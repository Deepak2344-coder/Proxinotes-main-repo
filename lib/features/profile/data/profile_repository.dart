import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepository {
  final SupabaseClient _supabase;

  ProfileRepository(this._supabase);

  Future<Map<String, dynamic>?> getProfile(String userId) async {
    return _supabase
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
  }

  Future<void> updateProfile({
    required String userId,
    String? name,
    String? rollNo,
    String? phone,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (rollNo != null) data['roll_no'] = rollNo;
    if (phone != null) data['phone'] = phone;

    if (data.isNotEmpty) {
      await _supabase.from('users').update(data).eq('id', userId);
    }
  }

  Future<List<Map<String, dynamic>>> getDevices(String userId) async {
    final res = await _supabase
        .from('devices')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (res as List).cast<Map<String, dynamic>>();
  }
}
