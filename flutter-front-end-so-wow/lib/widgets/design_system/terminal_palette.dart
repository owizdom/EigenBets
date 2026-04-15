import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

/// Extended palette for the trading-terminal aesthetic. Layers on top of
/// [AppTheme] without replacing it.
///
/// The visual vocabulary is intentionally restrained: hairline borders, small
/// LED-style accent colors, and high-contrast text. Every glow is calibrated
/// to read as instrumentation, not candy.
class TerminalPalette {
  // ── Grid / instrumentation tones ─────────────────────────────────────────
  static const Color gridLine = Color(0x22CBD5E1);        // 13% slate — barely-there grid
  static const Color gridLineStrong = Color(0x55CBD5E1);  // accent grid line
  static const Color hairline = Color(0x22FFFFFF);        // 13% white divider
  static const Color ledGreen = Color(0xFF34D399);        // Emerald 400 — "up" glow
  static const Color ledRed = Color(0xFFF87171);          // Red 400 — "down" glow
  static const Color ledAmber = Color(0xFFFBBF24);        // Amber 400 — "caution"
  static const Color ledCyan = Color(0xFF22D3EE);         // Cyan 400 — "live"
  static const Color ledViolet = Color(0xFFA78BFA);       // Violet 400 — "resolved"

  // ── Deeper surface tints for layered cards ───────────────────────────────
  static const Color deepSurface = Color(0xFF111827);     // Gray 900
  static const Color glassSurface = Color(0xE61E293B);    // Slate 800 @ 90%

  // ── Multi-outcome palette (high-contrast, colorblind-safe-ish) ───────────
  static const List<Color> outcomeCycle = <Color>[
    Color(0xFF34D399), // emerald
    Color(0xFFF87171), // red
    Color(0xFF22D3EE), // cyan
    Color(0xFFFBBF24), // amber
    Color(0xFFA78BFA), // violet
    Color(0xFFF472B6), // pink
    Color(0xFF60A5FA), // blue
    Color(0xFF4ADE80), // green
    Color(0xFFFB923C), // orange
    Color(0xFFE879F9), // fuchsia
  ];

  static Color outcomeColorAt(int index) =>
      outcomeCycle[index % outcomeCycle.length];

  // ── Motion tokens ────────────────────────────────────────────────────────
  static const Duration ledOn = Duration(milliseconds: 520);
  static const Duration ledOff = Duration(milliseconds: 220);
  static const Duration cellCascade = Duration(milliseconds: 38);
  static const Duration chartEntry = Duration(milliseconds: 900);
  static const Duration meterSettle = Duration(milliseconds: 620);
  static const Duration feedStagger = Duration(milliseconds: 55);
  static const Duration hoverLift = Duration(milliseconds: 140);
  static const Duration shimmerCycle = Duration(milliseconds: 1400);
  static const Duration medalSweep = Duration(milliseconds: 2800);

  static const Curve meterCurve = Curves.easeOutCubic;
  static const Curve chartCurve = Cubic(0.22, 1.0, 0.36, 1.0); // cubic out-expo-ish
  static const Curve hoverCurve = Curves.easeOutCubic;

  // ── Typography helpers ───────────────────────────────────────────────────

  /// Tabular-figures style for any numeric readout. Uses JetBrains Mono so it
  /// reads as instrument data rather than prose.
  static TextStyle mono(BuildContext context, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize ?? 13,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color ?? AppTheme.textPrimary,
      letterSpacing: letterSpacing ?? 0,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
  }

  /// Micro-cap label used for categories, section headers, status chips.
  /// Tiny, high-tracking, all-caps — broadcast-news aesthetic.
  static TextStyle microCap(BuildContext context, {
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize ?? 10,
      fontWeight: fontWeight ?? FontWeight.w700,
      color: color ?? AppTheme.textSecondary.withOpacity(0.7),
      letterSpacing: 1.6,
      height: 1.2,
    );
  }
}
