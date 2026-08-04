import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const String _functionsBaseUrl = String.fromEnvironment(
    'FUNCTIONS_BASE_URL',
    defaultValue: '',
  );

  SupabaseClient get _supabase => Supabase.instance.client;

  Map<String, String> get _authHeaders {
    final session = _supabase.auth.currentSession;
    return {
      'Authorization': 'Bearer ${session?.accessToken ?? ''}',
      'Content-Type': 'application/json',
    };
  }

  Future<Uint8List> fetchPageImage({
    required String contentId,
    required int pageNo,
  }) async {
    final uri = Uri.parse(
      '$_functionsBaseUrl/gatekeeper?content_id=$contentId&page_no=$pageNo',
    );
    final res = await http.get(uri, headers: _authHeaders);

    if (res.statusCode == 402) {
      throw PaymentRequiredException();
    }
    if (res.statusCode != 200) {
      final body = res.body.isNotEmpty ? res.body : 'status ${res.statusCode}';
      throw Exception('Could not load page: $body');
    }
    return res.bodyBytes;
  }

  Future<String> createSubscription({required String planId}) async {
    final uri = Uri.parse('$_functionsBaseUrl/create-subscription');
    final res = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({'plan_id': planId}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to create subscription: ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['subscription_id'] as String;
  }

  Future<Map<String, dynamic>> createCourseSubscription({
    required String courseId,
  }) async {
    final uri = Uri.parse('$_functionsBaseUrl/create-course-subscription');
    final res = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({'course_id': courseId}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to create subscription: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

class PaymentRequiredException implements Exception {
  final String message;
  PaymentRequiredException([this.message = 'Payment required']);

  @override
  String toString() => message;
}
