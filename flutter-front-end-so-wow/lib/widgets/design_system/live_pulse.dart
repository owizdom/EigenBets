import 'package:flutter/material.dart';
import 'terminal_palette.dart';

/// Hard-cutoff LED indicator. Not a smooth fade — it snaps on, stays on for
/// [TerminalPalette.ledOn], then snaps off for [TerminalPalette.ledOff].
/// Mimics the blink of a hardware status light rather than a breathing dot.
class LivePulse extends StatefulWidget {
  final Color color;
  final double size;
  final bool active;

  const LivePulse({
    Key? key,
    this.color = TerminalPalette.ledCyan,
    this.size = 7,
    this.active = true,
  }) : super(key: key);

  @override
  State<LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<LivePulse> with SingleTickerProviderStateMixin {
  bool _on = true;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    if (_disposed || !mounted || !widget.active) return;
    final next = _on ? TerminalPalette.ledOn : TerminalPalette.ledOff;
    Future<void>.delayed(next, () {
      if (_disposed || !mounted) return;
      setState(() => _on = !_on);
      _schedule();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 60),
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: _on
            ? widget.color
            : widget.color.withOpacity(0.18),
        shape: BoxShape.circle,
        boxShadow: _on
            ? [
                BoxShadow(
                  color: widget.color.withOpacity(0.55),
                  blurRadius: widget.size * 1.8,
                  spreadRadius: 0.5,
                ),
              ]
            : const [],
      ),
    );
  }
}

/// LED + label pair (e.g., "● LIVE"). Small caps label, tabular mono font.
class LiveBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;

  const LiveBadge({
    Key? key,
    this.label = 'LIVE',
    this.color = TerminalPalette.ledCyan,
    this.active = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LivePulse(color: color, active: active),
        const SizedBox(width: 6),
        Text(
          label,
          style: TerminalPalette.microCap(context,
              color: color, fontSize: 9.5),
        ),
      ],
    );
  }
}
