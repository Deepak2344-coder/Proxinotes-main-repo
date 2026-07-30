import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:notes_app/core/models/content_model.dart';

class ContentRepository {
  final SupabaseClient _supabase;
  static const _cacheKey = 'content_metadata_cache';
  static const _subjectsCacheKey = 'subjects_cache';

  ContentRepository(this._supabase);

  Future<List<ContentModel>> getAllContent() async {
    try {
      final res = await _supabase
          .from('content_metadata')
          .select()
          .order('subject', ascending: true)
          .order('chapter', ascending: true);

      final items = (res as List)
          .map((e) => ContentModel.fromMap(e as Map<String, dynamic>))
          .toList();

      // Cache for offline use
      await _cacheContent(items);
      return items;
    } catch (e) {
      // Network failed, try cache
      final cached = await _getCachedContent();
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<List<String>> getSubjects() async {
    try {
      final res = await _supabase
          .from('content_metadata')
          .select('subject')
          .order('subject', ascending: true);

      final subjects = (res as List)
          .map((e) => e['subject'] as String)
          .toSet()
          .toList();

      // Cache for offline use
      await _cacheSubjects(subjects);
      return subjects;
    } catch (e) {
      final cached = await _getCachedSubjects();
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<List<ContentModel>> getContentBySubject(String subject) async {
    try {
      final res = await _supabase
          .from('content_metadata')
          .select()
          .eq('subject', subject)
          .order('chapter', ascending: true);

      return (res as List)
          .map((e) => ContentModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Fall back to full cache filtered by subject
      final allCached = await _getCachedContent();
      if (allCached.isNotEmpty) {
        return allCached.where((c) => c.subject == subject).toList();
      }
      rethrow;
    }
  }

  Future<List<ContentModel>> searchContent(String query) async {
    try {
      final res = await _supabase
          .from('content_metadata')
          .select()
          .or(
            'subject.ilike.%$query%,chapter.cast.text.ilike.%$query%',
          )
          .order('subject', ascending: true)
          .order('chapter', ascending: true);

      return (res as List)
          .map((e) => ContentModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Fall back to local search on cache
      final allCached = await _getCachedContent();
      if (allCached.isNotEmpty) {
        final q = query.toLowerCase();
        return allCached.where((c) =>
          c.subject.toLowerCase().contains(q) ||
          c.chapter.toString().contains(q)
        ).toList();
      }
      rethrow;
    }
  }

  Future<void> _cacheContent(List<ContentModel> items) async {
    final prefs = await SharedPreferences.getInstance();
    final json = items.map((e) => e.toMap()).toList();
    await prefs.setString(_cacheKey, jsonEncode(json));
  }

  Future<List<ContentModel>> _getCachedContent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return [];
    try {
      final json = jsonDecode(raw) as List;
      return json
          .map((e) => ContentModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _cacheSubjects(List<String> subjects) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_subjectsCacheKey, subjects);
  }

  Future<List<String>> _getCachedSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_subjectsCacheKey) ?? [];
  }
}
