import 'package:flutter/material.dart';
import '../models/market_data.dart';
import '../theme/app_theme.dart';
import 'design_system/live_pulse.dart';
import 'design_system/probability_meter.dart';
import 'design_system/pulse_number.dart';
import 'design_system/sparkline.dart';
import 'design_system/terminal_palette.dart';
import 'design_system/trading_card.dart';

/// Redesigned market card for the prediction-markets "trading terminal"
/// aesthetic. Same public signature as before — existing call sites pass
/// `MarketData market` + optional `onTap`.
///
/// Anatomy (binary market):
///   • Left-edge conviction stripe colored by the dominant outcome
///   • Top row: CATEGORY micro-cap · Vol readout · LIVE/VERIFIED/EXPIRED badge
///   • Title (tight display style) + optional description (one line, muted)
///   • Sparkline of recent price history ([market.priceHistory])
///   • Two stacked outcome meters (Yes / No) with tabular percentages that
///     pulse when the underlying price changes
///   • Footer: expiry countdown + chevron glyph hinting the tappable affordance
class MarketCard extends StatelessWidget {
  final MarketData market;
  final VoidCallback? onTap;

  const MarketCard({
    Key? key,
    required this.market,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMulti = market.marketType != MarketType.binary;

    final outcomes = market.outcomes;
    final outcomePrices = outcomes.map((o) => o.price).toList();
    final topPrice = outcomePrices.isEmpty
        ? 0.5
        : outcomePrices.reduce((a, b) => a > b ? a : b);

    final stripeBase = dominantOutcomeColor(outcomePrices);
    final stripe = convictionStripe(topPrice: topPrice, baseColor: stripeBase);

    final sparkValues = market.priceHistory.isNotEmpty
        ? market.priceHistory.map((p) => p.price).toList()
        : _syntheticSpark(market.yesPrice);

    return TradingCard(
      onTap: onTap,
      stripeColor: stripe,
      padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _TopRow(market: market),
          const SizedBox(height: 10),
          Text(
            market.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              height: 1.22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          if (market.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              market.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.55),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'PRICE PULSE',
                  style: TerminalPalette.microCap(
                    context,
                    color:
                        theme.colorScheme.onSurface.withOpacity(0.35),
                    fontSize: 9,
                  ),
                ),
              ),
              Sparkline(
                values: sparkValues,
                color: stripeBase,
                width: 92,
                height: 24,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isMulti)
            _MultiOutcomeMini(market: market)
          else
            _BinaryMeters(market: market),
          const SizedBox(height: 12),
          _FooterRow(market: market),
        ],
      ),
    );
  }

  // Stable-ish fallback sparkline derived from the current price, so cards
  // without historical data still show a line instead of a bare field.
  List<double> _syntheticSpark(double current) {
    const int pts = 14;
    final base = current.clamp(0.02, 0.98);
    final List<double> out = [];
    for (int i = 0; i < pts; i++) {
      final drift = ((i * 37) % 11) / 110; // bounded deterministic drift
      final val = (base + drift - 0.055).clamp(0.01, 0.99);
      out.add(val);
    }
    out.add(current);
    return out;
  }
}

class _TopRow extends StatelessWidget {
  final MarketData market;
  const _TopRow({required this.market});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _CategoryTag(category: market.category),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'VOL \$${_compactMoney(market.volume)}',
            style: TerminalPalette.microCap(
              context,
              color: theme.colorScheme.onSurface.withOpacity(0.55),
            ),
          ),
        ),
        _StatusBadge(market: market),
      ],
    );
  }

  static String _compactMoney(double n) {
    if (n >= 1e6) return '${(n / 1e6).toStringAsFixed(1)}M';
    if (n >= 1e3) return '${(n / 1e3).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }
}

class _CategoryTag extends StatelessWidget {
  final String category;
  const _CategoryTag({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.35),
          width: 0.8,
        ),
      ),
      child: Text(
        category.toUpperCase(),
        style: TerminalPalette.microCap(
          context,
          color: AppTheme.primaryColor,
          fontSize: 9,
        ).copyWith(letterSpacing: 1.4),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final MarketData market;
  const _StatusBadge({required this.market});

  @override
  Widget build(BuildContext context) {
    if (market.isAvsVerified) {
      return _Badge(
        label: 'VERIFIED',
        color: TerminalPalette.ledViolet,
        icon: Icons.verified_outlined,
      );
    }
    final expired = market.expiryDate.isBefore(DateTime.now());
    if (expired) {
      return _Badge(
        label: 'CLOSED',
        color: TerminalPalette.ledAmber,
        icon: Icons.lock_clock_outlined,
      );
    }
    return const LiveBadge(label: 'LIVE', color: TerminalPalette.ledCyan);
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _Badge({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 11),
        const SizedBox(width: 4),
        Text(
          label,
          style: TerminalPalette.microCap(context, color: color, fontSize: 9.5),
        ),
      ],
    );
  }
}

class _BinaryMeters extends StatelessWidget {
  final MarketData market;
  const _BinaryMeters({required this.market});

  @override
  Widget build(BuildContext context) {
    final yesColor = TerminalPalette.ledGreen;
    final noColor = TerminalPalette.ledRed;
    final yesWinning = market.yesPrice >= market.noPrice;
    return Column(
      children: [
        OutcomeMeterRow(
          label: market.outcomes.isNotEmpty ? market.outcomes[0].label : 'Yes',
          value: market.yesPrice,
          color: yesColor,
          symbol: 'Y',
          highlighted: yesWinning,
        ),
        OutcomeMeterRow(
          label: market.outcomes.length > 1 ? market.outcomes[1].label : 'No',
          value: market.noPrice,
          color: noColor,
          symbol: 'N',
          highlighted: !yesWinning,
        ),
      ],
    );
  }
}

class _MultiOutcomeMini extends StatelessWidget {
  final MarketData market;
  const _MultiOutcomeMini({required this.market});

  @override
  Widget build(BuildContext context) {
    final limited = market.outcomes.take(3).toList();
    int topIdx = 0;
    double topPrice = -double.infinity;
    for (int i = 0; i < market.outcomes.length; i++) {
      if (market.outcomes[i].price > topPrice) {
        topPrice = market.outcomes[i].price;
        topIdx = i;
      }
    }
    return Column(
      children: [
        for (int i = 0; i < limited.length; i++)
          OutcomeMeterRow(
            label: limited[i].label,
            value: limited[i].price,
            color: TerminalPalette.outcomeColorAt(i),
            highlighted: i == topIdx,
          ),
        if (market.outcomes.length > 3) ...[
          const SizedBox(height: 4),
          Text(
            '+ ${market.outcomes.length - 3} more outcomes',
            style: TerminalPalette.microCap(
              context,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ],
    );
  }
}

class _FooterRow extends StatelessWidget {
  final MarketData market;
  const _FooterRow({required this.market});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final diff = market.expiryDate.difference(now);
    final (label, color) = _expiryLabel(diff);

    return Row(
      children: [
        Icon(
          Icons.schedule,
          size: 13,
          color: color.withOpacity(0.9),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: PulseNumber(
            value: label,
            style: TerminalPalette.mono(
              context,
              fontSize: 11.5,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: TerminalPalette.ledCyan.withOpacity(0.10),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: TerminalPalette.ledCyan.withOpacity(0.42),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TRADE',
                style: TerminalPalette.microCap(
                  context,
                  color: TerminalPalette.ledCyan,
                  fontSize: 9.5,
                ).copyWith(letterSpacing: 1.6),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 13,
                color: TerminalPalette.ledCyan,
              ),
            ],
          ),
        ),
      ],
    );
  }

  (String, Color) _expiryLabel(Duration d) {
    if (d.isNegative) {
      return ('RESOLVING…', TerminalPalette.ledAmber);
    }
    if (d.inMinutes < 60) {
      return ('CLOSES IN ${d.inMinutes}M', TerminalPalette.ledAmber);
    }
    if (d.inHours < 24) {
      return ('CLOSES IN ${d.inHours}H', TerminalPalette.ledAmber);
    }
    if (d.inDays < 7) {
      return ('${d.inDays}D ${(d.inHours % 24).toString().padLeft(2, '0')}H LEFT',
          AppTheme.textSecondary);
    }
    final expiry =
        '${market.expiryDate.year}-${_pad2(market.expiryDate.month)}-${_pad2(market.expiryDate.day)}';
    return ('RESOLVES · $expiry', AppTheme.textSecondary);
  }

  static String _pad2(int n) => n < 10 ? '0$n' : '$n';
}
