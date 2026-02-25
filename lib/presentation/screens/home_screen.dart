import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/loading_overlay.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../providers/auth_provider.dart';
import '../providers/meters_provider.dart';
import '../providers/connectivity_provider.dart';
import '../../data/models/meter_model.dart';
import '../../data/repositories/meter_repository.dart';
import '../../data/services/local/preferences_service.dart';
import '../../app/di/injection.dart';
import '../widgets/gps_onboarding_sheet.dart';
import '../widgets/camera_onboarding_sheet.dart';

/// Home screen — 3 states:
///   A — no meters downloaded
///   B — meters ready, work NOT started  (mockup 3)
///   C — work started                    (mockup 5 pending card)
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions();
      ref.read(metersProvider.notifier).loadMeters();
    });
  }

  Future<void> _checkPermissions() async {
    final prefs = getIt<PreferencesService>();
    final shownGps = await prefs.isGpsOnboardingShown();
    
    // 1. GPS Onboarding
    if (!shownGps) {
      final status = await Permission.locationWhenInUse.status;
      if (!status.isGranted) {
        if (mounted) {
          await GpsOnboardingSheet.show(context);
          await prefs.setGpsOnboardingShown(true);
        }
      } else {
        await prefs.setGpsOnboardingShown(true);
      }
    }

    // 2. Camera Onboarding
    final shownCamera = await prefs.isCameraOnboardingShown();
    if (!shownCamera) {
      final camStatus = await Permission.camera.status;
      if (!camStatus.isGranted) {
        if (mounted) {
          await CameraOnboardingSheet.show(context);
          await prefs.setCameraOnboardingShown(true);
        }
      } else {
        await prefs.setCameraOnboardingShown(true);
      }
    }
  }

  // ─── Actions ──────────────────────────────────────────────

  Future<void> _downloadWork() async {
    final controller = StreamController<LoadingOverlayState>();

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, anim, _, child) =>
          FadeTransition(opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut), child: child),
      pageBuilder: (ctx, _, __) => StreamOverlay(
        stateStream: controller.stream,
        title: 'Descargando medidores...',
        activeIcon: Icons.cloud_download_rounded,
      ),
    );

    final sub = ref.listenManual<MetersState>(metersProvider, (_, next) {
      if (next.isDownloading) {
        controller.add(LoadingOverlayState(
          current: next.downloadProgress,
          total: next.downloadTotal,
          message: next.downloadTotal > 0
              ? 'Página ${next.downloadProgress} de ${next.downloadTotal}'
              : 'Conectando...',
        ));
      }
    });

    try {
      await ref.read(metersProvider.notifier).downloadMeters();
      final ms = ref.read(metersProvider);
      controller.add(LoadingOverlayState(
        current: ms.downloadTotal,
        total: ms.downloadTotal,
        isComplete: true,
        message: '${ms.meters.length} medidores descargados',
      ));
      await Future.delayed(const Duration(milliseconds: 2000));
      controller.add(const LoadingOverlayState(shouldDismiss: true));
    } catch (e) {
      controller.add(const LoadingOverlayState(shouldDismiss: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ref.read(metersProvider).error ?? e.toString()),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      sub.close();
      await controller.close();
    }
  }

  /// Start work → mark locally started → navigate to meter list
  Future<void> _startWork() async {
    await ref.read(metersProvider.notifier).startWork();
    if (mounted) context.go('/meters');
  }

  Future<void> _sendReadings() async {
    // Validate first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Validando datos...'),
            ]),
          ),
        ),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    final validation = ref.read(metersProvider.notifier).validateReadings();
    if (!mounted) return;

    final unsyncedValidators = validation.valid.where((r) => r.synced == false).toList();

    if (!validation.hasErrors) {
      if (unsyncedValidators.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No hay lecturas nuevas por enviar.'),
          ));
        }
        return;
      }

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Enviar lecturas'),
          content: Text('¿Enviar ${unsyncedValidators.length} lecturas al servidor?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
          ],
        ),
      );
      if (ok == true && mounted) await _doSend(unsyncedValidators);
    } else {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Lecturas con error'),
          content: Text('${validation.invalidCount} lecturas sin valor ni incidencia.'),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (unsyncedValidators.isNotEmpty)
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, 'send_valid'),
                    child: Text('Enviar ${unsyncedValidators.length} lecturas válidas por sincronizar'),
                  ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, 'view_errors'),
                  child: Text('Ver ${validation.invalidCount} con errores'),
                ),
              ],
            ),
          ],
        ),
      );
      if (choice == 'send_valid' && mounted && unsyncedValidators.isNotEmpty) {
        await _doSend(unsyncedValidators);
      } else if (choice == 'view_errors' && mounted) {
        context.go('/meters?filter=errors');
      }
    }
  }

  Future<void> _doSend(List<dynamic> readings) async {
    final controller = StreamController<LoadingOverlayState>();
    final dialogFuture = showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, anim, _, child) =>
          FadeTransition(opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut), child: child),
      pageBuilder: (ctx, _, __) => StreamOverlay(
        stateStream: controller.stream,
        title: 'Enviando lecturas...',
        activeIcon: Icons.cloud_upload_rounded,
      ),
    );
    try {
      final syncResult = await ref.read(metersProvider.notifier).finishWork(
        readingsToSend: readings.cast(),
        onProgress: (cur, tot) => controller.add(LoadingOverlayState(
          current: cur, total: tot, message: 'Enviando $cur de $tot lecturas...')),
        onImageProgress: (cur, tot) => controller.add(LoadingOverlayState(
          current: cur, total: tot, message: 'Subiendo $cur de $tot imágenes...')),
      );

      if (syncResult.hasErrors) {
        // En caso de error, indicamos al LoadingOverlay que proceda a cerrarse
        controller.add(const LoadingOverlayState(shouldDismiss: true));
        // Esperamos a que la animación de cierre (pop) termine para no chocar o causar crash (_debugLocked) con GoRouter
        await dialogFuture;
        if (mounted && ref.read(authProvider).isAuthenticated) {
          context.push('/sync-result', extra: syncResult);
        }
      } else {
        // En caso de éxito, esperamos un poco
        controller.add(const LoadingOverlayState(isComplete: true, message: '¡Lecturas enviadas!'));
        await Future.delayed(const Duration(milliseconds: 2000));
        controller.add(const LoadingOverlayState(shouldDismiss: true));
        await dialogFuture; // Wait for dismissal
        if (mounted && ref.read(authProvider).isAuthenticated) {
          context.push('/sync-result', extra: syncResult);
        }
      }
    } catch (e) {
      controller.add(const LoadingOverlayState(shouldDismiss: true));
      await dialogFuture; // Wait for dismissal
      if (mounted && ref.read(authProvider).isAuthenticated) {
        // En caso de excepción no controlada, mostraremos el error de igual manera en SyncResultScreen
        final errorResult = SyncResult(
          synced: 0,
          errors: readings.length,
          errorMessages: [],
          globalError: 'Atención: ${e.toString()}',
        );
        context.push('/sync-result', extra: errorResult);
      }
    } finally {
      await controller.close();
    }
  }

  Future<void> _finishWork() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Finalizando trabajo...'),
            ]),
          ),
        ),
      ),
    );

    try {
      final message = await ref.read(metersProvider.notifier).finishPeriod();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // close dialog
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // close dialog
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _updateData() async {
    final controller = StreamController<LoadingOverlayState>();

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, anim, _, child) =>
          FadeTransition(opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut), child: child),
      pageBuilder: (ctx, _, __) => StreamOverlay(
        stateStream: controller.stream,
        title: 'Actualizando datos...',
        activeIcon: Icons.sync_rounded,
      ),
    );

    final sub = ref.listenManual<MetersState>(metersProvider, (_, next) {
      if (next.isUpdating) {
        controller.add(LoadingOverlayState(
          current: next.downloadProgress,
          total: next.downloadTotal,
          message: next.updateStatus ?? 'Procesando...',
        ));
      }
    });

    try {
      await ref.read(metersProvider.notifier).updateMeters();
      controller.add(const LoadingOverlayState(
        isComplete: true,
        message: 'Datos actualizados con éxito',
      ));
      await Future.delayed(const Duration(milliseconds: 2000));
      controller.add(const LoadingOverlayState(shouldDismiss: true));
    } catch (e) {
      controller.add(const LoadingOverlayState(shouldDismiss: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ref.read(metersProvider).error ?? e.toString()),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      sub.close();
      await controller.close();
    }
  }

  // ─── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final ms = ref.watch(metersProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final name = authState.user?.firstName ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ms.isLoading
            ? _buildSkeleton()
            : ms.meters.isEmpty
                ? _buildNoPeriod(name)
                : ms.isWorkStarted
                    ? _buildWorkStarted(ms, name)
                    : _buildPeriodReady(ms, name, isOnline),
      ),
    );
  }

  // ─── State A: No period ───────────────────────────────────

  Widget _buildNoPeriod(String name) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _header(name, 'Sin periodo activo'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 32),
                _progressRing(0.0),
                const SizedBox(height: 20),
                const Text('Sin periodo activo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                const SizedBox(height: 6),
                Text('Descarga tu asignación del servidor para comenzar.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                _primaryBtn(Icons.cloud_download_rounded, 'Obtener periodo de trabajo', _downloadWork),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── State B: Period ready, work NOT started (mockup 3) ───

  Widget _buildPeriodReady(MetersState ms, String name, bool isOnline) {
    final total = ms.stats['total'] ?? ms.meters.length;
    final pending = ms.stats['pending'] ?? ms.totalPending;
    final read = ms.stats['read'] ?? ms.totalRead;

    return Column(
      children: [
        _header(name, 'Periodo activo${isOnline ? '' : ' · Sin conexión'}'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                _progressRing(ms.progressPercent / 100.0),
                const SizedBox(height: 16),
                const Text('Todo listo para iniciar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                const SizedBox(height: 4),
                Text('Tu ruta está sincronizada y lista.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                const SizedBox(height: 20),
                _statsCard(total: total, pending: pending, read: read),
                const SizedBox(height: 20),
                _primaryBtn(Icons.play_circle_rounded, 'Iniciar lecturas', _startWork),
                const SizedBox(height: 12),
                _plainBtn('Actualizar datos', _updateData),
                _buildErrorsSection(ms),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── State C: Work started (mockup 5 pending-to-send UI) ─

  Widget _buildWorkStarted(MetersState ms, String name) {
    final total = ms.stats['total'] ?? ms.meters.length;
    final read = ms.stats['read'] ?? ms.totalRead;
    final pending = ms.totalPending;
    
    final synced = ms.readMeters.where((m) => ms.readings[m.nAbonado]?.synced == true).length;
    final unsynced = ms.readMeters.length - synced;

    return Column(
      children: [
        _header(name, 'Trabajo en progreso'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              children: [
                // Progress ring + count
                _progressRing(ms.progressPercent / 100.0),
                const SizedBox(height: 12),
                Text('$read de $total',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                const SizedBox(height: 2),
                Text('Medidores leídos hoy',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                const SizedBox(height: 16),

                // Stat chips
                Row(
                  children: [
                    Expanded(child: _statChip('Pendientes', pending, const Color(0xFFFB923C))),
                    const SizedBox(width: 12),
                    Expanded(child: _statChip('Leídos', read, AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _statChip('Por enviar', unsynced, const Color(0xFF0EA5E9))),
                    const SizedBox(width: 12),
                    Expanded(child: _statChip('Enviados', synced, AppColors.success)),
                  ],
                ),
                const SizedBox(height: 20),

                // ── UI based on completion status ───────────
                if (total > 0 && pending == 0 && unsynced == 0) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 28),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Trabajo completado',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B))),
                              SizedBox(height: 2),
                              Text(
                                'Todas las lecturas han sido enviadas. Puedes finalizar tu trabajo.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.45),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _primaryBtn(Icons.assignment_turned_in_rounded, 'Finalizar trabajo', _finishWork),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.cloud_upload_outlined, color: Color(0xFFF59E0B), size: 28),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Pendiente de envío',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B))),
                              SizedBox(height: 2),
                              Text(
                                'Las lecturas están listas localmente. Debes enviarlas para su aprobación final.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.45),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _primaryBtn(Icons.send_rounded, 'Enviar lecturas', _sendReadings),
                  const SizedBox(height: 10),
                  _plainBtn('Revisar lecturas antes de enviar', () => context.go('/meters')),
                  const SizedBox(height: 10),
                  _plainBtn('Actualizar datos', _updateData),
                ],
                _buildErrorsSection(ms),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Shared widgets ───────────────────────────────────────

  Widget _header(String name, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hola, $name 👋',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryLight,
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ),
              ),
              Positioned(
                bottom: 1,
                right: 1,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressRing(double progress, {double size = 160}) {
    final pct = (progress * 100).round();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulse ring
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.05),
            ),
          ),
          // Inner ring
          Container(
            width: size * 0.75,
            height: size * 0.75,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.08),
            ),
          ),
          // Progress arc
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: size * 0.06,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            '$pct%',
            style: TextStyle(fontSize: size * 0.22, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
          ),
        ],
      ),
    );
  }

  /// 3-column stats card — no box shadow, clean border (mockup 3)
  Widget _statsCard({required int total, required int pending, required int read}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
      ),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(child: _statCol('$total', 'Total', const Color(0xFF1E293B))),
                VerticalDivider(color: const Color(0xFFF1F5F9), thickness: 1),
                Expanded(child: _statCol('$pending', 'Pendientes', AppColors.primary)),
                VerticalDivider(color: const Color(0xFFF1F5F9), thickness: 1),
                Expanded(child: _statCol('$read', 'Leídos', const Color(0xFF94A3B8))),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Progreso', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              Text('$read / $total', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
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
        ],
      ),
    );
  }

  Widget _statCol(String value, String label, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
      ],
    );
  }

  Widget _statChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
      ),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
              Text('$count', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _primaryBtn(IconData icon, String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }

  /// Plain white outlined button — "Revisar lecturas antes de enviar"
  Widget _plainBtn(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          backgroundColor: Colors.white,
        ),
        child: Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF475569))),
      ),
    );
  }

  Widget _buildErrorsSection(MetersState ms) {
    if (ms.metersWithErrors.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        const Text('Con errores de envío', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1E293B))),
        const SizedBox(height: 12),
        ...ms.metersWithErrors.map((m) => _buildErrorCard(m, ms)),
      ],
    );
  }

  Widget _buildErrorCard(MeterModel meter, MetersState ms) {
    final reading = ms.readings[meter.nAbonado];
    final errorMsg = reading?.syncError ?? 'Error desconocido';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.go('/meters/${Uri.encodeComponent(meter.nAbonado)}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(meter.clientName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Error', style: TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(meter.nAbonado, style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_rounded, size: 16, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(child: Text(errorMsg, style: const TextStyle(fontSize: 12, color: AppColors.error))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(children: [
        SkeletonHomeCard(),
        SizedBox(height: 16),
        SkeletonMeterCard(),
        SizedBox(height: 8),
        SkeletonMeterCard(),
      ]),
    );
  }
}
