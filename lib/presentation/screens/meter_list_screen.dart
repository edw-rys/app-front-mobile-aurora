import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/meter_model.dart';
import '../../data/models/reading_model.dart';
import '../providers/meters_provider.dart';
import '../../shared/widgets/sector_picker_sheet.dart';

/// Fast-entry meter list screen — matches mockup 6
/// Inline reading input with auto-save debounce
class MeterListScreen extends ConsumerStatefulWidget {
  /// Optional initial filter ('pending', 'read', 'all')
  final String? initialFilter;

  const MeterListScreen({super.key, this.initialFilter});

  @override
  ConsumerState<MeterListScreen> createState() => _MeterListScreenState();
}

class _MeterListScreenState extends ConsumerState<MeterListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _jumpTimer;

  @override
  void initState() {
    super.initState();
    // Sync search controller with provider if already has data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final filters = ref.read(meterFiltersProvider);
      if (filters.query.isNotEmpty) {
        _searchController.text = filters.query;
      }
      
      // If initialFilter is provided, it overrides provider status
      if (widget.initialFilter != null) {
        ref.read(meterFiltersProvider.notifier).setStatus(widget.initialFilter!);
      }
    });
  }

  @override
  void didUpdateWidget(MeterListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFilter != oldWidget.initialFilter && widget.initialFilter != null) {
      ref.read(meterFiltersProvider.notifier).setStatus(widget.initialFilter!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _jumpTimer?.cancel();
    super.dispose();
  }

  /// Scroll (in the current filtered list) to the next meter that has no reading.
  void _jumpToNextPending(List<MeterModel> filtered, MetersState s) {
    if (!_scrollController.hasClients) return;
    const itemHeight = 135.0; // Approximate card height + margin
    
    // Calculate current visible index
    int currentVisibleIdx = (_scrollController.offset / itemHeight).floor();
    if (currentVisibleIdx < 0) currentVisibleIdx = 0;

    // Find next pending AFTER the currently visible item
    int nextIdx = filtered.indexWhere((m) => !s.readings.containsKey(m.nAbonado), currentVisibleIdx + 1);
    
    // If not found, wrap around and search from the beginning
    if (nextIdx < 0) {
      nextIdx = filtered.indexWhere((m) => !s.readings.containsKey(m.nAbonado));
    }
    
    if (nextIdx < 0) return;

    final targetOffset = (itemHeight * nextIdx)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
        
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(metersProvider);
    final filters = ref.watch(meterFiltersProvider);
    final filtered = ref.watch(filteredMetersProvider);
    
    // Recalculate counts based on sector
    final sectorMeters = filters.sector == null 
        ? s.meters 
        : s.meters.where((m) => m.sector?.name == filters.sector!.name).toList();
        
    final total = sectorMeters.length;
    final read = sectorMeters.where((m) => s.readings.containsKey(m.nAbonado)).length;
    final pending = sectorMeters.where((m) => !s.readings.containsKey(m.nAbonado)).length;
    final errors = sectorMeters.where((m) {
      final r = s.readings[m.nAbonado];
      return r != null && (!r.isValid || r.syncError != null);
    }).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // ── Sticky header ─────────────────────────────────
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Lecturas de hoy',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B))),
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                          onPressed: () => context.go('/home'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Search bar
                    TextField(
                      controller: _searchController,
                      onChanged: (val) => ref.read(meterFiltersProvider.notifier).setQuery(val),
                      decoration: InputDecoration(
                        hintText: 'Buscar cliente o medidor...',
                        prefixIcon:
                            const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: EdgeInsets.zero,
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                })
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _chip('Todos', 'all', total),
                          const SizedBox(width: 8),
                          _chip('Pendientes', 'pending', pending),
                          const SizedBox(width: 8),
                          _chip('Leídos', 'read', read),
                          if (errors > 0) ...[
                            const SizedBox(width: 8),
                            _chip('Con errores', 'errors', errors, color: AppColors.error),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Sector Filter (Searchable Picker)
                    if (s.sectors.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => SectorPickerSheet(
                              sectors: s.sectors,
                              selectedSector: filters.sector,
                              onSelect: (val) => ref.read(meterFiltersProvider.notifier).setSector(val),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: filters.sector == null ? 12 : 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.map_rounded, size: 18, color: AppColors.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  filters.sector?.name ?? 'Filtrar por sector',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: filters.sector == null ? const Color(0xFF64748B) : const Color(0xFF1E293B),
                                    fontWeight: filters.sector == null ? FontWeight.normal : FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (filters.sector != null)
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    ref.read(meterFiltersProvider.notifier).setSector(null);
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                )
                              else
                                const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF94A3B8)),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    // Progress bar
                    Row(
                      children: [
                        const Text('Progreso diario',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 0.5)),
                        const Spacer(),
                        Text('$read de $total',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: total > 0 ? read / total : 0,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFF1F5F9),
                        valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
          // ── List ──────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.done_all_rounded, size: 64, color: AppColors.primary),
                        const SizedBox(height: 16),
                        const Text('No hay medidores en este filtro',
                            style: TextStyle(color: Color(0xFF64748B))),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final meter = filtered[i];
                      final reading = s.readings[meter.nAbonado];
                      return _FastEntryCard(
                        meter: meter,
                        reading: reading,
                        onTap: () =>
                            context.push('/meters/${Uri.encodeComponent(meter.nAbonado)}'),
                        onSave: (r) =>
                            ref.read(metersProvider.notifier).saveReading(r, meter: meter),
                      );
                    },
                  ),
          ),
        ],
      ),
      // Jump to next pending FAB
      floatingActionButton: pending > 0
          ? FloatingActionButton.small(
              onPressed: () => _jumpToNextPending(filtered, s),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.arrow_downward_rounded, size: 20),
            )
          : null,
    );
  }

  Widget _chip(String label, String value, int count, {Color? color}) {
    final filters = ref.watch(meterFiltersProvider);
    final selected = filters.status == value;
    final defaultBg = color ?? const Color(0xFF1E293B);
    
    return GestureDetector(
      onTap: () => ref.read(meterFiltersProvider.notifier).setStatus(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? defaultBg : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? defaultBg : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: selected ? Colors.white : const Color(0xFF475569))),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.2)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('$count',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : const Color(0xFF64748B))),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual fast-entry card with auto-save debounce
class _FastEntryCard extends StatefulWidget {
  final MeterModel meter;
  final ReadingModel? reading;
  final VoidCallback onTap;
  final Future<void> Function(ReadingModel) onSave;

  const _FastEntryCard({
    required this.meter,
    required this.reading,
    required this.onTap,
    required this.onSave,
  });

  @override
  State<_FastEntryCard> createState() => _FastEntryCardState();
}

class _FastEntryCardState extends State<_FastEntryCard> {
  late TextEditingController _ctrl;
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  bool _saving = false;
  String? _inputError;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.reading?.currentReading?.toString() ?? '',
    );
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _validateInputs();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _FastEntryCard old) {
    super.didUpdateWidget(old);
    final newVal = widget.reading?.currentReading?.toString() ?? '';
    if (_ctrl.text != newVal && !_saving) {
      _ctrl.text = newVal;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _validateInputs() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      if (mounted) setState(() => _inputError = null);
      return;
    }
    if (!RegExp(r'^\d+$').hasMatch(text)) {
      if (mounted) setState(() => _inputError = 'No admitido');
      return;
    }
    final val = int.tryParse(text);
    if (val == null) {
      if (mounted) setState(() => _inputError = 'Inválido');
      return;
    }
    final prev = widget.meter.reading.previousReading;
    if (prev != null && val < prev) {
      if (mounted) setState(() => _inputError = 'Revisar valor');
      return;
    }
    if (mounted) setState(() => _inputError = null);
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (_inputError != null && mounted) {
      setState(() => _inputError = null);
    }
    _debounce = Timer(const Duration(milliseconds: 1500), () => _save());
  }

  Future<void> _save() async {
    _validateInputs();
    if (_inputError != null) return;

    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final val = int.tryParse(text);
    if (val == null) return;

    setState(() => _saving = true);
    final reading = (widget.reading ?? ReadingModel(nAbonado: widget.meter.nAbonado)).copyWith(
      currentReading: val,
      localTimestamp: DateTime.now().toIso8601String(),
    );
    try {
      await widget.onSave(reading);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _isRead => widget.reading?.currentReading != null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _isRead ? Colors.white.withValues(alpha: 0.6) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFFF1F5F9),
              width: _isRead ? 1 : 1.5),
          boxShadow: _isRead
              ? []
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(widget.meter.clientName,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: _isRead
                              ? const Color(0xFF475569)
                              : const Color(0xFF1E293B))),
                ),
                _StatusBadge(isRead: _isRead),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  widget.meter.nAbonado,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: _isRead ? const Color(0xFF94A3B8) : AppColors.primary,
                      fontFamily: 'monospace'),
                ),
                const SizedBox(width: 6),
                const Text('·', style: TextStyle(color: Color(0xFFCBD5E1))),
                const SizedBox(width: 6),
                const Text('N° ',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                Text(widget.meter.number ?? '-',
                    style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: Color(0xFF475569))),
                const SizedBox(width: 6),
                const Text('· ', style: TextStyle(color: Color(0xFFCBD5E1))),
                Expanded(
                  child: Text(
                      'Ant: ${widget.meter.reading.previousReading ?? 0}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(widget.meter.address,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isRead ? 'Lectura ingresada' : 'Nueva lectura',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: _isRead
                              ? const Color(0xFF94A3B8)
                              : AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _ctrl,
                        focusNode: _focusNode,
                        enabled: true,
                        keyboardType: TextInputType.number,
                        onChanged: _onChanged,
                        onEditingComplete: () {
                          _debounce?.cancel();
                          _focusNode.unfocus();
                          _save();
                        },
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w300,
                          color: _inputError != null
                              ? Colors.red
                              : (_isRead ? const Color(0xFF475569) : const Color(0xFF1E293B)),
                        ),
                        decoration: InputDecoration(
                          hintText: '0000',
                          hintStyle:
                              const TextStyle(color: Color(0xFFCBD5E1), fontWeight: FontWeight.w300),
                          errorText: _inputError,
                          errorMaxLines: 1,
                          errorStyle: const TextStyle(fontSize: 10, height: 0.8),
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: _inputError != null
                                  ? Colors.red
                                  : (_isRead ? const Color(0xFF22C55E).withValues(alpha: 0.5) : const Color(0xFFE2E8F0)),
                              width: 2,
                            ),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: _inputError != null
                                  ? Colors.red
                                  : (_isRead ? const Color(0xFF22C55E).withValues(alpha: 0.5) : const Color(0xFFE2E8F0)),
                              width: 2,
                            ),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: _inputError != null ? Colors.red : AppColors.primary, width: 2),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.only(bottom: 4, top: 4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _isRead ? null : () { _debounce?.cancel(); _save(); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isRead
                          ? const Color(0xFFDCFCE7)
                          : AppColors.primary,
                      boxShadow: _isRead
                          ? []
                          : [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8)],
                    ),
                    child: _saving
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Icon(
                            _isRead ? Icons.done_all_rounded : Icons.check_rounded,
                            color: _isRead ? const Color(0xFF22C55E) : Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isRead;
  const _StatusBadge({required this.isRead});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isRead
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isRead ? 'LEÍDO' : 'PENDIENTE',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: isRead ? const Color(0xFF16A34A) : const Color(0xFFD97706),
        ),
      ),
    );
  }
}
