import 'package:flutter/material.dart';
import '../models/market_data.dart';
import '../theme/app_theme.dart';
import 'design_system/probability_meter.dart';
import 'design_system/terminal_palette.dart';
import 'design_system/trading_card.dart';

/// Displays N outcome options as stacked horizontal probability meters.
/// Selection is visually emphasised with a glow ring and a lit conviction
/// bullet — the design system's segmented meter replaces the smooth bar.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outcomes = market.outcomes;
    final totalPrice = outcomes.fold<double>(0, (sum, o) => sum + o.price);

    int topIdx = 0;
    double topPrice = -double.infinity;
    for (int i = 0; i < outcomes.length; i++) {
      if (outcomes[i].price > topPrice) {
        topPrice = outcomes[i].price;
        topIdx = i;
      }
    }
    final stripeColor = TerminalPalette.outcomeColorAt(topIdx);

    return TradingCard(
      stripeColor: stripeColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row.
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.38),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  market.marketType == MarketType.multiChoice
                      ? 'MULTI-CHOICE'
                      : market.marketType == MarketType.range
                          ? 'RANGE'
                          : 'YES / NO',
                  style: TerminalPalette.microCap(context,
                      color: AppTheme.primaryColor, fontSize: 9.5),
                ),
              ),
              const Spacer(),
              Text(
                'OUTCOMES · ${outcomes.length}',
                style: TerminalPalette.microCap(context,
                    color: theme.colorScheme.onSurface.withOpacity(0.5)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Stacked single-bar view — each outcome gets a slice proportional
          // to its normalized price, rendered as a single flowing meter.
          _StackedMeterBar(outcomes: outcomes, totalPrice: totalPrice),
          const SizedBox(height: 16),

          // Individual outcome rows, each tappable.
          ...List.generate(outcomes.length, (i) {
            final outcome = outcomes[i];
            final isSelected = selectedIndex == i;
            final color = TerminalPalette.outcomeColorAt(i);
            final normalized = totalPrice > 0
                ? outcome.price / totalPrice
                : 1.0 / outcomes.length;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOutcomeSelected != null
                  ? () => onOutcomeSelected!(i)
                  : null,
              child: AnimatedContainer(
                duration: TerminalPalette.hoverLift,
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withOpacity(0.10)
                      : TerminalPalette.deepSurface.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? color.withOpacity(0.85)
                        : theme.dividerColor,
                    width: isSelected ? 1.2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.28),
                            blurRadius: 14,
                            spreadRadius: -3,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(isSelected ? 0.7 : 0.3),
                                blurRadius: isSelected ? 8 : 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            outcome.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isSelected
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurface
                                      .withOpacity(0.8),
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '${(normalized * 100).toStringAsFixed(1)}%',
                          style: TerminalPalette.mono(
                            context,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ProbabilityMeter(
                      value: normalized,
                      color: color,
                      height: 7,
                      segmentCount: 20,
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

/// A single flowing bar split into outcome slices. Unlike the old solid-color
/// blocks, each slice here has a tiny micro-gap and the leading edge of each
/// slice bleeds into a glow — all outcomes visible in one glance.
class _StackedMeterBar extends StatelessWidget {
  final List<Outcome> outcomes;
  final double totalPrice;

  const _StackedMeterBar({
    required this.outcomes,
    required this.totalPrice,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 10,
      child: Row(
        children: List.generate(outcomes.length, (i) {
          final fraction = totalPrice > 0
              ? outcomes[i].price / totalPrice
              : 1.0 / outcomes.length;
          final color = TerminalPalette.outcomeColorAt(i);
          return Expanded(
            flex: (fraction * 1000).round().clamp(1, 1000),
            child: Container(
              margin: EdgeInsets.only(right: i == outcomes.length - 1 ? 0 : 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    color.withOpacity(0.85),
                    color,
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.55),
                    blurRadius: 6,
                    spreadRadius: -2,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
