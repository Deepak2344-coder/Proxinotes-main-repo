import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:notes_app/core/models/subscription_model.dart';
import 'package:notes_app/features/subscription/data/subscription_repository.dart';
import 'package:notes_app/features/auth/presentation/providers/auth_provider.dart';

final subscriptionRepositoryProvider =
    Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(ref.read(supabaseClientProvider));
});

class SubscriptionState {
  final SubscriptionModel? subscription;
  final bool isLoading;
  final String? error;
  final String? razorpaySubscriptionId;

  const SubscriptionState({
    this.subscription,
    this.isLoading = false,
    this.error,
    this.razorpaySubscriptionId,
  });

  bool get isActive => subscription?.isActive ?? false;

  SubscriptionState copyWith({
    SubscriptionModel? subscription,
    bool? isLoading,
    String? error,
    String? razorpaySubscriptionId,
  }) {
    return SubscriptionState(
      subscription: subscription ?? this.subscription,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      razorpaySubscriptionId:
          razorpaySubscriptionId ?? this.razorpaySubscriptionId,
    );
  }
}

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  final SubscriptionRepository _repo;

  SubscriptionNotifier(this._repo) : super(const SubscriptionState()) {
    _load();
  }

  Future<void> _load() async {
    final sub = await _repo.getCurrentSubscription();
    state = SubscriptionState(subscription: sub);
  }

  Future<void> createSubscription(String planId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final subId = await _repo.createSubscription(planId);
      state = state.copyWith(
        isLoading: false,
        razorpaySubscriptionId: subId,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void setSubscriptionFromRazorpay(String razorpaySubId) {
    state = state.copyWith(razorpaySubscriptionId: razorpaySubId);
  }

  void refresh() {
    _load();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  return SubscriptionNotifier(ref.read(subscriptionRepositoryProvider));
});
