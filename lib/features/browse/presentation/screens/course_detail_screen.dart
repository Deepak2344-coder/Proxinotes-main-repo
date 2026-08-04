import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:notes_app/core/models/course_model.dart';
import 'package:notes_app/core/models/subject_model.dart';
import 'package:notes_app/core/theme/app_theme.dart';
import 'package:notes_app/core/widgets/error_display.dart';
import 'package:notes_app/core/widgets/loading_widget.dart';
import 'package:notes_app/core/widgets/empty_display.dart';
import 'package:notes_app/features/browse/presentation/providers/course_provider.dart';
import 'package:notes_app/features/subscription/presentation/providers/course_purchase_provider.dart';
import 'package:notes_app/features/browse/presentation/screens/subject_detail_screen.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  final CourseModel course;

  const CourseDetailScreen({super.key, required this.course});

  @override
  ConsumerState<CourseDetailScreen> createState() =>
      _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen> {
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    final purchaseNotifier = ref.read(
      coursePurchaseProvider(widget.course.id).notifier,
    );
    purchaseNotifier.onPaymentSuccess();

    // Poll for access (webhook may take a moment)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        ref.read(coursePurchaseProvider(widget.course.id).notifier)
            .checkAccess(widget.course.id);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Subscription activated! Access granted.'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ref.read(coursePurchaseProvider(widget.course.id).notifier)
        .onPaymentError(response.message ?? 'Payment failed');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response.message ?? 'Payment failed'),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {}

  void _showPaymentConfirmation() {
    final course = widget.course;
    final price = course.price;
    final priceStr = price > 0 ? '₹${price.toStringAsFixed(0)}' : 'Free';

    String durationText = 'monthly';
    if (course.subscriptionEndDate != null) {
      final end = course.subscriptionEndDate!;
      final now = DateTime.now();
      final months = (end.year - now.year) * 12 + (end.month - now.month);
      if (months > 0) {
        durationText = '$months month${months > 1 ? 's' : ''} (until ${_formatDate(end)})';
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Subscribe to Course',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              course.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.navy.withAlpha(10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.autorenew, color: AppTheme.navy, size: 20),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Monthly autopay',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Text(
                            '$priceStr/month',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.navy,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, color: AppTheme.textSecondary, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Duration: $durationText',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Auto-renewing monthly subscription. Access continues until the course end date. Cancel anytime.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _startSubscription();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.amber,
              foregroundColor: AppTheme.navy,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              price > 0 ? 'Subscribe $priceStr/mo' : 'Get Access',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _startSubscription() async {
    final purchaseNotifier = ref.read(
      coursePurchaseProvider(widget.course.id).notifier,
    );
    await purchaseNotifier.createSubscription(widget.course.id);

    if (!mounted) return;

    final purchaseState = ref.read(coursePurchaseProvider(widget.course.id));

    if (purchaseState.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(purchaseState.error!),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    if (purchaseState.hasAccess && purchaseState.razorpaySubscriptionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Free access granted!'),
          backgroundColor: AppTheme.success,
        ),
      );
      return;
    }

    if (purchaseState.razorpaySubscriptionId == null) return;

    final contact = purchaseState.contact ?? '';
    final email = purchaseState.email ?? Supabase.instance.client.auth.currentUser?.email ?? '';
    final amount = (widget.course.price * 100).toInt();

    try {
      _razorpay.open({
        'key': purchaseState.razorpayKeyId ?? const String.fromEnvironment('RAZORPAY_KEY', defaultValue: ''),
        'subscription_id': purchaseState.razorpaySubscriptionId,
        'amount': amount,
        'currency': 'INR',
        'name': 'Proxinotes',
        'description': 'Subscribe: ${widget.course.name}',
        'prefill': {
          'contact': contact,
          'email': email,
        },
        'theme': {
          'color': '#1F2A44',
        },
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final purchaseState = ref.watch(coursePurchaseProvider(widget.course.id));
    final hasAccess = purchaseState.hasAccess;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.name),
      ),
      body: Column(
        children: [
          if (!hasAccess) _PurchaseBanner(
            course: widget.course,
            onSubscribe: _showPaymentConfirmation,
            isProcessing: purchaseState.isProcessing,
          ),
          Expanded(
            child: hasAccess
                ? _SubjectList(course: widget.course)
                : _LockedView(course: widget.course),
          ),
        ],
      ),
    );
  }
}

class _PurchaseBanner extends StatelessWidget {
  final CourseModel course;
  final VoidCallback onSubscribe;
  final bool isProcessing;

  const _PurchaseBanner({
    required this.course,
    required this.onSubscribe,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    final priceStr = course.price > 0
        ? '₹${course.price.toStringAsFixed(0)}/mo'
        : 'Free';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.navy, AppTheme.navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Colors.white70, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Access this course',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  course.price > 0
                      ? 'Subscribe for $priceStr with autopay'
                      : 'Get free access to this course',
                  style: TextStyle(
                    color: Colors.white.withAlpha(180),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: isProcessing ? null : onSubscribe,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.amber,
              foregroundColor: AppTheme.navy,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.navy,
                    ),
                  )
                : Text(
                    course.price > 0 ? priceStr : 'Get Access',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SubjectList extends ConsumerWidget {
  final CourseModel course;

  const _SubjectList({required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<List<SubjectModel>> subjectsAsync;
    try {
      subjectsAsync = ref.watch(subjectsForCourseProvider(course.id));
    } catch (_) {
      return const ErrorDisplay(message: 'Failed to load subjects');
    }

    return subjectsAsync.when(
      data: (subjects) {
        if (subjects.isEmpty) {
          return const EmptyDisplay(
            message: 'No subjects in this course yet',
            icon: Icons.folder_outlined,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: subjects.length,
          itemBuilder: (_, i) => _SubjectCard(
            subject: subjects[i],
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SubjectDetailScreen(
                    subject: subjects[i],
                    courseName: course.name,
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const LoadingWidget(message: 'Loading subjects...'),
      error: (e, _) => ErrorDisplay(message: e.toString()),
    );
  }
}

class _LockedView extends ConsumerWidget {
  final CourseModel course;

  const _LockedView({required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<List<SubjectModel>> subjectsAsync;
    try {
      subjectsAsync = ref.watch(subjectsForCourseProvider(course.id));
    } catch (_) {
      return const ErrorDisplay(message: 'Failed to load subjects');
    }

    return subjectsAsync.when(
      data: (subjects) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (course.description.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  course.description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
            if (course.specs.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.navy.withAlpha(10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.navy.withAlpha(30)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What\'s included',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      course.specs,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            ...subjects.map((s) => Opacity(
              opacity: 0.5,
              child: Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.folder_outlined, color: AppTheme.textSecondary),
                  title: Text(
                    s.name,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: const Icon(Icons.lock_outline, size: 18, color: AppTheme.textSecondary),
                ),
              ),
            )),
          ],
        );
      },
      loading: () => const LoadingWidget(message: 'Loading...'),
      error: (e, _) => ErrorDisplay(message: e.toString()),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final SubjectModel subject;
  final VoidCallback onTap;

  const _SubjectCard({required this.subject, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.amber.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.folder_outlined, color: AppTheme.amber, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  subject.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
