import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:notes_app/core/models/subject_model.dart';
import 'package:notes_app/core/theme/app_theme.dart';
import 'package:notes_app/core/widgets/error_display.dart';
import 'package:notes_app/core/widgets/loading_widget.dart';
import 'package:notes_app/core/widgets/empty_display.dart';

class SubjectDetailScreen extends ConsumerStatefulWidget {
  final SubjectModel subject;
  final String courseName;

  const SubjectDetailScreen({
    super.key,
    required this.subject,
    required this.courseName,
  });

  @override
  ConsumerState<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends ConsumerState<SubjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subject.name),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.amber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Study Materials'),
            Tab(text: 'Question Banks'),
            Tab(text: 'Tests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FileList(
            subjectId: widget.subject.id,
            fileType: 'study_material',
            emptyMessage: 'No study materials yet',
            emptyIcon: Icons.menu_book_outlined,
          ),
          _FileList(
            subjectId: widget.subject.id,
            fileType: 'question_bank',
            emptyMessage: 'No question banks yet',
            emptyIcon: Icons.question_answer_outlined,
          ),
          _FileList(
            subjectId: widget.subject.id,
            fileType: 'test_pdf',
            emptyMessage: 'No tests yet',
            emptyIcon: Icons.quiz_outlined,
          ),
        ],
      ),
    );
  }
}

class _FileList extends ConsumerWidget {
  final String subjectId;
  final String fileType;
  final String emptyMessage;
  final IconData emptyIcon;

  const _FileList({
    required this.subjectId,
    required this.fileType,
    required this.emptyMessage,
    required this.emptyIcon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesAsync = ref.watch(_filesProvider(_FilesKey(subjectId, fileType)));

    return filesAsync.when(
      data: (files) {
        if (files.isEmpty) {
          return EmptyDisplay(message: emptyMessage, icon: emptyIcon);
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: files.length,
          itemBuilder: (_, i) => _FileCard(file: files[i]),
        );
      },
      loading: () => const LoadingWidget(message: 'Loading...'),
      error: (e, _) => ErrorDisplay(message: e.toString()),
    );
  }
}

class _FilesKey {
  final String subjectId;
  final String fileType;
  const _FilesKey(this.subjectId, this.fileType);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _FilesKey &&
          runtimeType == other.runtimeType &&
          subjectId == other.subjectId &&
          fileType == other.fileType;

  @override
  int get hashCode => subjectId.hashCode ^ fileType.hashCode;
}

final _filesProvider = FutureProvider.family<List<Map<String, dynamic>>, _FilesKey>(
  (ref, key) async {
    final supabase = Supabase.instance.client;

    // Get units for this subject
    final unitsRes = await supabase
        .from('units')
        .select('id')
        .eq('subject_id', key.subjectId);

    final unitIds = (unitsRes as List).map((u) => u['id'] as String).toList();

    if (unitIds.isEmpty) return [];

    // Get files for these units with the specified file type
    final filesRes = await supabase
        .from('files')
        .select()
        .inFilter('unit_id', unitIds)
        .eq('file_type', key.fileType)
        .order('created_at', ascending: false);

    return (filesRes as List).cast<Map<String, dynamic>>();
  },
);

class _FileCard extends StatelessWidget {
  final Map<String, dynamic> file;

  const _FileCard({required this.file});

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final name = file['name'] as String? ?? 'Untitled';
    final size = (file['r2_size'] as num?)?.toInt() ?? 0;
    final pages = (file['r2_pages'] as num?)?.toInt() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.navy.withAlpha(15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.description_outlined, color: AppTheme.navy, size: 20),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          '${_formatSize(size)}${pages > 0 ? ' · $pages pages' : ''}',
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
      ),
    );
  }
}
