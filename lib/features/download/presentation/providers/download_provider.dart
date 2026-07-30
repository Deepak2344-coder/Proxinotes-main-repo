import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:notes_app/core/models/content_model.dart';
import 'package:notes_app/core/network/api_client.dart';
import 'package:notes_app/features/download/data/download_manager.dart';

final downloadManagerProvider = Provider<DownloadManager>((ref) {
  return DownloadManager(ApiClient.instance);
});

class DownloadNotifier extends StateNotifier<Map<String, DownloadProgress>> {
  final DownloadManager _manager;
  Timer? _pollTimer;

  DownloadNotifier(this._manager) : super({}) {
    _startPolling();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _updateProgress();
    });
  }

  void _updateProgress() {
    final newMap = <String, DownloadProgress>{};
    for (final entry in state.entries) {
      newMap[entry.key] = _manager.getProgress(entry.key);
    }
    if (newMap.isNotEmpty) {
      state = newMap;
    }
  }

  Future<void> download(ContentModel content) async {
    state = {
      ...state,
      content.id: _manager.getProgress(content.id),
    };

    await _manager.downloadChapter(content);

    state = {
      ...state,
      content.id: _manager.getProgress(content.id),
    };
  }

  void cancel(String contentId) {
    _manager.cancelDownload(contentId);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

final downloadProvider =
    StateNotifierProvider<DownloadNotifier, Map<String, DownloadProgress>>(
        (ref) {
  return DownloadNotifier(ref.read(downloadManagerProvider));
});
