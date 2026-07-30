import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:notes_app/core/models/notice_model.dart';

class NoticeRepository {
  final SupabaseClient _supabase;

  NoticeRepository(this._supabase);

  Future<List<Notice>> fetchActiveNotices() async {
    final res = await _supabase
        .from('notices')
        .select()
        .order('priority', ascending: false)
        .order('created_at', ascending: false);

    return (res as List)
        .map((e) => Notice.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
