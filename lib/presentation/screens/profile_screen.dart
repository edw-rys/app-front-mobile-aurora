import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/helpers.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../providers/auth_provider.dart';
import '../providers/meters_provider.dart';
import '../providers/readings_provider.dart';
import '../widgets/map_download_dialog.dart';
import '../widgets/gps_onboarding_sheet.dart';

import '../../app/di/injection.dart';
import '../../data/services/local/preferences_service.dart';

/// Profile screen - matches mockup 10
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with WidgetsBindingObserver {
  bool _autoSync = false;
  bool _hasLocationPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAutoSync();
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final status = await Permission.locationWhenInUse.status;
    if (mounted) {
      setState(() => _hasLocationPermission = status.isGranted);
    }
  }

  Future<void> _loadAutoSync() async {
    final v = await getIt<PreferencesService>().getAutoSyncEnabled();
    if (mounted) setState(() => _autoSync = v);
  }

  Future<void> _setAutoSync(bool v) async {
    await getIt<PreferencesService>().setAutoSyncEnabled(v);
    setState(() => _autoSync = v);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final metersState = ref.watch(metersProvider);
    final user = authState.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: SkeletonProfileCard()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          AppStrings.profile,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // User card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        Helpers.getInitials(user.fullName),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppColors.primary,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.fullName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (user.email != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      user.email!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  if (user.role != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        user.role!.roleName,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.primary,
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stats card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat(
                    context,
                    '${metersState.stats['total'] ?? 0}',
                    'Total',
                  ),
                  _buildStat(
                    context,
                    '${metersState.stats['read'] ?? 0}',
                    'Leídos',
                  ),
                  _buildStat(
                    context,
                    '${metersState.stats['pending'] ?? 0}',
                    'Pendientes',
                  ),
                  _buildStat(
                    context,
                    '${metersState.stats['unsynced'] ?? 0}',
                    'Sin enviar',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Auto-sync setting ───────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: SwitchListTile.adaptive(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                secondary: Icon(Icons.sync_rounded, color: AppColors.primary),
                title: const Text('Envío automático',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text(
                  'Envía cada lectura al servidor al guardarse localmente',
                  style: TextStyle(fontSize: 12),
                ),
                value: _autoSync,
                onChanged: _setAutoSync,
                activeColor: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),

            // Actions
            _buildActionTile(
              context,
              icon: Icons.auto_stories_rounded,
              label: 'Guía de usuario',
              onTap: () => context.push('/user-guide'),
            ),
            const SizedBox(height: 8),
            _buildActionTile(
              context,
              icon: Icons.file_download_outlined,
              label: AppStrings.exportCSV,
              enabled: metersState.meters.isNotEmpty,
              onTap: () => _exportCSV(context, ref),
            ),
            const SizedBox(height: 8),
            _buildActionTile(
              context,
              icon: Icons.map_rounded,
              label: 'Descargar mapa',
              enabled: metersState.meters.isNotEmpty,
              onTap: () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => const MapDownloadDialog(),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildActionTile(
              context,
              icon: Icons.restore_rounded,
              label: 'Restaurar datos',
              isDestructive: true,
              enabled: metersState.meters.isNotEmpty,
              onTap: () => _handleRestore(context, ref),
            ),
            if (!_hasLocationPermission) ...[
              const SizedBox(height: 8),
              _buildActionTile(
                context,
                icon: Icons.location_on_outlined,
                label: 'Permisos de ubicación',
                onTap: () => GpsOnboardingSheet.show(context, onPermissionGranted: _checkPermission),
              ),
            ],
            const SizedBox(height: 8),
            _buildActionTile(
              context,
              icon: Icons.logout_rounded,
              label: AppStrings.logout,
              isDestructive: true,
              onTap: () => _handleLogout(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.primary,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDestructive ? AppColors.error : AppColors.textSecondary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isDestructive ? AppColors.error : null,
                      fontWeight: enabled ? FontWeight.w500 : FontWeight.normal,
                    ),
              ),
              const Spacer(),
              if (enabled)
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportCSV(BuildContext context, WidgetRef ref) async {
    try {
      final csvData = await ref.read(readingsProvider.notifier).exportCSV();
      if (csvData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay datos para exportar')),
        );
        return;
      }

      final csv = const CsvEncoder().convert(csvData);
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/lecturas_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(csv);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV exportado: ${file.path}'),
            backgroundColor: AppColors.success,
          ),
        );
      }

      // Native share automatically after saving
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Lecturas Exportadas',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleRestore(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Restaurar datos'),
          ],
        ),
        content: const Text(
          'Se eliminarán todas las lecturas y medidores guardados localmente, '
          'y se reiniciará el estado de trabajo.\n\n'
          '⚠️ Esta acción no se puede deshacer.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Sí, restaurar'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // Atomically clears DB + resets prefs + resets in-memory state
      await ref.read(metersProvider.notifier).resetAllData();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Datos restaurados correctamente'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          'Las lecturas guardadas localmente se mantendrán en el dispositivo.',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Trigger logout (non-blocking in repository now)
      ref.read(authProvider.notifier).logout();
      
      // Navigate immediately
      if (context.mounted) {
        context.go('/login');
      }
    }
  }
}
