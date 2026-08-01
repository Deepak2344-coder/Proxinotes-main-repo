import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:notes_app/core/models/course_model.dart';
import 'package:notes_app/core/models/subject_model.dart';
import 'package:notes_app/core/models/unit_model.dart';

class CourseRepository {
  final SupabaseClient _supabase;
  static const _coursesCacheKey = 'courses_cache';
  static const _subjectsCacheKey = 'subjects_new_cache';
  static const _unitsCacheKey = 'units_cache';

  CourseRepository(this._supabase);

  Future<List<CourseModel>> getActiveCourses() async {
    try {
      final res = await _supabase
          .from('courses')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final items = (res as List)
          .map((e) => CourseModel.fromMap(e as Map<String, dynamic>))
          .toList();

      await _cacheCourses(items);
      return items;
    } catch (e) {
      final cached = await _getCachedCourses();
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<List<SubjectModel>> getSubjectsForCourse(String courseId) async {
    try {
      final res = await _supabase
          .from('subjects')
          .select()
          .eq('course_id', courseId)
          .order('order_index', ascending: true);

      final items = (res as List)
          .map((e) => SubjectModel.fromMap(e as Map<String, dynamic>))
          .toList();

      await _cacheSubjects(items);
      return items;
    } catch (e) {
      final cached = await _getCachedSubjects();
      if (cached.isNotEmpty) {
        return cached.where((s) => s.courseId == courseId).toList();
      }
      rethrow;
    }
  }

  Future<List<UnitModel>> getUnitsForSubject(String subjectId) async {
    try {
      final res = await _supabase
          .from('units')
          .select()
          .eq('subject_id', subjectId)
          .order('order_index', ascending: true);

      final items = (res as List)
          .map((e) => UnitModel.fromMap(e as Map<String, dynamic>))
          .toList();

      await _cacheUnits(items);
      return items;
    } catch (e) {
      final cached = await _getCachedUnits();
      if (cached.isNotEmpty) {
        return cached.where((u) => u.subjectId == subjectId).toList();
      }
      rethrow;
    }
  }

  Future<List<SubjectModel>> getAllSubjects() async {
    try {
      final res = await _supabase
          .from('subjects')
          .select()
          .order('order_index', ascending: true);

      final items = (res as List)
          .map((e) => SubjectModel.fromMap(e as Map<String, dynamic>))
          .toList();

      await _cacheSubjects(items);
      return items;
    } catch (e) {
      final cached = await _getCachedSubjects();
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  // --- Caching ---

  Future<void> _cacheCourses(List<CourseModel> items) async {
    final prefs = await SharedPreferences.getInstance();
    final json = items.map((e) => e.toMap()).toList();
    await prefs.setString(_coursesCacheKey, jsonEncode(json));
  }

  Future<List<CourseModel>> _getCachedCourses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_coursesCacheKey);
    if (raw == null) return [];
    try {
      final json = jsonDecode(raw) as List;
      return json
          .map((e) => CourseModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _cacheSubjects(List<SubjectModel> items) async {
    final prefs = await SharedPreferences.getInstance();
    final json = items.map((e) => e.toMap()).toList();
    await prefs.setString(_subjectsCacheKey, jsonEncode(json));
  }

  Future<List<SubjectModel>> _getCachedSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_subjectsCacheKey);
    if (raw == null) return [];
    try {
      final json = jsonDecode(raw) as List;
      return json
          .map((e) => SubjectModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _cacheUnits(List<UnitModel> items) async {
    final prefs = await SharedPreferences.getInstance();
    final json = items.map((e) => e.toMap()).toList();
    await prefs.setString(_unitsCacheKey, jsonEncode(json));
  }

  Future<List<UnitModel>> _getCachedUnits() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_unitsCacheKey);
    if (raw == null) return [];
    try {
      final json = jsonDecode(raw) as List;
      return json
          .map((e) => UnitModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
