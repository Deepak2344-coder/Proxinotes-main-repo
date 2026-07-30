import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:notes_app/core/theme/app_theme.dart';
import 'package:notes_app/features/subscription/presentation/providers/subscription_provider.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  final VoidCallback? onSubscribed;

  const SubscriptionScreen({super.key, this.onSubscribed});

  @override
  ConsumerState<SubscriptionScreen> createState() =>
      _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  late Razorpay _razorpay;
  String? _selectedPlan;
  bool _plansLoading = true;
  List<Map<String, dynamic>> _plans = [];

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    try {
      final data = await Supabase.instance.client
          .from('pricing_plans')
          .select()
          .order('amount', ascending: true);
      _plans = List<Map<String, dynamic>>.from(data as List);
      if (_plans.isNotEmpty && mounted) {
        setState(() => _selectedPlan = _plans[0]['id'] as String);
      }
    } catch (_) {
      _plans = [];
    } finally {
      if (mounted) setState(() => _plansLoading = false);
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    ref.read(subscriptionProvider.notifier).refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Subscription activated!'),
        backgroundColor: AppTheme.success,
      ),
    );
    widget.onSubscribed?.call();
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ref.read(subscriptionProvider.notifier).refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response.message ?? 'Payment failed'),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {}

  Future<void> _startSubscription() async {
    if (_selectedPlan == null) return;

    final subNotifier = ref.read(subscriptionProvider.notifier);
    await subNotifier.createSubscription(_selectedPlan!);

    if (!mounted) return;

    final subState = ref.read(subscriptionProvider);
    if (subState.razorpaySubscriptionId == null) {
      if (subState.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(subState.error!),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return;
    }

    try {
      _razorpay.open({
        'key': const String.fromEnvironment('RAZORPAY_KEY', defaultValue: ''),
        'subscription_id': subState.razorpaySubscriptionId,
        'name': 'NotesApp',
        'description': 'Notes Subscription',
        'prefill': {
          'contact': '',
          'email': Supabase.instance.client.auth.currentUser?.email ?? '',
        },
        'theme': {
          'color': '#1F2A44',
        },
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting payment: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final subState = ref.watch(subscriptionProvider);

    if (subState.isActive) {
      return Scaffold(
        appBar: AppBar(title: const Text('Subscription')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 80, color: AppTheme.success),
                const SizedBox(height: 24),
                const Text(
                  'Subscription Active',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You have full access to all notes',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Start Reading'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Choose Your Plan')),
      body: _plansLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          const Text(
            'Unlock unlimited access to all study notes',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ..._plans.map((plan) => _buildPlanCard(plan)),
          if (subState.error != null) ...[
            const SizedBox(height: 16),
            Text(
              subState.error!,
              style: const TextStyle(color: AppTheme.error, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed:
                (_selectedPlan != null && !subState.isLoading) ? _startSubscription : null,
            child: subState.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.navy,
                    ),
                  )
                : Text('Subscribe - ${_getSelectedPrice()}'),
          ),
          const SizedBox(height: 16),
          Text(
            'Cancel anytime. Auto-renews monthly.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary.withAlpha(150),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(int paise) {
    final rupees = paise ~/ 100;
    return '₹$rupees';
  }

  String _getSelectedPrice() {
    if (_selectedPlan == null) return '';
    final plan = _plans.firstWhere((p) => p['id'] == _selectedPlan);
    final amount = plan['amount'] as int;
    final interval = plan['interval'] as String? ?? 'month';
    return '${_formatPrice(amount)}/$interval';
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final isSelected = _selectedPlan == plan['id'];
    final name = plan['name'] as String;
    final amount = plan['amount'] as int;
    final desc = plan['description'] as String? ?? '';
    final interval = plan['interval'] as String? ?? 'month';
    final isMiddle = _plans.indexOf(plan) == 1 && _plans.length == 3;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => setState(() => _selectedPlan = plan['id'] as String),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.navy.withAlpha(15)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppTheme.navy : const Color(0xFFE5E7EB),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              if (isMiddle) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.amber,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Popular',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.navy,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (desc.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              desc,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          _formatPrice(amount),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.navy,
                          ),
                        ),
                        Text(
                          '/$interval',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppTheme.navy,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
