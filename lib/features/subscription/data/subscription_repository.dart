import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:notes_app/core/models/subscription_model.dart';
import 'package:notes_app/core/network/api_client.dart';

class SubscriptionRepository {
  final SupabaseClient _supabase;

  SubscriptionRepository(this._supabase);

  Future<SubscriptionModel?> getCurrentSubscription() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final res = await _supabase
        .from('subscriptions')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (res == null) return null;
    return SubscriptionModel.fromMap(res);
  }

  Future<String> createSubscription(String planId) async {
    return ApiClient.instance.createSubscription(planId: planId);
  }

  Stream<SubscriptionModel?> watchSubscription() {
    final user = _supabase.auth.currentUser;
    if (user == null) return Stream.value(null);

    return _supabase
        .from('subscriptions')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1)
        .map((events) {
          if (events.isEmpty) return null;
          return SubscriptionModel.fromMap(events.first);
        });
  }
}
