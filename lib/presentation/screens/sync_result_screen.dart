import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../data/repositories/meter_repository.dart';

class SyncResultScreen extends StatelessWidget {
  final SyncResult result;

  const SyncResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final hasErrors = result.hasErrors;
    final hasGlobalError = result.globalError != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Illustration
                    Center(
                      child: SizedBox(
                        width: 192,
                        height: 192,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Background Blob
                            Container(
                              width: 170,
                              height: 170,
                              decoration: BoxDecoration(
                                color: (hasErrors ? AppColors.error : AppColors.primary).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                            ),
                            // Inner Circle
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: (hasErrors ? AppColors.error : AppColors.primary).withValues(alpha: 0.1),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  hasErrors ? Icons.warning_amber_rounded : Icons.speed_rounded,
                                  size: 80,
                                  color: (hasErrors ? AppColors.error : AppColors.primary).withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                            // Status Badge
                            Positioned(
                              bottom: 20,
                              right: 20,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: hasErrors ? AppColors.error : AppColors.success,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.background, width: 4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  hasErrors ? Icons.close_rounded : Icons.check_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Text Content
                    Text(
                      hasErrors 
                          ? 'Sincronización con errores' 
                          : '¡Lecturas guardadas!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A), // Slate 900
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      hasGlobalError
                          ? 'Hubo un problema al contactar con el servidor. Tus lecturas están a salvo localmente.'
                          : (hasErrors
                              ? 'Se subieron ${result.synced} lecturas, pero ${result.errors} tuvieron errores (ej: abonado no existe). Revisa los detalles en el inicio.'
                              : 'Las ${result.synced} lecturas se han enviado correctamente al servidor. Puedes continuar con tu trabajo o volver al inicio.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF64748B), // Slate 500
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Error summary snippet if there are errors
                    // Global Error details if present
                    if (hasGlobalError)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              result.globalError!,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.error),
                            ),
                            if (result.globalErrorDetails.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              ...result.globalErrorDetails.map((msg) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• ', style: TextStyle(color: AppColors.error, fontSize: 14)),
                                    Expanded(child: Text(msg, style: const TextStyle(color: AppColors.error, fontSize: 14))),
                                  ],
                                ),
                              )),
                            ],
                          ],
                        ),
                      )
                    // Else Error summary snippet if there are individual errors
                    else if (hasErrors)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border, width: 0.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${result.errors} medidores rechazados', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                      Text('Requieren corrección', style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Footer Action
            Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  shadowColor: AppColors.primary.withValues(alpha: 0.4),
                ),
                onPressed: () {
                  if (hasErrors) {
                    // Navigate directly to the errors filter
                    context.go('/meters?filter=errors');
                  } else {
                    context.go('/home');
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      hasErrors ? 'Ver errores en Inicio' : 'Volver a Inicio',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
