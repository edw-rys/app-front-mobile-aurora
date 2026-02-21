import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_colors.dart';

class GpsOnboardingSheet extends StatelessWidget {
  final VoidCallback? onPermissionGranted;

  const GpsOnboardingSheet({super.key, this.onPermissionGranted});

  static Future<void> show(BuildContext context, {VoidCallback? onPermissionGranted}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GpsOnboardingSheet(onPermissionGranted: onPermissionGranted),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 16),
          
          // Animation
          SizedBox(
            height: 200,
            child: Lottie.asset(
              'assets/lotties/GPSLocationAnimation.json',
              repeat: true,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Activa tu ubicación',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Necesitamos saber tu ubicación para georreferenciar los medidores y mostrarte la ruta más corta.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          ElevatedButton(
            onPressed: () => _requestPermission(context),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Dar permisos'),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
            ),
            child: const Text(
              'En otro momento',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestPermission(BuildContext context) async {
    final status = await Permission.locationWhenInUse.request();
    
    if (status.isGranted) {
      if (context.mounted) {
        Navigator.pop(context);
        onPermissionGranted?.call();
      }
    } else if (status.isPermanentlyDenied) {
      if (context.mounted) {
        _showSettingsDialog(context);
      }
    }
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permiso necesario'),
        content: const Text(
          'Los permisos de ubicación están desactivados permanentemente. Por favor, actívalos en los ajustes de tu dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Abrir Ajustes'),
          ),
        ],
      ),
    );
  }
}
