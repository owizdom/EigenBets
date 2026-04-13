import 'package:flutter/material.dart';
import '../models/market_data.dart';
import '../theme/app_theme.dart';

/// A slider widget for range-based prediction markets
/// Shows outcome bands with the crowd's current prediction highlighted
class RangePredictionSlider extends StatelessWidget {
  final MarketData market;
  final int? selectedBand;
  final ValueChanged<int>? onBandSelected;

  const RangePredictionSlider({
    super.key,
    required this.market,
    this.selectedBand,
    this.onBandSelected,
  });

  static const List<Color> _bandColors = [
    Color(0xFF3B82F6), // Blue
    Color(0xFF10B981), // Green
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Red
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Pink
    Color(0xFF14B8A6), // Teal
    Color(0xFFF97316), // Orange
  ];

  @override
  Widget build(BuildContext context) {
    final outcomes = market.outcomes;
    final rangeMin = market.rangeMin ?? 0;
    final rangeMax = market.rangeMax ?? 100;
    final totalPrice = outcomes.fold<double>(0, (sum, o) => sum + o.price);

    // Find the band with highest probability (crowd prediction)
    int crowdPick = 0;
    double maxPrice = 0;
    for (int i = 0; i < outcomes.length; i++) {
      if (outcomes[i].price > maxPrice) {
        maxPrice = outcomes[i].price;
        crowdPick = i;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.subtleAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'RANGE',
                  style: TextStyle(
                    color: AppTheme.warningColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${rangeMin.toStringAsFixed(0)} - ${rangeMax.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Range bands visualization
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 48,
              child: Row(
                children: List.generate(outcomes.length, (i) {
                  final fraction = totalPrice > 0
                      ? outcomes[i].price / totalPrice
                      : 1.0 / outcomes.length;
                  final isSelected = selectedBand == i;
                  final isCrowdPick = i == crowdPick;
                  final color = _bandColors[i % _bandColors.length];

                  return Expanded(
                    flex: (fraction * 1000).round().clamp(1, 1000),
                    child: GestureDetector(
                      onTap: onBandSelected != null
                          ? () => onBandSelected!(i)
                          : null,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color
                              : color.withOpacity(isCrowdPick ? 0.8 : 0.4),
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (fraction > 0.12)
                              Text(
                                outcomes[i].label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            Text(
                              '${(fraction * 100).round()}%',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: fraction > 0.1 ? 12 : 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Crowd prediction label
          Row(
            children: [
              const Icon(Icons.people_outline, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(
                'Crowd prediction: ${outcomes[crowdPick].label}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Band selector chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(outcomes.length, (i) {
              final isSelected = selectedBand == i;
              final color = _bandColors[i % _bandColors.length];
              final pct = totalPrice > 0
                  ? (outcomes[i].price / totalPrice * 100).round()
                  : (100 / outcomes.length).round();

              return GestureDetector(
                onTap: onBandSelected != null
                    ? () => onBandSelected!(i)
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withOpacity(0.2)
                        : AppTheme.cardColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? color : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    '${outcomes[i].label} ($pct%)',
                    style: TextStyle(
                      color: isSelected ? color : AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
