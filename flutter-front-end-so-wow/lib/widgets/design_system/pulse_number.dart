import 'package:flutter/material.dart';
import 'terminal_palette.dart';

/// A numeric readout that flashes when the underlying [value] changes —
/// a hardware-ticker "data updated" signal. No easing on the flash, just a
/// hard cutoff that fades over ~320ms. Use for live price/volume/odds.
class PulseNumber extends StatefulWidget {
  final String value;
  final TextStyle? style;
  final Color? flashColor;
  final TextAlign? textAlign;

  const PulseNumber({
    Key? key,
    required this.value,
    this.style,
    this.flashColor,
    this.textAlign,
  }) : super(key: key);

  @override
  State<PulseNumber> createState() => _PulseNumberState();
}

class _PulseNumberState extends State<PulseNumber>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void didUpdateWidget(covariant PulseNumber old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _controller.forward(from: 1.0);
      _controller.animateTo(0.0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.style ?? TerminalPalette.mono(context);
    final flash = widget.flashColor ?? TerminalPalette.ledCyan;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final color = Color.lerp(base.color, flash, t);
        return Text(
          widget.value,
          textAlign: widget.textAlign,
          style: base.copyWith(
            color: color,
            shadows: t > 0
                ? [
                    Shadow(
                      color: flash.withOpacity(0.6 * t),
                      blurRadius: 6 * t,
                    ),
                  ]
                : const [],
          ),
        );
      },
    );
  }
}
