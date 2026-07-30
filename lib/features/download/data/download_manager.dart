import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:notes_app/core/models/content_model.dart';
import 'package:notes_app/core/network/api_client.dart';
import 'package:notes_app/core/security/page_encryptor.dart';

class DownloadProgress {
  final int total;
  final int completed;
  final int failed;
  final bool isComplete;

  const DownloadProgress({
    this.total = 0,
    this.completed = 0,
    this.failed = 0,
    this.isComplete = false,
  });

  double get percentage => total > 0 ? completed / total : 0;

  DownloadProgress copyWith({
    int? total,
    int? completed,
    int? failed,
    bool? isComplete,
  }) {
    return DownloadProgress(
      total: total ?? this.total,
      completed: completed ?? this.completed,
      failed: failed ?? this.failed,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

class DownloadManager {
  final ApiClient _apiClient;
  final Map<String, DownloadProgress> _progress = {};
  final Map<String, bool> _cancelling = {};
  static final Map<String, bool> _fileLocks = {};

  DownloadManager(this._apiClient);

  static Future<Directory> get _cacheRoot async {
    final dir = await getApplicationDocumentsDirectory();
    return Directory('${dir.path}/notes_encrypted');
  }

  DownloadProgress getProgress(String contentId) =>
      _progress[contentId] ?? const DownloadProgress();

  Future<bool> isChapterCached(String contentId, int pageCount) async {
    final root = await _cacheRoot;
    final cacheDir = Directory('${root.path}/$contentId');
    if (!await cacheDir.exists()) return false;

    int existingCount = 0;
    for (int i = 1; i <= pageCount; i++) {
      final file = File('${cacheDir.path}/page_$i.enc');
      if (await file.exists()) existingCount++;
    }
    return existingCount >= pageCount;
  }

  Future<int> getCachedPageCount(String contentId, int pageCount) async {
    final root = await _cacheRoot;
    final cacheDir = Directory('${root.path}/$contentId');
    if (!await cacheDir.exists()) return 0;

    int count = 0;
    for (int i = 1; i <= pageCount; i++) {
      final file = File('${cacheDir.path}/page_$i.enc');
      if (await file.exists()) count++;
    }
    return count;
  }

  Future<void> downloadChapter(ContentModel content) async {
    if (_progress.containsKey(content.id) &&
        !_progress[content.id]!.isComplete) {
      return;
    }

    _cancelling[content.id] = false;
    _progress[content.id] = DownloadProgress(
      total: content.pageCount,
      completed: 0,
      failed: 0,
    );

    final root = await _cacheRoot;
    final cacheDir = Directory('${root.path}/${content.id}');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    const batchSize = 3;
    for (int batchStart = 0;
        batchStart < content.pageCount;
        batchStart += batchSize) {
      if (_cancelling[content.id] == true) break;

      final batchEnd = (batchStart + batchSize).clamp(0, content.pageCount);
      final futures = <Future>[];

      for (int i = batchStart; i < batchEnd; i++) {
        final pageNo = i + 1;
        futures.add(_downloadPage(content.id, pageNo, cacheDir));
      }

      await Future.wait(futures);
    }

    _progress[content.id] = _progress[content.id]!.copyWith(
      isComplete: true,
    );
    _cancelling.remove(content.id);
  }

  Future<void> _downloadPage(
    String contentId,
    int pageNo,
    Directory cacheDir,
  ) async {
    if (_cancelling[contentId] == true) return;

    final lockKey = '$contentId/page_$pageNo';

    while (_fileLocks[lockKey] == true) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    _fileLocks[lockKey] = true;

    try {
      final file = File('${cacheDir.path}/page_$pageNo.enc');
      if (await file.exists()) {
        _progress[contentId] = _progress[contentId]!.copyWith(
          completed: _progress[contentId]!.completed + 1,
        );
        return;
      }

      final bytes = await _apiClient.fetchPageImage(
        contentId: contentId,
        pageNo: pageNo,
      );

      final encrypted = await PageEncryptor.encrypt(bytes);
      final tmpFile = File('${file.path}.tmp');
      await tmpFile.writeAsBytes(encrypted);
      await tmpFile.rename(file.path);

      _progress[contentId] = _progress[contentId]!.copyWith(
        completed: _progress[contentId]!.completed + 1,
      );
    } catch (e) {
      _progress[contentId] = _progress[contentId]!.copyWith(
        failed: _progress[contentId]!.failed + 1,
      );
    } finally {
      _fileLocks.remove(lockKey);
    }
  }

  void cancelDownload(String contentId) {
    _cancelling[contentId] = true;
  }

  Future<void> deleteChapter(String contentId) async {
    final root = await _cacheRoot;
    final cacheDir = Directory('${root.path}/$contentId');
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
    _progress.remove(contentId);
  }

  Future<int> getTotalCacheSize() async {
    final root = await _cacheRoot;
    final cacheDir = Directory(root.path);
    if (!await cacheDir.exists()) return 0;

    int totalSize = 0;
    await for (final entity in cacheDir.list(recursive: true)) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }
    return totalSize;
  }

  Future<int> getTotalCachedChapters() async {
    final root = await _cacheRoot;
    if (!await root.exists()) return 0;

    int count = 0;
    await for (final entity in root.list()) {
      if (entity is Directory) count++;
    }
    return count;
  }

  Future<void> clearAllDownloads() async {
    final root = await _cacheRoot;
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
    _progress.clear();
    _cancelling.clear();
  }

  Future<List<CachedChapterInfo>> getCachedChapterDetails() async {
    final root = await _cacheRoot;
    if (!await root.exists()) return [];

    final chapters = <CachedChapterInfo>[];
    await for (final entity in root.list()) {
      if (entity is Directory) {
        final dirName = entity.path.split(Platform.pathSeparator).last;
        int pageCount = 0;
        int totalSize = 0;
        await for (final file in entity.list()) {
          if (file is File && file.path.endsWith('.enc')) {
            pageCount++;
            totalSize += await file.length();
          }
        }
        if (pageCount > 0) {
          chapters.add(CachedChapterInfo(
            contentId: dirName,
            pageCount: pageCount,
            totalSize: totalSize,
            lastModified: entity.statSync().modified,
          ));
        }
      }
    }

    chapters.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    return chapters;
  }
}

class CachedChapterInfo {
  final String contentId;
  final int pageCount;
  final int totalSize;
  final DateTime lastModified;

  const CachedChapterInfo({
    required this.contentId,
    required this.pageCount,
    required this.totalSize,
    required this.lastModified,
  });

  String get formattedSize {
    if (totalSize < 1024) return '$totalSize B';
    if (totalSize < 1024 * 1024) {
      return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
