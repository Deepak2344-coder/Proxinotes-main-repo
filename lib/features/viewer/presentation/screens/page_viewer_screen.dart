import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:notes_app/core/models/content_model.dart';
import 'package:notes_app/core/theme/app_theme.dart';
import 'package:notes_app/features/viewer/presentation/providers/viewer_provider.dart';

class PageViewerScreen extends ConsumerStatefulWidget {
  final ContentModel content;

  const PageViewerScreen({super.key, required this.content});

  @override
  ConsumerState<PageViewerScreen> createState() => _PageViewerScreenState();
}

class _PageViewerScreenState extends ConsumerState<PageViewerScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  final Map<int, Uint8List> _loadedPages = {};
  final Map<int, bool> _loadingPages = {};
  final Map<int, String?> _pageErrors = {};
  final Map<int, TransformationController> _transformControllers = {};
  final Map<int, GlobalKey<_ZoomablePageState>> _zoomKeys = {};
  int _currentPage = 1;
  bool _isZoomed = false;

  static const int _preloadAheadCount = 3;
  static const int _initialBatchSize = 4;

  @override
  void initState() {
    super.initState();
    ScreenProtector.preventScreenshotOn();
    _preloadInitialBatch();
  }

  @override
  void dispose() {
    ScreenProtector.preventScreenshotOff();
    _pageController.dispose();
    for (final c in _transformControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  GlobalKey<_ZoomablePageState> _getZoomKey(int pageNo) {
    return _zoomKeys.putIfAbsent(pageNo, () => GlobalKey<_ZoomablePageState>());
  }

  TransformationController _getController(int pageNo) {
    return _transformControllers.putIfAbsent(
      pageNo,
      () => TransformationController()..addListener(_onTransformChanged),
    );
  }

  void _onTransformChanged() {
    final currentController = _transformControllers[_currentPage];
    if (currentController == null) return;

    final scale = currentController.value.getMaxScaleOnAxis();
    final isCurrentlyZoomed = scale > 1.05;

    if (isCurrentlyZoomed != _isZoomed) {
      setState(() => _isZoomed = isCurrentlyZoomed);
    }
  }

  void _preloadInitialBatch() {
    final count = widget.content.pageCount.clamp(1, _initialBatchSize);
    for (int i = 1; i <= count; i++) {
      _loadPage(i);
    }
  }

  void _preloadAhead(int fromPage) {
    final end =
        (fromPage + _preloadAheadCount).clamp(1, widget.content.pageCount);
    for (int i = fromPage; i <= end; i++) {
      if (!_loadedPages.containsKey(i) && _loadingPages[i] != true) {
        _loadPage(i);
      }
    }
  }

  Future<void> _loadPage(int pageNo) async {
    if (pageNo < 1 || pageNo > widget.content.pageCount) return;
    if (_loadedPages.containsKey(pageNo) || _loadingPages[pageNo] == true) {
      return;
    }

    setState(() => _loadingPages[pageNo] = true);

    try {
      final repo = ref.read(viewerRepositoryProvider);
      final cached = await repo.getCachedPage(
        contentId: widget.content.id,
        pageNo: pageNo,
      );

      Uint8List bytes;
      if (cached != null) {
        bytes = cached;
      } else {
        bytes = await repo.fetchPageImage(
          contentId: widget.content.id,
          pageNo: pageNo,
        );
        await repo.cachePageLocally(
          contentId: widget.content.id,
          pageNo: pageNo,
          bytes: bytes,
        );
      }

      if (mounted) {
        setState(() {
          _loadedPages[pageNo] = bytes;
          _loadingPages[pageNo] = false;
          _pageErrors[pageNo] = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingPages[pageNo] = false;
          _pageErrors[pageNo] = e.toString();
        });
      }
    }
  }

  void _resetZoom() {
    final key = _zoomKeys[_currentPage];
    key?.currentState?.animateResetZoom();
  }

  void _onDoubleTap(TapDownDetails details, int pageNo) {
    final key = _zoomKeys[pageNo];
    key?.currentState?.animateToggleZoom(details.localPosition);
  }

  @override
  Widget build(BuildContext context) {
    final bookmarkNotifier = ref.read(bookmarkIdsProvider.notifier);
    final bookmarks = ref.watch(bookmarkIdsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.content.subject} - Ch ${widget.content.chapter}'),
        actions: [
          if (_isZoomed)
            IconButton(
              icon: const Icon(Icons.zoom_out),
              onPressed: _resetZoom,
              tooltip: 'Reset zoom',
            ),
          IconButton(
            icon: Icon(
              bookmarks.contains(widget.content.id)
                  ? Icons.bookmark
                  : Icons.bookmark_border,
            ),
            onPressed: () {
              bookmarkNotifier.toggle(
                widget.content.id,
                widget.content.subject,
                widget.content.chapter,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            color: AppTheme.navy.withAlpha(20),
            child: Text(
              'Watermarked · ${_getUserIdentifier()}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: _isZoomed
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              itemCount: widget.content.pageCount,
              onPageChanged: (page) {
                _currentPage = page + 1;
                _preloadAhead(_currentPage);
                _resetZoom();
                setState(() {});
              },
              itemBuilder: (context, index) {
                final pageNo = index + 1;
                return AnimatedPageWrapper(
                  key: ValueKey('page_$pageNo'),
                  child: _buildPage(pageNo),
                );
              },
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final total = widget.content.pageCount;
    final loading = _loadingPages.values.where((v) => v == true).length;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: Text(
              'Page $_currentPage of $total',
              key: ValueKey(_currentPage),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          if (loading > 0) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.navy.withAlpha(150),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Loading $loading...',
              style: TextStyle(
                color: AppTheme.textSecondary.withAlpha(150),
                fontSize: 12,
              ),
            ),
          ],
          if (_isZoomed) ...[
            const SizedBox(width: 12),
            Icon(
              Icons.zoom_in,
              size: 14,
              color: AppTheme.navy.withAlpha(150),
            ),
            const SizedBox(width: 4),
            Text(
              'Double-tap to reset',
              style: TextStyle(
                color: AppTheme.textSecondary.withAlpha(150),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPage(int pageNo) {
    if (_loadedPages.containsKey(pageNo)) {
      return _ZoomablePage(
        key: _getZoomKey(pageNo),
        bytes: _loadedPages[pageNo]!,
        controller: _getController(pageNo),
        onDoubleTap: (details) => _onDoubleTap(details, pageNo),
      );
    }

    if (_pageErrors[pageNo] != null) {
      final is402 = _pageErrors[pageNo]!.contains('402') ||
          _pageErrors[pageNo]!.toLowerCase().contains('payment');
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              is402 ? Icons.lock_outline : Icons.error_outline,
              size: 48,
              color: is402 ? AppTheme.warning : AppTheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              is402 ? 'Subscribe to view all pages' : 'Failed to load page',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            if (!is402)
              ElevatedButton(
                onPressed: () => _loadPage(pageNo),
                child: const Text('Retry'),
              ),
          ],
        ),
      );
    }

    return _buildLoadingSkeleton(pageNo);
  }

  Widget _buildLoadingSkeleton(int pageNo) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 200,
            height: 260,
            decoration: BoxDecoration(
              color: AppTheme.navy.withAlpha(8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.navy.withAlpha(15)),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppTheme.navy.withAlpha(180),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Page $pageNo',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary.withAlpha(150),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getUserIdentifier() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return 'User';
    final email = user.email ?? '';
    final prefix = email.split('@').first;
    return prefix.length > 4
        ? '${prefix.substring(0, 2)}***${prefix.substring(prefix.length - 2)}'
        : prefix;
  }
}

class AnimatedPageWrapper extends StatefulWidget {
  final Widget child;

  const AnimatedPageWrapper({super.key, required this.child});

  @override
  State<AnimatedPageWrapper> createState() => _AnimatedPageWrapperState();
}

class _AnimatedPageWrapperState extends State<AnimatedPageWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _scaleAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0.08, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnim.value,
          child: Transform.translate(
            offset: _slideAnim.value,
            child: Transform.scale(
              scale: _scaleAnim.value,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _ZoomablePage extends StatefulWidget {
  final Uint8List bytes;
  final TransformationController controller;
  final void Function(TapDownDetails) onDoubleTap;

  const _ZoomablePage({
    super.key,
    required this.bytes,
    required this.controller,
    required this.onDoubleTap,
  });

  @override
  State<_ZoomablePage> createState() => _ZoomablePageState();
}

class _ZoomablePageState extends State<_ZoomablePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Animation<Matrix4>? _matrixAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
        if (_matrixAnimation != null) {
          widget.controller.value = _matrixAnimation!.value;
        }
      });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void animateToggleZoom(Offset tapPosition) {
    final currentScale = widget.controller.value.getMaxScaleOnAxis();

    if (currentScale > 1.1) {
      animateResetZoom();
    } else {
      animateZoomTo(tapPosition, 2.5);
    }
  }

  void animateZoomTo(Offset tapPosition, double targetScale) {
    _animController.stop();

    final currentTransform = widget.controller.value.clone();
    final targetDx = tapPosition.dx * (1 - targetScale);
    final targetDy = tapPosition.dy * (1 - targetScale);
    final targetTransform = Matrix4.identity()
      ..translateByDouble(targetDx, targetDy, 0.0, 1.0)
      ..scaleByDouble(targetScale, targetScale, 1.0, 1.0);

    _matrixAnimation = Matrix4Tween(
      begin: currentTransform,
      end: targetTransform,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animController.forward(from: 0.0);
  }

  void animateResetZoom() {
    _animController.stop();

    final currentTransform = widget.controller.value.clone();
    final targetTransform = Matrix4.identity();

    _matrixAnimation = Matrix4Tween(
      begin: currentTransform,
      end: targetTransform,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animController.forward(from: 0.0);
  }

  void _onDoubleTap(TapDownDetails details) {
    widget.onDoubleTap(details);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: _onDoubleTap,
      child: InteractiveViewer(
        transformationController: widget.controller,
        minScale: 1.0,
        maxScale: 5.0,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        panEnabled: true,
        scaleEnabled: true,
        child: Center(
          child: Image.memory(
            widget.bytes,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}
