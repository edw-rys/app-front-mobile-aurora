import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Shimmer skeleton loader for loading states (GET requests)
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: const [
                Color(0xFFE2E8F0),
                Color(0xFFF1F5F9),
                Color(0xFFE2E8F0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton for a meter card
class SkeletonMeterCard extends StatelessWidget {
  const SkeletonMeterCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLoader(height: 16, width: 200),
          SizedBox(height: 8),
          SkeletonLoader(height: 12, width: 150),
          SizedBox(height: 12),
          Row(
            children: [
              SkeletonLoader(height: 24, width: 80, borderRadius: 6),
              SizedBox(width: 8),
              SkeletonLoader(height: 12, width: 100),
              Spacer(),
              SkeletonLoader(height: 12, width: 60),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton for home stats card
class SkeletonHomeCard extends StatelessWidget {
  const SkeletonHomeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: const Column(
        children: [
          Row(
            children: [
              SkeletonLoader(height: 80, width: 80, borderRadius: 40),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLoader(height: 24, width: 120),
                    SizedBox(height: 8),
                    SkeletonLoader(height: 14, width: 160),
                    SizedBox(height: 8),
                    SkeletonLoader(height: 14, width: 100),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton for profile card
class SkeletonProfileCard extends StatelessWidget {
  const SkeletonProfileCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: const Column(
        children: [
          SkeletonLoader(height: 60, width: 60, borderRadius: 30),
          SizedBox(height: 12),
          SkeletonLoader(height: 18, width: 140),
          SizedBox(height: 8),
          SkeletonLoader(height: 14, width: 180),
        ],
      ),
    );
  }
}
