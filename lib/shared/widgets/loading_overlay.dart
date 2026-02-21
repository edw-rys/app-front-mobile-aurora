import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Full-screen loading overlay with smooth animations.
/// Used for both download and sync operations.
/// Must be shown via showGeneralDialog to cover everything including bottom nav.
class LoadingOverlay extends StatefulWidget {
  final int currentProgress;
  final int totalCount;
  final bool isComplete;
  final String? statusMessage;
  final String title;
  final IconData activeIcon;
  final VoidCallback? onDismiss;

  const LoadingOverlay({
    super.key,
    this.currentProgress = 0,
    this.totalCount = 0,
    this.isComplete = false,
    this.statusMessage,
    this.title = 'Sincronizando...',
    this.activeIcon = Icons.cloud_upload_rounded,
    this.onDismiss,
  });

  @override
  State<LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<LoadingOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _checkController;
  late AnimationController _progressFadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _checkScale;
  late Animation<double> _progressFade;

  @override
  void initState() {
    super.initState();

    // Pulse animation for the active icon
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Check mark animation
    _checkController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.elasticOut),
    );

    // Progress text fade
    _progressFadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
      value: 1.0,
    );

    _progressFade = CurvedAnimation(
      parent: _progressFadeController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didUpdateWidget(LoadingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Trigger check animation on complete
    if (widget.isComplete && !oldWidget.isComplete) {
      _pulseController.stop();
      _pulseController.value = 1.0;
      _checkController.forward();
    }

    // Animate progress text changes
    if (widget.currentProgress != oldWidget.currentProgress) {
      _progressFadeController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _checkController.dispose();
    _progressFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.totalCount > 0
        ? widget.currentProgress / widget.totalCount
        : 0.0;

    if (widget.title == 'Enviando lecturas...') {
      return _buildSyncingLayout(context, progress);
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.black54,
        child: SafeArea(
          top: false,
          bottom: false,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated icon area
                  _buildAnimatedIcon(),
                  const SizedBox(height: 28),

                  // Title
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      widget.isComplete ? '¡Completado!' : widget.title,
                      key: ValueKey(widget.isComplete),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Status message with fade animation
                  if (widget.statusMessage != null)
                    FadeTransition(
                      opacity: _progressFade,
                      child: Text(
                        widget.statusMessage!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Progress bar (smooth animated)
                  if (!widget.isComplete && widget.totalCount > 0) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                        builder: (context, value, _) {
                          return LinearProgressIndicator(
                            value: value,
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.1),
                            valueColor: const AlwaysStoppedAnimation(
                                AppColors.primary),
                            minHeight: 8,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${widget.currentProgress} / ${widget.totalCount}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],

                  // Complete indicator
                  if (widget.isComplete) ...[
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 400),
                      builder: (context, value, _) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: value,
                            backgroundColor:
                                AppColors.success.withValues(alpha: 0.1),
                            valueColor: const AlwaysStoppedAnimation(
                                AppColors.success),
                            minHeight: 8,
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSyncingLayout(BuildContext context, double progress) {
    final isDone = widget.isComplete;
    final progressVal = isDone ? 1.0 : progress;

    return Material(
      color: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            // Top Nav Spacer
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Align(
                alignment: Alignment.center,
                child: Text('SINCRONIZANDO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 2)),
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Illustration String
                    SizedBox(
                      height: 200,
                      width: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (!isDone) 
                            RotationTransition(
                              turns: _pulseController, // smooth rotation reusing pulse controller
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 4),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border(top: BorderSide(color: AppColors.primary, width: 4)),
                                  ),
                                ),
                              ),
                            ),
                          Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.background, width: 8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(isDone ? Icons.check_circle_rounded : Icons.water_drop_rounded, size: 60, color: isDone ? AppColors.success : AppColors.primary),
                                if (!isDone)
                                  Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${widget.currentProgress}/${widget.totalCount}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isDone)
                            Positioned(
                              bottom: 16,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 4),
                                ),
                                child: const Icon(Icons.check, color: Colors.white, size: 20),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Text
                    Text(
                      isDone ? 'Lecturas guardadas' : 'Guardando tu lectura',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary, height: 1.2),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.statusMessage ?? 'Tu lectura se está enviando de forma segura a nuestros servidores',
                      style: const TextStyle(fontSize: 16, color: AppColors.textSecondary, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Timeline
                    SizedBox(
                      height: 80,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: 24,
                            left: 30,
                            right: 30,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progressVal, // 0 to 1
                                backgroundColor: AppColors.border,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                minHeight: 4,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildTimelineStep(Icons.wifi, 'Conectado', true),
                              _buildTimelineStep(Icons.cloud_upload, 'Enviando', progressVal > 0),
                              _buildTimelineStep(Icons.verified, 'Completado', isDone),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep(IconData icon, String label, bool active) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.background,
            shape: BoxShape.circle,
            border: Border.all(color: active ? AppColors.primary : AppColors.border, width: active ? 0 : 1),
            boxShadow: active ? [
              BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 2)
            ] : null,
          ),
          child: Icon(icon, color: active ? Colors.white : AppColors.textSecondary, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.bold : FontWeight.w500, color: active ? AppColors.primary : AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildAnimatedIcon() {
    if (widget.isComplete) {
      return ScaleTransition(
        scale: _checkScale,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.success,
                AppColors.success.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withValues(alpha: 0.3),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: 44,
          ),
        ),
      );
    }

    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Icon(
          widget.activeIcon,
          color: Colors.white,
          size: 38,
        ),
      ),
    );
  }
}

/// Helper to show the overlay as a full-screen dialog that covers everything
/// including the bottom navigation bar.
Future<void> showLoadingOverlay({
  required BuildContext context,
  required Future<void> Function() operation,
  required Stream<LoadingOverlayState> stateStream,
  String title = 'Sincronizando...',
  IconData activeIcon = Icons.cloud_upload_rounded,
}) async {
  showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ),
        child: child,
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) {
      return StreamOverlay(
        stateStream: stateStream,
        title: title,
        activeIcon: activeIcon,
      );
    },
  );

  await operation();
}

/// State object passed through the stream
class LoadingOverlayState {
  final int current;
  final int total;
  final bool isComplete;
  final String? message;
  final bool shouldDismiss;

  const LoadingOverlayState({
    this.current = 0,
    this.total = 0,
    this.isComplete = false,
    this.message,
    this.shouldDismiss = false,
  });
}

/// Internal widget that listens to a stream to update the overlay
class StreamOverlay extends StatefulWidget {
  final Stream<LoadingOverlayState> stateStream;
  final String title;
  final IconData activeIcon;

  const StreamOverlay({
    super.key,
    required this.stateStream,
    required this.title,
    required this.activeIcon,
  });

  @override
  State<StreamOverlay> createState() => _StreamOverlayState();
}

class _StreamOverlayState extends State<StreamOverlay> {
  LoadingOverlayState _state = const LoadingOverlayState();
  StreamSubscription<LoadingOverlayState>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.stateStream.listen((newState) {
      if (!mounted) return;
      if (newState.shouldDismiss) {
        // Use maybePop and rootNavigator to avoid crashes if the dialog was already dismissed
        // or if the underlying route changed (e.g. during force logout redirect)
        Navigator.of(context, rootNavigator: true).maybePop();
        return;
      }
      setState(() => _state = newState);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      currentProgress: _state.current,
      totalCount: _state.total,
      isComplete: _state.isComplete,
      statusMessage: _state.message,
      title: widget.title,
      activeIcon: widget.activeIcon,
    );
  }
}
