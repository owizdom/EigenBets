import 'package:flutter/material.dart';
import '../models/market_data.dart';
import '../services/avs_service.dart';
import '../models/transaction_data.dart';

class BetPlacementForm extends StatefulWidget {
  final MarketData market;

  const BetPlacementForm({
    Key? key,
    required this.market,
  }) : super(key: key);

  @override
  State<BetPlacementForm> createState() => _BetPlacementFormState();
}

class _BetPlacementFormState extends State<BetPlacementForm> {
  String _selectedOutcome = 'Yes';
  double _betAmount = 100;
  final TextEditingController _amountController = TextEditingController(text: '100');
  final AvsService _avsService = AvsService();
  bool _isVerificationInProgress = false;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_updateBetAmount);
  }

  @override
  void dispose() {
    _amountController.removeListener(_updateBetAmount);
    _amountController.dispose();
    super.dispose();
  }

  void _updateBetAmount() {
    final text = _amountController.text;
    if (text.isNotEmpty) {
      setState(() {
        _betAmount = double.tryParse(text) ?? 0;
      });
    } else {
      setState(() {
        _betAmount = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Place Your Bet',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          widget.market.title,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onBackground.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Select Outcome',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        _buildOutcomeSelector(context),
        const SizedBox(height: 24),
        Text(
          'Bet Amount',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        _buildAmountInput(context),
        const SizedBox(height: 8),
        _buildQuickAmountButtons(context),
        const SizedBox(height: 24),
        _buildBetSummary(context),
        const SizedBox(height: 24),
        Column(
          children: [
            if (widget.market.expiryDate.isBefore(DateTime.now()) && !widget.market.isAvsVerified)
              // Show dedicated AVS verification button if market is expired but not verified
              SizedBox(
                width: double.infinity,
                child: _isVerificationInProgress 
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                    onPressed: _requestAvsVerification,
                    icon: const Icon(Icons.verified_user),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Colors.white,
                    ),
                    label: const Text('Send to AVS for Verification'),
                  ),
              )
            else
              // Regular bet placement button for active markets
              SizedBox(
                width: double.infinity,
                child: _isVerificationInProgress 
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                    onPressed: _betAmount > 0 ? _placeBet : null,
                    child: const Text('Place Bet'),
                  ),
              ),
          ],
        ),
      ],
    );
  }

  static const List<Color> _outcomeColors = [
    Color(0xFF6366F1), // Indigo (Yes)
    Color(0xFFEF4444), // Red (No)
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Pink
    Color(0xFF14B8A6), // Teal
    Color(0xFFF97316), // Orange
    Color(0xFF3B82F6), // Blue
    Color(0xFF84CC16), // Lime
  ];

  Widget _buildOutcomeSelector(BuildContext context) {
    final theme = Theme.of(context);
    final outcomes = widget.market.outcomes;

    // Binary markets: show two side-by-side buttons (original layout)
    if (widget.market.marketType == MarketType.binary || outcomes.length == 2) {
      return Row(
        children: List.generate(outcomes.length, (i) {
          final outcome = outcomes[i];
          final isSelected = _selectedOutcome == outcome.label;
          final color = _outcomeColors[i % _outcomeColors.length];
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i > 0 ? 16 : 0),
              child: InkWell(
                onTap: () => setState(() => _selectedOutcome = outcome.label),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withOpacity(0.1) : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? color : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        outcome.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isSelected ? color : theme.colorScheme.onBackground,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(outcome.price * 100).toStringAsFixed(1)}%',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isSelected ? color : theme.colorScheme.onBackground.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      );
    }

    // Multi-choice markets: show a vertical radio list
    return Column(
      children: List.generate(outcomes.length, (i) {
        final outcome = outcomes[i];
        final isSelected = _selectedOutcome == outcome.label;
        final color = _outcomeColors[i % _outcomeColors.length];
        final totalPrice = outcomes.fold<double>(0, (sum, o) => sum + o.price);
        final pct = totalPrice > 0 ? (outcome.price / totalPrice * 100).round() : 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => setState(() => _selectedOutcome = outcome.label),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.1) : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? color : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: isSelected ? color : theme.colorScheme.onBackground.withOpacity(0.3), width: 2),
                      color: isSelected ? color : Colors.transparent,
                    ),
                    child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      outcome.label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: isSelected ? color : theme.colorScheme.onBackground,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  Text(
                    '$pct%',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildAmountInput(BuildContext context) {
    final theme = Theme.of(context);
    
    return TextField(
      controller: _amountController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        prefixIcon: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'USDC',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: theme.colorScheme.surface,
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildQuickAmountButtons(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildQuickAmountButton(context, 10),
        _buildQuickAmountButton(context, 50),
        _buildQuickAmountButton(context, 100),
        _buildQuickAmountButton(context, 500),
      ],
    );
  }

  Widget _buildQuickAmountButton(BuildContext context, double amount) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: () {
        setState(() {
          _betAmount = amount;
          _amountController.text = amount.toString();
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '\$${amount.toInt()}',
          style: theme.textTheme.bodySmall,
        ),
      ),
    );
  }

  Widget _buildBetSummary(BuildContext context) {
    final theme = Theme.of(context);
    final outcomePrice = _selectedOutcome == 'Yes'
        ? widget.market.yesPrice
        : widget.market.noPrice;
    final potentialWinnings = _betAmount / outcomePrice;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bet Amount',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                '\$${_betAmount.toStringAsFixed(2)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Outcome Price',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                '${(outcomePrice * 100).toStringAsFixed(1)}%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Potential Winnings',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                '\$${potentialWinnings.toStringAsFixed(2)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _placeBet() async {
    if (widget.market.status != MarketStatus.open) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This market is not open for betting',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    // Check if market needs AVS verification (if past expiry date)
    if (widget.market.expiryDate.isBefore(DateTime.now()) && !widget.market.isAvsVerified) {
      _requestAvsVerification();
      return;
    }
    
    // Show loading state for blockchain interaction
    setState(() {
      _isVerificationInProgress = true;
    });
    
    // Simulate blockchain transaction time (2-4 seconds)
    final loadingDuration = 2000 + (DateTime.now().millisecond % 2000);
    await Future.delayed(Duration(milliseconds: loadingDuration));
    
    // Reset loading state
    if (mounted) {
      setState(() {
        _isVerificationInProgress = false;
      });
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bet placed successfully: $_betAmount USDC on $_selectedOutcome',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  Future<void> _requestAvsVerification() async {
    setState(() {
      _isVerificationInProgress = true;
    });
    
    // For demo purposes, we'll use the simulation function
    try {
      final result = await _avsService.simulateAvsVerification(widget.market);
      
      // FORCE outcome to be Yes for demo
      result['outcome'] = 'Yes';
      
      setState(() {
        _isVerificationInProgress = false;
      });
      
      // Show verification result
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Market verified by AVS. Outcome: Yes',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green[700],
        ),
      );
    } catch (e) {
      setState(() {
        _isVerificationInProgress = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AVS verification failed: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }
}
