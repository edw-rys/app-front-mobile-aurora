import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/helpers.dart';
import '../../core/utils/validators.dart';
import '../../data/models/reading_model.dart';
import '../providers/meters_provider.dart';

/// Meter detail screen — mockup 7
/// Giant centered input, collapsible optional section, sticky footer
class MeterDetailScreen extends ConsumerStatefulWidget {
  final String nAbonado;

  const MeterDetailScreen({super.key, required this.nAbonado});

  @override
  ConsumerState<MeterDetailScreen> createState() => _MeterDetailScreenState();
}

class _MeterDetailScreenState extends ConsumerState<MeterDetailScreen> {
  final _readingController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isDamaged = false;
  bool _isInaccessible = false;
  bool _isSaving = false;
  bool _optionalExpanded = false;
  bool _showSavedIndicator = false;
  Timer? _indicatorTimer;

  // Reactive validation
  String? _inputError; // non-null = blocked
  int? _prevReading;   // filled when meter is loaded

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExistingReading());
  }

  @override
  void didUpdateWidget(covariant MeterDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nAbonado != widget.nAbonado) {
      // Route param changed, but widget tree was reused
      _readingController.clear();
      _notesController.clear();
      setState(() {
        _isDamaged = false;
        _isInaccessible = false;
        _inputError = null;
        _prevReading = null;
      });
      _loadExistingReading();
    }
  }

  void _loadExistingReading() {
    final s = ref.read(metersProvider);
    final meter = s.meters.firstWhere((m) => m.nAbonado == widget.nAbonado);
    _prevReading = meter.reading.previousReading;
    final existing = s.readings[widget.nAbonado];
    if (existing != null) {
      if (existing.currentReading != null) {
        _readingController.text = existing.currentReading.toString();
      }
      _notesController.text = existing.notes ?? '';
      setState(() {
        _isDamaged = existing.isDamaged;
        _isInaccessible = existing.isInaccessible;
      });
    }
  }

  @override
  void dispose() {
    _readingController.dispose();
    _notesController.dispose();
    _indicatorTimer?.cancel();
    super.dispose();
  }

  void _fillSameReading() {
    final s = ref.read(metersProvider);
    final meter = s.meters.firstWhere((m) => m.nAbonado == widget.nAbonado);
    final prev = meter.reading.previousReading ?? 0;
    _readingController.text = prev.toString();
    _readingController.selection = TextSelection.collapsed(offset: _readingController.text.length);
    _validateInput(_readingController.text);
  }

  /// Real-time input validation — sets _inputError and triggers rebuild
  void _validateInput(String raw) {
    final text = raw.trim();
    // Allow empty (user is typing, not an error yet)
    if (text.isEmpty) {
      setState(() => _inputError = null);
      return;
    }
    // Must be pure digits (no letters, no minus sign through UI path)
    if (!RegExp(r'^\d+$').hasMatch(text)) {
      setState(() => _inputError = 'Solo se admiten números');
      return;
    }
    final val = int.tryParse(text);
    if (val == null) {
      setState(() => _inputError = 'Número inválido');
      return;
    }
    if (val < 0) {
      setState(() => _inputError = 'No puede ser negativo');
      return;
    }
    final effectivePrev = _prevReading ?? 0;
    if (val < effectivePrev) {
      setState(() => _inputError = 'Menor a la lectura anterior ($effectivePrev)');
      return;
    }
    setState(() => _inputError = null);
  }

  bool get _canSave => _inputError == null && !_isSaving;

  void _showSavedBriefly() {
    _indicatorTimer?.cancel();
    setState(() => _showSavedIndicator = true);
    _indicatorTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _showSavedIndicator = false);
    });
  }


  Future<void> _saveReading() async {
    final readingValue = int.tryParse(_readingController.text.trim());
    if (readingValue == null && !_isDamaged && !_isInaccessible) return;

    final s = ref.read(metersProvider);
    final meter = s.meters.firstWhere((m) => m.nAbonado == widget.nAbonado);

    // Only warn for high consumption (negative+below-prev are already blocked by validation)
    if (readingValue != null) {
      final result = Validators.validateConsumption(readingValue, meter.reading.previousReading);
      if (result == ConsumptionResult.high) {
        final ok = await _showWarning(AppStrings.highConsumption, AppStrings.highConsumptionDesc);
        if (!ok) return;
      }
    }

    setState(() => _isSaving = true);

    final reading = ReadingModel(
      nAbonado: widget.nAbonado,
      currentReading: readingValue,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      isDamaged: _isDamaged,
      isInaccessible: _isInaccessible,
      localTimestamp: Helpers.formatDateTimeForApi(DateTime.now()),
      dateRead: Helpers.formatDateTimeForApi(DateTime.now()),
    );

    // Capture next meter BEFORE saving, because saving might remove current meter from filtered list (e.g. if filtering by Pending)
    final filtered = ref.read(filteredMetersProvider);
    final currentIdx = filtered.indexWhere((m) => m.nAbonado == widget.nAbonado);
    String? nextAbonado;
    if (currentIdx != -1 && currentIdx < filtered.length - 1) {
      nextAbonado = filtered[currentIdx + 1].nAbonado;
    }

    await ref.read(metersProvider.notifier).saveReading(reading, meter: meter);
    setState(() => _isSaving = false);

    if (mounted) {
      _readingController.clear();
      _notesController.clear();
      _showSavedBriefly();
      _navigateToNext(explicitNext: nextAbonado);
    }
  }

  void _navigateToNext({String? explicitNext}) {
    if (explicitNext != null) {
      context.go('/meters/${Uri.encodeComponent(explicitNext)}');
      return;
    }

    final filtered = ref.read(filteredMetersProvider);
    final idx = filtered.indexWhere((m) => m.nAbonado == widget.nAbonado);

    if (idx != -1 && idx < filtered.length - 1) {
      context.go('/meters/${Uri.encodeComponent(filtered[idx + 1].nAbonado)}');
    } else {
      context.go('/meters');
    }
  }

  void _navigateToPrevious() {
    final filtered = ref.read(filteredMetersProvider);
    final idx = filtered.indexWhere((m) => m.nAbonado == widget.nAbonado);
    if (idx > 0) {
      context.go('/meters/${Uri.encodeComponent(filtered[idx - 1].nAbonado)}');
    }
  }

  Future<bool> _showWarning(String title, String body) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(body),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continuar')),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(metersProvider);
    final filtered = ref.watch(filteredMetersProvider);
    
    final meter = s.meters.firstWhere(
      (m) => m.nAbonado == widget.nAbonado,
      orElse: () => throw StateError('Meter not found'),
    );
    
    final idxInFiltered = filtered.indexOf(meter);
    final displayIdx = idxInFiltered != -1 ? idxInFiltered + 1 : 0;
    final displayTotal = filtered.length;
    
    final prevReading = meter.reading.previousReading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              // ── Header ──────────────────────────────────────
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            context.go('/meters');
                          }
                        },
                      ),
                      Text(
                        '$displayIdx de $displayTotal',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF718096)),
                      ),
                      const Spacer(),
                      if (meter.geo.hasCoordinates)
                        TextButton(
                          onPressed: () => context.go('/map'),
                          child: Text('Mapa', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Main scrollable area ─────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  child: Column(
                    children: [
                      // Client + address
                      Text(
                        meter.clientName,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1A202C)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      // n_abonado prominently
                      Text(
                        meter.nAbonado,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            fontFamily: 'monospace'),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meter.address,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF718096)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      // Label row: "Nueva lectura" left + "Misma lectura" TextButton right
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Nueva lectura',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF94A3B8),
                                  letterSpacing: 0.5)),
                          TextButton(
                            onPressed: _fillSameReading,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text('Misma lectura (${prevReading ?? 0})',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Giant reading input
                      TextField(
                        controller: _readingController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        autofocus: true,
                        onChanged: _validateInput,
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4,
                          color: _inputError != null
                              ? Colors.red
                              : const Color(0xFF1A202C),
                        ),
                        decoration: InputDecoration(
                          hintText: '00000',
                          hintStyle: const TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE2E8F0),
                              letterSpacing: 4),
                          errorText: _inputError,
                          errorStyle: const TextStyle(fontSize: 12),
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: _inputError != null ? Colors.red : AppColors.primary,
                                width: 2),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: _inputError != null ? Colors.red : AppColors.primary,
                                width: 2),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: _inputError != null ? Colors.red : AppColors.primary,
                                width: 2.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Previous reading info
                      Text(
                        'Lectura anterior: ${prevReading ?? 'N/A'}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF718096)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Periodo: ${Helpers.formatDate(meter.reading.date)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 32),

                      // ── Collapsible "Opcional" ────────────────
                      GestureDetector(
                        onTap: () => setState(() => _optionalExpanded = !_optionalExpanded),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Opcional',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF718096))),
                            AnimatedRotation(
                              turns: _optionalExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 250),
                              child: const Icon(Icons.expand_more_rounded,
                                  size: 20, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),

                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: _optionalExpanded
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 16),
                                  const Text('Notas',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF4A5568))),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _notesController,
                                    maxLines: 3,
                                    decoration: InputDecoration(
                                      hintText: 'Agrega una nota...',
                                      border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _Toggle(
                                    label: 'Medidor dañado',
                                    icon: Icons.warning_amber_rounded,
                                    iconColor: Colors.orange,
                                    value: _isDamaged,
                                    onChanged: (v) => setState(() => _isDamaged = v),
                                  ),
                                  const SizedBox(height: 8),
                                  _Toggle(
                                    label: 'Acceso imposible',
                                    icon: Icons.block_rounded,
                                    iconColor: Colors.red,
                                    value: _isInaccessible,
                                    onChanged: (v) => setState(() => _isInaccessible = v),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Sticky footer ────────────────────────────────
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _canSave ? _saveReading : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: Colors.white))
                              : const Text('Guardar y siguiente',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      // Footer row: [← Anterior] [Volver a la lista] [Omitir →]
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: idxInFiltered > 0 ? _navigateToPrevious : null,
                            icon: const Icon(Icons.arrow_back_rounded, size: 18),
                            label: const Text('Anterior'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF94A3B8),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              } else {
                                context.go('/meters');
                              }
                            },
                            child: Text('Volver',
                                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500)),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _navigateToNext,
                            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                            label: const Text('Omitir'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF94A3B8),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Floating saved indicator (bottom-left) ───────────
          if (_showSavedIndicator)
            Positioned(
              left: 20,
              bottom: 100,
              child: AnimatedOpacity(
                opacity: _showSavedIndicator ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text('Guardado',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _Toggle({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.zero,
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
