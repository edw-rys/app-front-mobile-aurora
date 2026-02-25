import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/helpers.dart';
import '../../core/utils/validators.dart';
import '../../data/models/reading_model.dart';
import '../../data/services/local/image_compression_service.dart';
import '../providers/meters_provider.dart';
import '../widgets/camera_onboarding_sheet.dart';
import '../../app/di/injection.dart';
import '../../data/services/local/preferences_service.dart';

/// Meter detail screen — mockup 7
/// Giant centered input, collapsible sections, sticky footer with camera support
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
  bool _photoExpanded = false;
  bool _showSavedIndicator = false;
  Timer? _indicatorTimer;

  String? _inputError;
  int? _prevReading;

  final _imageService = ImageCompressionService();
  String? _localImagePath; // Path captured this session (may already be in reading)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExistingReading());
  }

  @override
  void didUpdateWidget(covariant MeterDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nAbonado != widget.nAbonado) {
      _readingController.clear();
      _notesController.clear();
      setState(() {
        _isDamaged = false;
        _isInaccessible = false;
        _inputError = null;
        _prevReading = null;
        _localImagePath = null;
        _photoExpanded = false;
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
        _localImagePath = existing.localImagePath;
        _photoExpanded = existing.hasLocalImage;
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
    _readingController.selection =
        TextSelection.collapsed(offset: _readingController.text.length);
    _validateInput(_readingController.text);
  }

  void _validateInput(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      setState(() => _inputError = null);
      return;
    }
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

  bool get _hasImage => (_localImagePath != null && _localImagePath!.isNotEmpty);

  bool get _canSave {
    final s = ref.read(metersProvider);
    if (_inputError != null || _isSaving) return false;
    // requirePhoto: must have image to save
    if (s.enablePhoto && s.requirePhoto && !_hasImage) return false;
    return true;
  }

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
      localImagePath: _localImagePath,
    );

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

  /// Opens the camera, captures and compresses a photo
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

    setState(() => _isSaving = true);
    try {
      final compressed = await _imageService.compressAndSave(result);
      setState(() {
        _localImagePath = compressed;
        _photoExpanded = true;
        _isSaving = false;
      });
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar imagen: $e')),
        );
      }
    }
  }

  /// Opens the photo in full-screen with zoom and swipe-to-close
  void _openPhotoView() {
    if (!_hasImage) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PhotoViewPage(imagePath: _localImagePath!),
        fullscreenDialog: true,
      ),
    );
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

    final enablePhoto = s.enablePhoto;
    final requirePhoto = s.requirePhoto;

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
                      Text(
                        meter.clientName,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1A202C)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
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
                          color: _inputError != null ? Colors.red : const Color(0xFF1A202C),
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

                      // ── Collapsible photo section (when has image) ──
                      if (enablePhoto && _hasImage) ...[
                        GestureDetector(
                          onTap: () => setState(() => _photoExpanded = !_photoExpanded),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF06B6D4).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFF06B6D4).withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.camera_alt_rounded,
                                    size: 18, color: Color(0xFF06B6D4)),
                                const SizedBox(width: 10),
                                const Expanded(
                                    child: Text('Foto del medidor',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF06B6D4)))),
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 16,
                                  color: AppColors.success,
                                ),
                                const SizedBox(width: 8),
                                AnimatedRotation(
                                  turns: _photoExpanded ? 0.5 : 0,
                                  duration: const Duration(milliseconds: 250),
                                  child: const Icon(Icons.expand_more_rounded,
                                      size: 20, color: Color(0xFF06B6D4)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: _photoExpanded
                              ? GestureDetector(
                                  onTap: _openPhotoView,
                                  child: Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    height: 200,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: const Color(0xFF06B6D4).withValues(alpha: 0.3)),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.file(
                                          File(_localImagePath!),
                                          fit: BoxFit.cover,
                                        ),
                                        Positioned(
                                          bottom: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.5),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(Icons.zoom_in_rounded,
                                                color: Colors.white, size: 18),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 20),
                      ],

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
                      // Camera button (only when enablePhoto=true)
                      if (enablePhoto) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _isSaving ? null : _capturePhoto,
                            icon: _isSaving && !_hasImage
                                ? const SizedBox(
                                    width: 18, height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : Icon(
                                    _hasImage ? Icons.camera_alt_rounded : Icons.camera_alt_rounded,
                                    size: 20,
                                    color: _hasImage ? AppColors.success : const Color(0xFF06B6D4),
                                  ),
                            label: Text(
                              _hasImage ? 'Cambiar foto' : 'Tomar foto del medidor',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _hasImage ? AppColors.success : const Color(0xFF06B6D4)),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: _hasImage
                                      ? AppColors.success.withValues(alpha: 0.5)
                                      : const Color(0xFF06B6D4).withValues(alpha: 0.5)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        // require_photo hint
                        if (requirePhoto && !_hasImage)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    size: 13, color: Colors.orange.shade700),
                                const SizedBox(width: 4),
                                Text('Se requiere foto para guardar',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange.shade700,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        const SizedBox(height: 8),
                      ],

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _canSave ? _saveReading : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFCBD5E1),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: Colors.white))
                              : const Text('Guardar y siguiente',
                                  style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),

                      // Footer nav row
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
                          /*TextButton(
                            onPressed: () {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              } else {
                                context.go('/meters');
                              }
                            },
                            child: Text('Volver',
                                style: TextStyle(
                                    color: AppColors.primary, fontWeight: FontWeight.w500)),
                          ),
                          const Spacer(),*/
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

          // ── Floating saved indicator ─────────────────────────
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

// ─── Camera Capture Page ──────────────────────────────────────

class _CameraCapturePage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const _CameraCapturePage({required this.cameras});

  @override
  State<_CameraCapturePage> createState() => _CameraCapturageState();
}

class _CameraCapturageState extends State<_CameraCapturePage> {
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
            const Center(child: CircularProgressIndicator(color: Colors.white)),
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

// ─── Photo View Page ──────────────────────────────────────────

/// Full-screen photo preview with zoom. Swipe down to close.
class _PhotoViewPage extends StatelessWidget {
  final String imagePath;
  const _PhotoViewPage({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
            Navigator.pop(context);
          }
        },
        child: Stack(
          children: [
            PhotoView(
              imageProvider: FileImage(File(imagePath)),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3,
              heroAttributes: PhotoViewHeroAttributes(tag: imagePath),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Toggle Widget ────────────────────────────────────────────

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
      decoration: const BoxDecoration(color: Colors.transparent),
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
