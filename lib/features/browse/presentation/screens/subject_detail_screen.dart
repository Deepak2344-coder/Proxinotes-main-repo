import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:notes_app/core/models/content_model.dart';
import 'package:notes_app/core/models/subject_model.dart';
import 'package:notes_app/core/theme/app_theme.dart';
import 'package:notes_app/core/widgets/error_display.dart';
import 'package:notes_app/core/widgets/loading_widget.dart';
import 'package:notes_app/core/widgets/empty_display.dart';
import 'package:notes_app/features/viewer/presentation/screens/page_viewer_screen.dart';

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
    _tabController = TabController(length: 2, vsync: this);
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
            Tab(text: 'Units'),
            Tab(text: 'Tests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _UnitsList(subjectId: widget.subject.id),
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

class _UnitsList extends ConsumerWidget {
  final String subjectId;

  const _UnitsList({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(_unitsProvider(subjectId));

    return unitsAsync.when(
      data: (units) {
        if (units.isEmpty) {
          return const EmptyDisplay(
            message: 'No units yet',
            icon: Icons.folder_outlined,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: units.length,
          itemBuilder: (_, i) => _UnitCard(unit: units[i]),
        );
      },
      loading: () => const LoadingWidget(message: 'Loading units...'),
      error: (e, _) => ErrorDisplay(message: e.toString()),
    );
  }
}

final _unitsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, subjectId) async {
    final supabase = Supabase.instance.client;
    final res = await supabase
        .from('units')
        .select()
        .eq('subject_id', subjectId)
        .order('order_index', ascending: true);
    return (res as List).cast<Map<String, dynamic>>();
  },
);

class _UnitCard extends StatelessWidget {
  final Map<String, dynamic> unit;

  const _UnitCard({required this.unit});

  @override
  Widget build(BuildContext context) {
    final name = unit['name'] as String? ?? 'Untitled';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _UnitDetailScreen(
                unitId: unit['id'] as String,
                unitName: name,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.navy.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.folder_outlined, color: AppTheme.navy, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  name,
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

class _UnitDetailScreen extends StatelessWidget {
  final String unitId;
  final String unitName;

  const _UnitDetailScreen({required this.unitId, required this.unitName});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(unitName),
          bottom: const TabBar(
            indicatorColor: AppTheme.amber,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(text: 'Study Material'),
              Tab(text: 'Question Bank'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _FileList(
              unitId: unitId,
              fileType: 'study_material',
              emptyMessage: 'No study materials yet',
              emptyIcon: Icons.menu_book_outlined,
            ),
            _FileList(
              unitId: unitId,
              fileType: 'question_bank',
              emptyMessage: 'No question banks yet',
              emptyIcon: Icons.question_answer_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class _FileList extends ConsumerWidget {
  final String? subjectId;
  final String? unitId;
  final String fileType;
  final String emptyMessage;
  final IconData emptyIcon;

  const _FileList({
    this.subjectId,
    this.unitId,
    required this.fileType,
    required this.emptyMessage,
    required this.emptyIcon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = _FilesKey(
      subjectId: subjectId ?? '',
      unitId: unitId ?? '',
      fileType: fileType,
    );
    final filesAsync = ref.watch(_filesProvider(key));

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
  final String unitId;
  final String fileType;
  const _FilesKey({required this.subjectId, required this.unitId, required this.fileType});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _FilesKey &&
          runtimeType == other.runtimeType &&
          subjectId == other.subjectId &&
          unitId == other.unitId &&
          fileType == other.fileType;

  @override
  int get hashCode => subjectId.hashCode ^ unitId.hashCode ^ fileType.hashCode;
}

final _filesProvider = FutureProvider.family<List<Map<String, dynamic>>, _FilesKey>(
  (ref, key) async {
    final supabase = Supabase.instance.client;

    if (key.unitId.isNotEmpty) {
      final res = await supabase
          .from('files')
          .select()
          .eq('unit_id', key.unitId)
          .eq('file_type', key.fileType)
          .order('created_at', ascending: false);
      return (res as List).cast<Map<String, dynamic>>();
    }

    final unitsRes = await supabase
        .from('units')
        .select('id')
        .eq('subject_id', key.subjectId);
    final unitIds = (unitsRes as List).map((u) => u['id'] as String).toList();
    if (unitIds.isEmpty) return [];

    final res = await supabase
        .from('files')
        .select()
        .inFilter('unit_id', unitIds)
        .eq('file_type', key.fileType)
        .order('created_at', ascending: false);
    return (res as List).cast<Map<String, dynamic>>();
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

  void _openFile(BuildContext context) {
    final fileId = file['id'] as String?;
    final pages = (file['r2_pages'] as num?)?.toInt() ?? 0;
    final isPreview = file['is_preview'] as bool? ?? false;
    final createdAtStr = file['created_at'] as String?;

    if (fileId == null || pages == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not available')),
      );
      return;
    }

    final content = ContentModel(
      id: fileId,
      subject: '',
      chapter: 0,
      pageCount: pages,
      isPreview: isPreview,
      createdAt: createdAtStr != null ? DateTime.tryParse(createdAtStr) ?? DateTime.now() : DateTime.now(),
    );

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PageViewerScreen(content: content)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = file['name'] as String? ?? 'Untitled';
    final size = (file['r2_size'] as num?)?.toInt() ?? 0;
    final pages = (file['r2_pages'] as num?)?.toInt() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _openFile(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.navy.withAlpha(15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.picture_as_pdf, color: AppTheme.error, size: 20),
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
        trailing: const Icon(Icons.open_in_new, color: AppTheme.textSecondary, size: 18),
      ),
    );
  }
}
