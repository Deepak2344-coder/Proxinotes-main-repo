import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:notes_app/core/network/api_client.dart';
import 'package:notes_app/core/security/page_encryptor.dart';

class ViewerRepository {
  final ApiClient _apiClient;

  ViewerRepository(this._apiClient);

  static final Map<String, bool> _fileLocks = {};

  static Future<Directory> get _cacheRoot async {
    final dir = await getApplicationDocumentsDirectory();
    return Directory('${dir.path}/notes_encrypted');
  }

  static String _cachePath(String contentId, int pageNo) =>
      '$contentId/page_$pageNo.enc';

  Future<Uint8List> fetchPageImage({
    required String contentId,
    required int pageNo,
  }) async {
    return _apiClient.fetchPageImage(contentId: contentId, pageNo: pageNo);
  }

  Future<String> cachePageLocally({
    required String contentId,
    required int pageNo,
    required Uint8List bytes,
  }) async {
    final root = await _cacheRoot;
    final cacheDir = Directory('${root.path}/$contentId');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    final lockKey = '$contentId/page_$pageNo';
    while (_fileLocks[lockKey] == true) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    _fileLocks[lockKey] = true;

    try {
      final encrypted = await PageEncryptor.encrypt(bytes);
      final file = File('${cacheDir.path}/page_$pageNo.enc');
      final tmpFile = File('${file.path}.tmp');

      await tmpFile.writeAsBytes(encrypted);
      await tmpFile.rename(file.path);

      return file.path;
    } finally {
      _fileLocks.remove(lockKey);
    }
  }

  Future<Uint8List?> getCachedPage({
    required String contentId,
    required int pageNo,
  }) async {
    final root = await _cacheRoot;
    final file = File('${root.path}/${_cachePath(contentId, pageNo)}');
    if (await file.exists()) {
      try {
        final data = await file.readAsBytes();
        return await PageEncryptor.decrypt(data);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<void> clearCache(String contentId) async {
    final root = await _cacheRoot;
    final cacheDir = Directory('${root.path}/$contentId');
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
  }

  Future<void> clearAllCache() async {
    final root = await _cacheRoot;
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  }

  Future<void> bookmarkContent({
    required String contentId,
    required String subject,
    required int chapter,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = prefs.getStringList('bookmarks') ?? [];
    final entry = '$contentId||$subject||Chapter $chapter';
    if (!bookmarks.contains(entry)) {
      bookmarks.add(entry);
      await prefs.setStringList('bookmarks', bookmarks);
    }
  }

  Future<void> removeBookmark(String contentId) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = prefs.getStringList('bookmarks') ?? [];
    bookmarks.removeWhere((e) => e.startsWith(contentId));
    await prefs.setStringList('bookmarks', bookmarks);
  }

  Future<bool> isBookmarked(String contentId) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = prefs.getStringList('bookmarks') ?? [];
    return bookmarks.any((e) => e.startsWith(contentId));
  }

  Future<List<Map<String, String>>> getBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = prefs.getStringList('bookmarks') ?? [];
    return bookmarks.map((e) {
      final parts = e.split('||');
      return {
        'contentId': parts[0],
        'subject': parts.length > 1 ? parts[1] : '',
        'chapter': parts.length > 2 ? parts[2] : '',
      };
    }).toList();
  }
}
