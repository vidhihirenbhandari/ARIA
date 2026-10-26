import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class VoiceInputButton extends StatefulWidget {
  final bool isRecording;
  final VoidCallback onTap;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;

  const VoiceInputButton({
    super.key,
    required this.isRecording,
    required this.onTap,
    this.onLongPressStart,
    this.onLongPressEnd,
  });

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(VoiceInputButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !oldWidget.isRecording) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPressStart: widget.onLongPressStart != null
          ? (_) => widget.onLongPressStart!()
          : null,
      onLongPressEnd: widget.onLongPressEnd != null
          ? (_) => widget.onLongPressEnd!()
          : null,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (_, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              if (widget.isRecording)
                Container(
                  width: 48 * _pulseAnimation.value,
                  height: 48 * _pulseAnimation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.error.withOpacity(0.2),
                  ),
                ),
              child!,
            ],
          );
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isRecording
                ? AppColors.error.withOpacity(0.9)
                : AppColors.surface,
            border: Border.all(
              color: widget.isRecording ? AppColors.error : AppColors.border,
            ),
          ),
          child: Icon(
            widget.isRecording ? Icons.stop_rounded : Icons.mic_outlined,
            color: widget.isRecording ? Colors.white : AppColors.textSecondary,
            size: 22,
          ),
        ),
      ),
    );
  }
}
