/// Glassmorphic Card Widget
/// 
/// A modern glass-effect card with blur and gradient borders
/// used throughout the app for a premium look.

import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/constants.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Gradient? gradient;
  final double blur;
  final Color? backgroundColor;
  final bool showBorder;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.gradient,
    this.blur = 10,
    this.backgroundColor,
    this.showBorder = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: padding ?? const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: gradient ?? LinearGradient(
                  colors: [
                    (backgroundColor ?? AppColors.glassWhite).withValues(alpha: 0.15),
                    (backgroundColor ?? AppColors.glassWhite).withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(borderRadius),
                border: showBorder ? Border.all(
                  color: AppColors.glassBorder.withValues(alpha: 0.2),
                  width: 1,
                ) : null,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated gradient border card
class GradientBorderCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double borderWidth;
  final List<Color> gradientColors;
  final bool animate;
  final Duration animationDuration;
  final VoidCallback? onTap;

  const GradientBorderCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.borderWidth = 2,
    this.gradientColors = const [
      AppColors.primaryStart,
      AppColors.accent,
      AppColors.primaryEnd,
    ],
    this.animate = true,
    this.animationDuration = const Duration(seconds: 3),
    this.onTap,
  });

  @override
  State<GradientBorderCard> createState() => _GradientBorderCardState();
}

class _GradientBorderCardState extends State<GradientBorderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: SweepGradient(
              colors: [
                ...widget.gradientColors,
                widget.gradientColors.first,
              ],
              transform: GradientRotation(_controller.value * 2 * 3.14159),
            ),
          ),
          child: Container(
            margin: EdgeInsets.all(widget.borderWidth),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(
                widget.borderRadius - widget.borderWidth,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(
                  widget.borderRadius - widget.borderWidth,
                ),
                child: Padding(
                  padding: widget.padding ?? const EdgeInsets.all(20),
                  child: widget.child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Shimmer loading effect
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final bool isLoading;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.isLoading = true,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Colors.grey,
                Colors.white,
                Colors.grey,
              ],
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ].map((e) => e.clamp(0.0, 1.0)).toList(),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
    );
  }
}
