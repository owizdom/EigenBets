import 'package:flutter/material.dart';
import '../models/market_data.dart';
import '../theme/app_theme.dart';

/// Displays N outcome options as stacked horizontal probability bars
class MultiOutcomeCard extends StatelessWidget {
  final MarketData market;
  final int? selectedIndex;
  final ValueChanged<int>? onOutcomeSelected;

  const MultiOutcomeCard({
    super.key,
    required this.market,
    this.selectedIndex,
    this.onOutcomeSelected,
  });

  static const List<Color> _outcomeColors = [
    AppTheme.successColor,
    AppTheme.errorColor,
    AppTheme.infoColor,
    AppTheme.warningColor,
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Pink
    Color(0xFF14B8A6), // Teal
    Color(0xFFF97316), // Orange
    Color(0xFF6366F1), // Indigo
    Color(0xFF84CC16), // Lime
  ];

  @override
  Widget build(BuildContext context) {
    final outcomes = market.outcomes;
    final totalPrice = outcomes.fold<double>(0, (sum, o) => sum + o.price);

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
          // Market type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              market.marketType == MarketType.multiChoice
                  ? 'MULTI-CHOICE'
                  : market.marketType == MarketType.range
                      ? 'RANGE'
                      : 'YES / NO',
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Stacked probability bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 24,
              child: Row(
                children: List.generate(outcomes.length, (i) {
                  final fraction = totalPrice > 0
                      ? outcomes[i].price / totalPrice
                      : 1.0 / outcomes.length;
                  return Expanded(
                    flex: (fraction * 1000).round().clamp(1, 1000),
                    child: Container(
                      color: _outcomeColors[i % _outcomeColors.length],
                      alignment: Alignment.center,
                      child: fraction > 0.08
                          ? Text(
                              '${(fraction * 100).round()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Individual outcome rows
          ...List.generate(outcomes.length, (i) {
            final outcome = outcomes[i];
            final isSelected = selectedIndex == i;
            final color = _outcomeColors[i % _outcomeColors.length];
            final pct = totalPrice > 0
                ? (outcome.price / totalPrice * 100).round()
                : (100 / outcomes.length).round();

            return GestureDetector(
              onTap: onOutcomeSelected != null
                  ? () => onOutcomeSelected!(i)
                  : null,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withOpacity(0.15)
                      : AppTheme.cardColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? color : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        outcome.label,
                        style: TextStyle(
                          color: isSelected
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
