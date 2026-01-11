/// URL Input Widget
/// 
/// A premium text input field for pasting URLs with
/// platform detection and visual feedback.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../utils/url_parser.dart';

class UrlInput extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onPaste;
  final bool enabled;
  final bool showPlatformIndicator;
  final String? errorText;

  const UrlInput({
    super.key,
    required this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onPaste,
    this.enabled = true,
    this.showPlatformIndicator = true,
    this.errorText,
  });

  @override
  State<UrlInput> createState() => _UrlInputState();
}

class _UrlInputState extends State<UrlInput> with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  SocialPlatform _detectedPlatform = SocialPlatform.unknown;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _glowController.repeat(reverse: true);
    
    widget.controller.addListener(_detectPlatform);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_detectPlatform);
    _glowController.dispose();
    super.dispose();
  }

  void _detectPlatform() {
    if (!widget.showPlatformIndicator) return;
    
    final url = widget.controller.text;
    final newPlatform = UrlParser.detectPlatform(url);
    
    if (newPlatform != _detectedPlatform) {
      setState(() {
        _detectedPlatform = newPlatform;
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      widget.controller.text = data.text!;
      widget.controller.selection = TextSelection.fromPosition(
        TextPosition(offset: data.text!.length),
      );
      widget.onPaste?.call();
      widget.onChanged?.call(data.text!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;
    final showPlatform = hasText && _detectedPlatform != SocialPlatform.unknown;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: _isFocused || showPlatform
                ? [
                    BoxShadow(
                      color: (showPlatform
                              ? _detectedPlatform.primaryColor
                              : AppColors.accent)
                          .withValues(alpha: 0.3 * _glowAnimation.value),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: showPlatform
                    ? [
                        _detectedPlatform.primaryColor.withValues(alpha: 0.2),
                        _detectedPlatform.primaryColor.withValues(alpha: 0.1),
                      ]
                    : [
                        AppColors.darkCard,
                        AppColors.darkCardAlt,
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.errorText != null
                    ? AppColors.error.withValues(alpha: 0.5)
                    : showPlatform
                        ? _detectedPlatform.primaryColor.withValues(alpha: 0.5)
                        : _isFocused
                            ? AppColors.accent.withValues(alpha: 0.5)
                            : AppColors.glassBorder.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // Platform indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: showPlatform ? 56 : 0,
                  height: 56,
                  curve: Curves.easeInOut,
                  child: showPlatform
                      ? Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: _detectedPlatform.gradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _detectedPlatform.icon,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        )
                      : null,
                ),
                
                // Text field
                Expanded(
                  child: Focus(
                    onFocusChange: (focused) {
                      setState(() {
                        _isFocused = focused;
                      });
                    },
                    child: TextField(
                      controller: widget.controller,
                      enabled: widget.enabled,
                      onChanged: widget.onChanged,
                      onSubmitted: widget.onSubmitted,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Paste Instagram, Facebook, or X URL...',
                        hintStyle: TextStyle(
                          color: AppColors.textMuted.withValues(alpha: 0.7),
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: showPlatform ? 8 : 20,
                          vertical: 18,
                        ),
                      ),
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.go,
                      autocorrect: false,
                    ),
                  ),
                ),
                
                // Clear/Paste button
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: hasText
                      ? IconButton(
                          onPressed: () {
                            widget.controller.clear();
                            widget.onChanged?.call('');
                          },
                          icon: const Icon(Icons.close_rounded),
                          color: AppColors.textMuted,
                          iconSize: 22,
                        )
                      : TextButton.icon(
                          onPressed: widget.enabled ? _pasteFromClipboard : null,
                          icon: const Icon(Icons.content_paste_rounded, size: 18),
                          label: const Text('Paste'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.accent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          
          // Error text
          if (widget.errorText != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 14,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.errorText!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Platform label
          if (showPlatform)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: _detectedPlatform.primaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_detectedPlatform.displayName} detected',
                    style: TextStyle(
                      color: _detectedPlatform.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
