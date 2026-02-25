import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_colors.dart';

class CameraOnboardingSheet extends StatelessWidget {
  final VoidCallback? onPermissionGranted;

  const CameraOnboardingSheet({super.key, this.onPermissionGranted});

  static Future<void> show(BuildContext context, {VoidCallback? onPermissionGranted}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CameraOnboardingSheet(onPermissionGranted: onPermissionGranted),
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
          
          // Icon Animation/Display
          Container(
            height: 120,
            width: 120,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.camera_alt_rounded,
              size: 64,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Cámara y archivos',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Necesitamos acceso a la cámara y a tus archivos para poder capturar y guardar las fotos de los medidores.',
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
    // Determine the permissions to request
    List<Permission> permissionsToRequest = [Permission.camera];
    
    // Requesting storage is tricky across Android versions, so we request it but don't strictly fail if it's denied, 
    // as we just save to app documents directory which might not need it in Android 10+. 
    // Nonetheless, we request it as requested by the user.
    if (Platform.isAndroid) {
      permissionsToRequest.add(Permission.storage);
    } else if (Platform.isIOS) {
      permissionsToRequest.add(Permission.photos);
    }

    final statuses = await permissionsToRequest.request();
    
    // We mainly care about the camera permission to proceed with photo features
    final cameraStatus = statuses[Permission.camera];
    
    if (cameraStatus != null && cameraStatus.isGranted) {
      if (context.mounted) {
        Navigator.pop(context);
        onPermissionGranted?.call();
      }
    } else if (cameraStatus != null && cameraStatus.isPermanentlyDenied) {
      if (context.mounted) {
        _showSettingsDialog(context);
      }
    } else {
      // Just popped if denied but not permanently
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permiso necesario'),
        content: const Text(
          'Los permisos de cámara están desactivados permanentemente. Por favor, actívalos en los ajustes de tu dispositivo.',
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
