import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:notes_app/core/network/api_client.dart';
import 'package:notes_app/features/auth/presentation/providers/auth_provider.dart';

class CoursePurchaseState {
  final bool hasAccess;
  final bool isLoading;
  final String? error;
  final bool isProcessing;
  final String? razorpaySubscriptionId;
  final int? orderAmount;
  final String? razorpayKeyId;
  final String? contact;
  final String? email;

  const CoursePurchaseState({
    this.hasAccess = false,
    this.isLoading = false,
    this.error,
    this.isProcessing = false,
    this.razorpaySubscriptionId,
    this.orderAmount,
    this.razorpayKeyId,
    this.contact,
    this.email,
  });

  CoursePurchaseState copyWith({
    bool? hasAccess,
    bool? isLoading,
    String? error,
    bool? isProcessing,
    String? razorpaySubscriptionId,
    int? orderAmount,
    String? razorpayKeyId,
    String? contact,
    String? email,
  }) {
    return CoursePurchaseState(
      hasAccess: hasAccess ?? this.hasAccess,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isProcessing: isProcessing ?? this.isProcessing,
      razorpaySubscriptionId: razorpaySubscriptionId ?? this.razorpaySubscriptionId,
      orderAmount: orderAmount ?? this.orderAmount,
      razorpayKeyId: razorpayKeyId ?? this.razorpayKeyId,
      contact: contact ?? this.contact,
      email: email ?? this.email,
    );
  }
}

class CoursePurchaseNotifier extends StateNotifier<CoursePurchaseState> {
  final SupabaseClient _supabase;

  CoursePurchaseNotifier(this._supabase)
      : super(const CoursePurchaseState()) {
    _load();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    state = const CoursePurchaseState();
  }

  Future<void> checkAccess(String courseId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      state = state.copyWith(hasAccess: false);
      return;
    }

    try {
      final res = await _supabase
          .from('course_purchases')
          .select()
          .eq('user_id', user.id)
          .eq('course_id', courseId)
          .eq('status', 'completed')
          .gt('expires_at', DateTime.now().toIso8601String())
          .maybeSingle();

      state = state.copyWith(hasAccess: res != null);
    } catch (e) {
      state = state.copyWith(hasAccess: false);
    }
  }

  Future<void> createSubscription(String courseId) async {
    state = state.copyWith(isProcessing: true, error: null);
    try {
      final result = await ApiClient.instance.createCourseSubscription(
        courseId: courseId,
      );
      if (result['free'] == true) {
        state = state.copyWith(
          isProcessing: false,
          hasAccess: true,
        );
        return;
      }
      state = state.copyWith(
        isProcessing: false,
        razorpaySubscriptionId: result['subscription_id'] as String,
        orderAmount: result['amount'] as int?,
        razorpayKeyId: result['key_id'] as String?,
        contact: result['contact'] as String?,
        email: result['email'] as String?,
      );
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void onPaymentSuccess() {
    state = state.copyWith(isProcessing: false);
  }

  void onPaymentError(String message) {
    state = state.copyWith(
      isProcessing: false,
      error: message,
    );
  }

  void clearOrder() {
    state = state.copyWith(
      razorpaySubscriptionId: null,
      orderAmount: null,
      razorpayKeyId: null,
      contact: null,
      email: null,
      error: null,
    );
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final coursePurchaseProvider = StateNotifierProvider.autoDispose
    .family<CoursePurchaseNotifier, CoursePurchaseState, String>((ref, courseId) {
  final supabase = ref.read(supabaseClientProvider);
  final notifier = CoursePurchaseNotifier(supabase);
  notifier.checkAccess(courseId);
  return notifier;
});
