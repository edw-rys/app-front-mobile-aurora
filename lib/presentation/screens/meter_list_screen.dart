import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/meter_model.dart';
import '../../data/models/reading_model.dart';
import '../../data/services/local/image_compression_service.dart';
import '../providers/meters_provider.dart';
import '../../shared/widgets/sector_picker_sheet.dart';
import '../widgets/camera_onboarding_sheet.dart';
import '../../app/di/injection.dart';
import '../../data/services/local/preferences_service.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final filters = ref.read(meterFiltersProvider);
      if (filters.query.isNotEmpty) {
        _searchController.text = filters.query;
      }
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

  void _jumpToNextPending(List<MeterModel> filtered, MetersState s) {
    if (!_scrollController.hasClients) return;
    const itemHeight = 145.0;
    int currentVisibleIdx = (_scrollController.offset / itemHeight).floor();
    if (currentVisibleIdx < 0) currentVisibleIdx = 0;
    int nextIdx = filtered.indexWhere((m) => !s.readings.containsKey(m.nAbonado), currentVisibleIdx + 1);
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

    final sectorMeters = filters.sector == null
        ? s.meters
        : s.meters.where((m) => m.sector?.name == filters.sector!.name).toList();

    final total = sectorMeters.length;
    final read = sectorMeters.where((m) => s.readings.containsKey(m.nAbonado)).length;
    final pending = sectorMeters.where((m) => !s.readings.containsKey(m.nAbonado)).length;
    final errors = sectorMeters.where((m) {
      final r = s.readings[m.nAbonado];
      if (r == null) return false;
      if (!r.isValid || r.syncError != null) return true;
      if (s.requirePhoto && r.isValid && !r.hasLocalImage) return true;
      return false;
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
                        enablePhoto: s.enablePhoto,
                        requirePhoto: s.requirePhoto,
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

/// Individual fast-entry card with auto-save debounce and optional photo support
class _FastEntryCard extends StatefulWidget {
  final MeterModel meter;
  final ReadingModel? reading;
  final bool enablePhoto;
  final bool requirePhoto;
  final VoidCallback onTap;
  final Future<void> Function(ReadingModel) onSave;

  const _FastEntryCard({
    required this.meter,
    required this.reading,
    required this.enablePhoto,
    required this.requirePhoto,
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
  bool _savedSuccess = false;
  String? _inputError;
  final _imageService = ImageCompressionService();

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.reading?.currentReading?.toString() ?? '',
    );
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _validateInputs();
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
    if (_inputError != null && mounted) setState(() => _inputError = null);

    // When enablePhoto=true and requirePhoto=true, do NOT auto-save without image
    if (widget.enablePhoto && widget.requirePhoto) {
      // Require image before saving — no debounce save
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 1500), () => _save());
  }

  Future<void> _save({String? localImagePath}) async {
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
      localImagePath: localImagePath,
    );
    try {
      await widget.onSave(reading);
      if (mounted) {
        setState(() => _savedSuccess = true);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _savedSuccess = false);
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Opens the device camera to capture a photo, compresses it, and saves
  Future<void> _capturePhoto() async {
    final status = await Permission.camera.status;
    if (!status.isGranted) {
      if (mounted) {
        await CameraOnboardingSheet.show(context);
      }
      final newStatus = await Permission.camera.status;
      if (!newStatus.isGranted) return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty || !mounted) return;

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _CameraCapturePage(cameras: cameras),
        fullscreenDialog: true,
      ),
    );

    if (result == null || !mounted) return;

    // Compress the image
    setState(() => _saving = true);
    try {
      final compressed = await _imageService.compressAndSave(result);
      // Now save with the image path
      await _save(localImagePath: compressed);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar imagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _isRead => widget.reading?.currentReading != null;
  bool get _hasImage => widget.reading?.hasLocalImage ?? false;

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
            // ── Card header ─────────────────────────────────
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Small image indicator when photo captured
                    if (widget.enablePhoto && _hasImage)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.camera_alt_rounded,
                            size: 13, color: Color(0xFF06B6D4)),
                      ),
                    _StatusBadge(isRead: _isRead),
                  ],
                ),
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

            // ── Input row ────────────────────────────────────
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
                          // Only auto-save on editing complete if no photo required
                          if (!widget.enablePhoto || !widget.requirePhoto) {
                            _save();
                          }
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
                              color: _buildBorderColor(),
                              width: 2,
                            ),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: _buildBorderColor(),
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
                      // Success indicator for !requirePhoto saves
                      if (widget.enablePhoto && !widget.requirePhoto && _savedSuccess)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  size: 13, color: AppColors.success),
                              const SizedBox(width: 4),
                              Text('Guardado',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // ── Action button ─────────────────────────────
                if (!widget.enablePhoto)
                  // Original save button (no photo mode)
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
                  )
                else if (!_hasImage)
                  // Camera button (photo mode, no image yet)
                  GestureDetector(
                    onTap: _saving ? null : _capturePhoto,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF06B6D4),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFF06B6D4).withValues(alpha: 0.35),
                              blurRadius: 8)
                        ],
                      ),
                      child: _saving
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 20),
                    ),
                  )
                else
                  // Check / saved indicator (has image)
                  GestureDetector(
                    onTap: _saving ? null : () { _debounce?.cancel(); _save(); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFDCFCE7),
                      ),
                      child: _saving
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Color(0xFF22C55E)))
                          : const Icon(Icons.done_all_rounded,
                              color: Color(0xFF22C55E), size: 20),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _buildBorderColor() {
    if (_inputError != null) return Colors.red;
    if (_isRead) {
      if (widget.enablePhoto && _hasImage) return const Color(0xFF06B6D4).withValues(alpha: 0.5);
      return const Color(0xFF22C55E).withValues(alpha: 0.5);
    }
    return const Color(0xFFE2E8F0);
  }
}

// ─── Camera Capture Page ───────────────────────────────────

/// Full-screen camera page. Returns the captured image file path, or null.
class _CameraCapturePage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const _CameraCapturePage({required this.cameras});

  @override
  State<_CameraCapturePage> createState() => _CameraCaptureCageState();
}

class _CameraCaptureCageState extends State<_CameraCapturePage> {
  late CameraController _controller;
  bool _initialized = false;
  bool _capturing = false;
  
  // Flash & Zoom states
  FlashMode _flashMode = FlashMode.off;
  double _currentZoomLevel = 1.0;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _controller = CameraController(
      widget.cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _controller.initialize();
    
    // Load persisted flash mode, default to off
    final prefs = getIt<PreferencesService>();
    final savedFlash = await prefs.getCameraFlashMode();
    _flashMode = FlashMode.values.firstWhere(
      (m) => m.name == savedFlash,
      orElse: () => FlashMode.off,
    );

    // Default to auto flash and grab zoom bounds
    await _controller.setFlashMode(_flashMode);
    _minAvailableZoom = await _controller.getMinZoomLevel();
    _maxAvailableZoom = await _controller.getMaxZoomLevel();
    _currentZoomLevel = _minAvailableZoom;

    if (mounted) setState(() => _initialized = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    if (!_initialized) return;
    FlashMode nextMode;
    switch (_flashMode) {
      case FlashMode.auto:
        nextMode = FlashMode.always;
        break;
      case FlashMode.always:
        nextMode = FlashMode.off;
        break;
      case FlashMode.off:
        nextMode = FlashMode.auto;
        break;
      case FlashMode.torch:
        nextMode = FlashMode.auto; // Unused but covered
        break;
    }
    await _controller.setFlashMode(nextMode);
    setState(() => _flashMode = nextMode);
    await getIt<PreferencesService>().setCameraFlashMode(nextMode.name);
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) async {
    if (!_initialized) return;
    
    final zoomFactor = details.scale;
    double newZoom = _currentZoomLevel * zoomFactor;

    // Dampen the zoom speed to make it smoother
    if (zoomFactor > 1) {
      newZoom = _currentZoomLevel + 0.05;
    } else if (zoomFactor < 1) {
      newZoom = _currentZoomLevel - 0.05;
    }

    newZoom = newZoom.clamp(_minAvailableZoom, _maxAvailableZoom);
    if (newZoom != _currentZoomLevel) {
      try {
        await _controller.setZoomLevel(newZoom);
        _currentZoomLevel = newZoom;
      } catch (e) {
         // ignore
      }
    }
  }

  Future<void> _capture() async {
    if (!_initialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await _controller.takePicture();
      if (mounted) Navigator.pop(context, file.path);
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_initialized)
            GestureDetector(
              onScaleUpdate: _handleScaleUpdate,
              child: CameraPreview(_controller),
            ),
          if (!_initialized)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          // Flash toggle
          if (_initialized)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 16,
              child: IconButton(
                icon: Icon(
                  _flashMode == FlashMode.always 
                      ? Icons.flash_on_rounded
                      : _flashMode == FlashMode.off
                          ? Icons.flash_off_rounded
                          : Icons.flash_auto_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: _toggleFlash,
              ),
            ),
          // Capture button
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _capture,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    color: _capturing
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.2),
                  ),
                  child: _capturing
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 32),
                ),
              ),
            ),
          ),
        ],
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
