import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/theme/app_theme.dart';
import 'core/models/notice_model.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/username_setup_screen.dart';
import 'features/browse/presentation/screens/browse_screen.dart';
import 'features/subscription/presentation/screens/subscription_screen.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'features/notices/presentation/providers/notice_provider.dart';
import 'features/notices/presentation/widgets/notice_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final supabaseUrl =
      const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  final supabaseKey =
      const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseKey,
    );
  }

  runApp(
    const ProviderScope(
      child: NotesApp(),
    ),
  );
}

class NotesApp extends StatelessWidget {
  const NotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppTheme.appName,
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: const _AppEntry(),
    );
  }
}

class _AppEntry extends ConsumerWidget {
  const _AppEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configured = const String.fromEnvironment('SUPABASE_URL').isNotEmpty;

    if (!configured) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Supabase credentials not configured.\n\n'
              'Build with --dart-define=SUPABASE_URL=... '
              '--dart-define=SUPABASE_ANON_KEY=... '
              '--dart-define=FUNCTIONS_BASE_URL=... '
              '--dart-define=RAZORPAY_KEY=...',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final authState = ref.watch(authProvider);

    if (authState.status != AuthStatus.authenticated) {
      return const LoginScreen();
    }

    if (authState.needsUsername) {
      return const UsernameSetupScreen();
    }

    return const AppShell();
  }
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _noticesScheduled = false;

  final List<Widget> _pages = const [
    BrowseScreen(),
    SubscriptionScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(noticeProvider.notifier).fetchNotices();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _noticesScheduled = false;
      ref.read(noticeProvider.notifier).fetchNotices();
    }
  }

  void _scheduleNoticeDisplay() {
    if (_noticesScheduled) return;
    final noticeState = ref.read(noticeProvider);
    if (noticeState.isLoading) return;

    _noticesScheduled = true;

    final allNotices = noticeState.activeNotices;
    if (allNotices.isEmpty) return;

    _showNextNotice(allNotices, noticeState.appVersion, 0);
  }

  void _showNextNotice(List<Notice> notices, String appVersion, int index) {
    if (index >= notices.length || !mounted) return;

    final notice = notices[index];

    NoticeDialog.show(
      context,
      notice: notice,
      appVersion: appVersion,
      onAction: () {
        if (notice.isUpdate && notice.linkUrl != null) {
          launchUrl(Uri.parse(notice.linkUrl!),
              mode: LaunchMode.externalApplication);
        }
      },
    ).then((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNextNotice(notices, appVersion, index + 1);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final noticeState = ref.watch(noticeProvider);

    if (!noticeState.isLoading && !_noticesScheduled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduleNoticeDisplay();
      });
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'Browse',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.subscriptions_outlined),
            activeIcon: Icon(Icons.subscriptions),
            label: 'Subscribe',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
