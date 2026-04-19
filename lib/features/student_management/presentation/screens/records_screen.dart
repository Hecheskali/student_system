import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/education_entities.dart';
import '../../domain/entities/school_records_entities.dart';
import '../../domain/services/necta_olevel_subjects.dart';
import '../providers/school_records_providers.dart';
import '../providers/student_management_providers.dart';
import '../utils/historical_import_parser.dart';
import '../utils/report_exporter.dart';
import '../widgets/motion_widgets.dart';
import '../widgets/workspace_shell.dart';

class RecordsScreen extends ConsumerWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SchoolAdminState adminState = ref.watch(schoolAdminProvider);
    final SchoolOverview overview = ref.watch(schoolOverviewProvider);
    final SchoolRecordsState records = ref.watch(schoolRecordsProvider);
    final HistoricalRecordsOverview archive = ref.watch(
      historicalRecordsOverviewProvider,
    );
    final SessionUser? session = adminState.session;

    if (session == null) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Login to open records archive'),
          ),
        ),
      );
    }

    return WorkspaceShell(
      currentSection: WorkspaceSection.records,
      session: session,
      eyebrow: 'Archive And Registry',
      title: 'Historical Records Center',
      subtitle:
          'Manage exam sessions, import archived school results, maintain student master records, and prepare the system for backend data storage.',
      actions: <Widget>[
        FilledButton.tonalIcon(
          onPressed: () => context.go('/profiles'),
          icon: const Icon(Icons.perm_media_rounded),
          label: const Text('School Profiles'),
        ),
        FilledButton.icon(
          onPressed: () => context.go('/analytics'),
          icon: const Icon(Icons.analytics_rounded),
          label: const Text('Recommendation Boards'),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: <Widget>[
          RevealMotion(
            child: _RecordsHero(overview: overview, archive: archive),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: <Widget>[
              _SignalCard(
                label: 'Exam Sessions',
                value: '${archive.totalSessions}',
                detail: 'Tracked archive windows',
                tone: const Color(0xFF155EEF),
              ),
              _SignalCard(
                label: 'Historical Rows',
                value: '${archive.totalHistoricalRecords}',
                detail: 'Imported records ready for comparison',
                tone: const Color(0xFF0F766E),
              ),
              _SignalCard(
                label: 'Tracked Years',
                value: '${archive.trackedAcademicYears}',
                detail: 'Academic years linked into the archive',
                tone: const Color(0xFF7C3AED),
              ),
              _SignalCard(
                label: 'Registry',
                value: '${records.studentMasterRecords.length}',
                detail: 'Student master records maintained',
                tone: const Color(0xFFEA580C),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool stacked = constraints.maxWidth < 1220;
              final Widget left = Column(
                children: <Widget>[
                  _RecordsBoard(
                    tone: const Color(0xFF155EEF),
                    title: 'Historical Import Workspace',
                    subtitle:
                        'Upload old school results from CSV or Excel, preview the parsed learners, then post them into the selected exam session.',
                    child: _HistoricalImportBoard(
                      sessions: records.examSessions,
                      existingRecords: records.historicalRecords,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _RecordsBoard(
                    tone: const Color(0xFFEA580C),
                    title: 'Import Ledger',
                    subtitle:
                        'Every archive file is registered here so future backend audit, validation, and rollback can connect to a real batch record.',
                    child: _ImportBatchBoard(batches: records.importBatches),
                  ),
                ],
              );
              final Widget right = Column(
                children: <Widget>[
                  _RecordsBoard(
                    tone: const Color(0xFF0F766E),
                    title: 'Exam Session Model',
                    subtitle:
                        'Create and maintain named sessions for mock exams, national exams, and internal windows before importing records.',
                    child: _SessionBoard(
                      sessions: records.examSessions,
                      classes: overview.studentResults
                          .map((StudentResultRecord item) => item.className)
                          .toSet()
                          .toList(),
                      records: records.historicalRecords,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _RecordsBoard(
                    tone: const Color(0xFF7C3AED),
                    title: 'Student Master Registry',
                    subtitle:
                        'Keep long-life student records separate from exam rows so biodata, guardians, class history, and archive links stay durable.',
                    child: _StudentRegistryBoard(
                      records: records.studentMasterRecords,
                      currentResults: overview.studentResults,
                    ),
                  ),
                ],
              );

              if (stacked) {
                return Column(
                  children: <Widget>[left, const SizedBox(height: 18), right],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(flex: 5, child: left),
                  const SizedBox(width: 18),
                  Expanded(flex: 5, child: right),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HistoricalImportBoard extends ConsumerStatefulWidget {
  const _HistoricalImportBoard({
    required this.sessions,
    required this.existingRecords,
  });

  final List<ExamSession> sessions;
  final List<HistoricalExamRecord> existingRecords;

  @override
  ConsumerState<_HistoricalImportBoard> createState() =>
      _HistoricalImportBoardState();
}

class _HistoricalImportBoardState
    extends ConsumerState<_HistoricalImportBoard> {
  HistoricalImportPreview? _preview;
  String? _selectedSessionId;
  bool _busy = false;
  final TextEditingController _noteController = TextEditingController(
    text: 'Archive upload staged from historical school file.',
  );

  @override
  void initState() {
    super.initState();
    if (widget.sessions.isNotEmpty) {
      _selectedSessionId = widget.sessions.first.id;
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ExamSession? selectedSession = widget.sessions.where((
      ExamSession item,
    ) {
      return item.id == _selectedSessionId;
    }).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DropdownButtonFormField<String>(
          initialValue: _selectedSessionId,
          decoration: const InputDecoration(labelText: 'Target exam session'),
          items: widget.sessions.map((ExamSession session) {
            return DropdownMenuItem<String>(
              value: session.id,
              child: Text('${session.name} • ${session.academicYear}'),
            );
          }).toList(),
          onChanged: (String? value) {
            setState(() {
              _selectedSessionId = value;
            });
          },
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _noteController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Batch note',
            hintText: 'Describe where this file came from',
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            FilledButton.icon(
              onPressed: selectedSession == null || _busy
                  ? null
                  : () => _pickFile(selectedSession),
              icon: const Icon(Icons.upload_file_rounded),
              label: Text(_busy ? 'Reading file...' : 'Upload Archive File'),
            ),
            if (_preview != null)
              FilledButton.tonalIcon(
                onPressed: selectedSession == null
                    ? null
                    : () => _commit(selectedSession),
                icon: const Icon(Icons.playlist_add_check_circle_rounded),
                label: const Text('Commit Import'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _preview == null ? 'No file staged yet' : _preview!.fileName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                _preview == null
                    ? 'Accepted formats: CSV and Excel. Expected columns: Admission, Student, Class, and the O-Level subjects you want to import.'
                    : '${_preview!.results.length} learners parsed • ${_preview!.warningCount} warnings',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
        if (_preview != null) ...<Widget>[
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              columns: const <DataColumn>[
                DataColumn(label: Text('Student')),
                DataColumn(label: Text('Admission')),
                DataColumn(label: Text('Class')),
                DataColumn(label: Text('Average')),
                DataColumn(label: Text('Division')),
              ],
              rows: _preview!.results.take(5).map((StudentResultRecord result) {
                return DataRow(
                  cells: <DataCell>[
                    DataCell(Text(result.studentName)),
                    DataCell(Text(result.admissionNumber)),
                    DataCell(Text(result.className)),
                    DataCell(
                      Text('${result.averageScore.toStringAsFixed(1)}%'),
                    ),
                    DataCell(Text(result.division)),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickFile(ExamSession session) async {
    setState(() {
      _busy = true;
    });
    final HistoricalImportPreview? preview =
        await HistoricalImportParser.pickAndParse(session: session);
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _preview = preview;
    });
  }

  void _commit(ExamSession session) {
    final HistoricalImportPreview? preview = _preview;
    if (preview == null || preview.results.isEmpty) {
      return;
    }
    ref
        .read(schoolRecordsProvider.notifier)
        .importHistoricalRecords(
          session: session,
          fileName: preview.fileName,
          note: _noteController.text.trim(),
          warningCount: preview.warningCount,
          results: preview.results,
        );
    setState(() {
      _preview = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${preview.results.length} historical records imported.'),
      ),
    );
  }
}

class _SessionBoard extends ConsumerStatefulWidget {
  const _SessionBoard({
    required this.sessions,
    required this.classes,
    required this.records,
  });

  final List<ExamSession> sessions;
  final List<String> classes;
  final List<HistoricalExamRecord> records;

  @override
  ConsumerState<_SessionBoard> createState() => _SessionBoardState();
}

class _SessionBoardState extends ConsumerState<_SessionBoard> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _yearController = TextEditingController(
    text: '2026',
  );
  final TextEditingController _termController = TextEditingController(
    text: 'Term 3',
  );
  final TextEditingController _scopeController = TextEditingController(
    text: 'Whole school archive set',
  );
  final TextEditingController _notesController = TextEditingController();
  ExamSessionType _type = ExamSessionType.mock;
  final Set<String> _selectedClasses = <String>{};

  @override
  void dispose() {
    _nameController.dispose();
    _yearController.dispose();
    _termController.dispose();
    _scopeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Session name',
            hintText: 'Form 4 Mock 2026',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _yearController,
                decoration: const InputDecoration(labelText: 'Academic year'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _termController,
                decoration: const InputDecoration(labelText: 'Term label'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ExamSessionType>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Session type'),
          items: ExamSessionType.values.map((ExamSessionType type) {
            return DropdownMenuItem<ExamSessionType>(
              value: type,
              child: Text(type.label),
            );
          }).toList(),
          onChanged: (ExamSessionType? value) {
            if (value == null) {
              return;
            }
            setState(() {
              _type = value;
            });
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _scopeController,
          decoration: const InputDecoration(labelText: 'Scope label'),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.classes.map((String className) {
            final bool active = _selectedClasses.contains(className);
            return FilterChip(
              label: Text(className),
              selected: active,
              onSelected: (bool selected) {
                setState(() {
                  if (selected) {
                    _selectedClasses.add(className);
                  } else {
                    _selectedClasses.remove(className);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Session notes'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _createSession,
          icon: const Icon(Icons.add_chart_rounded),
          label: const Text('Create Exam Session'),
        ),
        const SizedBox(height: 18),
        ...widget.sessions.map((ExamSession session) {
          final int count = widget.records
              .where(
                (HistoricalExamRecord record) =>
                    record.examSessionId == session.id,
              )
              .length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          session.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _exportSession(context, session),
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Export'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${session.type.label} • ${session.academicYear} • ${session.termLabel}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _BoardBadge(
                        label: '$count records',
                        tone: const Color(0xFFEAF1FF),
                        textColor: const Color(0xFF155EEF),
                      ),
                      _BoardBadge(
                        label: session.scopeLabel,
                        tone: const Color(0xFFE8FFF6),
                        textColor: const Color(0xFF0F766E),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _createSession() {
    if (_nameController.text.trim().isEmpty || _selectedClasses.isEmpty) {
      return;
    }
    ref
        .read(schoolRecordsProvider.notifier)
        .createExamSession(
          name: _nameController.text.trim(),
          academicYear: _yearController.text.trim(),
          termLabel: _termController.text.trim(),
          type: _type,
          scopeLabel: _scopeController.text.trim(),
          targetClasses: _selectedClasses.toList(),
          notes: _notesController.text.trim(),
        );
    _nameController.clear();
    _notesController.clear();
    setState(() {
      _selectedClasses.clear();
      _type = ExamSessionType.mock;
    });
  }

  Future<void> _exportSession(BuildContext context, ExamSession session) async {
    final List<HistoricalExamRecord> records = widget.records
        .where((HistoricalExamRecord item) => item.examSessionId == session.id)
        .toList();
    final ReportExportData report = ReportExportData(
      title: '${session.name} Historical Report',
      subtitle:
          'Archived learner results prepared for comparison, reporting, and backend persistence.',
      summary: <ReportSummaryItem>[
        ReportSummaryItem(label: 'Academic Year', value: session.academicYear),
        ReportSummaryItem(label: 'Term', value: session.termLabel),
        ReportSummaryItem(label: 'Type', value: session.type.label),
        ReportSummaryItem(label: 'Records', value: '${records.length}'),
      ],
      sections: <ReportExportSection>[
        ReportExportSection(
          title: 'Imported Historical Results',
          headers: const <String>[
            'Student',
            'Admission',
            'Class',
            'Average',
            'Division',
          ],
          rows: records.map((HistoricalExamRecord record) {
            return <Object?>[
              record.studentName,
              record.admissionNumber,
              record.className,
              record.result.averageScore.toStringAsFixed(1),
              record.result.division,
            ];
          }).toList(),
        ),
      ],
    );

    final String? path = await ReportExporter.exportReport(
      suggestedBaseName: session.name.toLowerCase().replaceAll(' ', '_'),
      report: report,
      format: ReportFileFormat.excel,
    );

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          path == null
              ? 'Export cancelled.'
              : 'Historical session report saved to $path',
        ),
      ),
    );
  }
}

class _StudentRegistryBoard extends ConsumerStatefulWidget {
  const _StudentRegistryBoard({
    required this.records,
    required this.currentResults,
  });

  final List<StudentMasterRecord> records;
  final List<StudentResultRecord> currentResults;

  @override
  ConsumerState<_StudentRegistryBoard> createState() =>
      _StudentRegistryBoardState();
}

class _StudentRegistryBoardState extends ConsumerState<_StudentRegistryBoard> {
  final TextEditingController _admissionController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _classController = TextEditingController();
  final TextEditingController _guardianController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  StudentGender _gender = StudentGender.female;
  StudentStatus _status = StudentStatus.active;

  @override
  void dispose() {
    _admissionController.dispose();
    _nameController.dispose();
    _classController.dispose();
    _guardianController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: _admissionController,
          decoration: const InputDecoration(labelText: 'Admission number'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Student name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _classController,
          decoration: const InputDecoration(labelText: 'Class'),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _guardianController,
                decoration: const InputDecoration(labelText: 'Guardian'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: DropdownButtonFormField<StudentGender>(
                initialValue: _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: StudentGender.values.map((StudentGender gender) {
                  return DropdownMenuItem<StudentGender>(
                    value: gender,
                    child: Text(gender.label),
                  );
                }).toList(),
                onChanged: (StudentGender? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _gender = value;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<StudentStatus>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: StudentStatus.values.map((StudentStatus status) {
                  return DropdownMenuItem<StudentStatus>(
                    value: status,
                    child: Text(status.label),
                  );
                }).toList(),
                onChanged: (StudentStatus? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _status = value;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Registry notes'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_rounded),
          label: const Text('Save Registry Record'),
        ),
        const SizedBox(height: 18),
        ...widget.records.take(5).map((StudentMasterRecord record) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    record.fullName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${record.admissionNumber} • ${record.className}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _BoardBadge(
                        label: record.latestDivision,
                        tone: const Color(0xFFF1E8FF),
                        textColor: const Color(0xFF7C3AED),
                      ),
                      _BoardBadge(
                        label: '${record.latestAverage.toStringAsFixed(1)}%',
                        tone: const Color(0xFFEAF1FF),
                        textColor: const Color(0xFF155EEF),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _save() {
    if (_admissionController.text.trim().isEmpty ||
        _nameController.text.trim().isEmpty ||
        _classController.text.trim().isEmpty) {
      return;
    }

    final StudentResultRecord? current = widget.currentResults.where((
      StudentResultRecord item,
    ) {
      return item.admissionNumber == _admissionController.text.trim();
    }).firstOrNull;

    ref
        .read(schoolRecordsProvider.notifier)
        .saveStudentMasterRecord(
          StudentMasterRecord(
            id: 'registry-${_admissionController.text.trim()}',
            admissionNumber: _admissionController.text.trim(),
            fullName: _nameController.text.trim(),
            formLevel: _classController.text
                .trim()
                .split(' ')
                .take(2)
                .join(' '),
            className: _classController.text.trim(),
            guardianName: _guardianController.text.trim(),
            guardianPhone: _phoneController.text.trim(),
            gender: _gender,
            dateOfBirth: DateTime(2009, 1, 1),
            admissionDate: DateTime.now(),
            status: _status,
            subjectCombination:
                current?.subjectResults
                    .map((SubjectResult item) => item.subject)
                    .toList() ??
                kNectaOLevelDefaultSubjectNames,
            notes: _notesController.text.trim(),
            latestAverage: current?.averageScore ?? 0,
            latestDivision: current?.division ?? 'Pending',
            riskLevel: current?.riskLevel ?? RiskLevel.watch,
          ),
        );

    _admissionController.clear();
    _nameController.clear();
    _classController.clear();
    _guardianController.clear();
    _phoneController.clear();
    _notesController.clear();
  }
}

class _ImportBatchBoard extends StatelessWidget {
  const _ImportBatchBoard({required this.batches});

  final List<HistoricalImportBatch> batches;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: batches.map((HistoricalImportBatch batch) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  batch.sessionName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  '${batch.fileName} • ${_dateLabel(batch.importedAt)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _BoardBadge(
                      label: '${batch.recordCount} records',
                      tone: const Color(0xFFEAF1FF),
                      textColor: const Color(0xFF155EEF),
                    ),
                    _BoardBadge(
                      label: '${batch.warningCount} warnings',
                      tone: const Color(0xFFFFF3E8),
                      textColor: const Color(0xFFEA580C),
                    ),
                    _BoardBadge(
                      label: batch.status.label,
                      tone: const Color(0xFFE8FFF6),
                      textColor: const Color(0xFF0F766E),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RecordsHero extends StatelessWidget {
  const _RecordsHero({required this.overview, required this.archive});

  final SchoolOverview overview;
  final HistoricalRecordsOverview archive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF0F172A), Color(0xFF155EEF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Historical records now live beside daily operations',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Build a real archive for mock, national, and internal exams so current performance can be compared with what the school has done before.',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${overview.schoolName} • ${archive.totalImportBatches} import batches • ${archive.trackedAcademicYears} academic years tracked',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _HeroStat(
                    label: 'National sessions',
                    value: '${archive.nationalSessions}',
                  ),
                  const SizedBox(height: 10),
                  _HeroStat(
                    label: 'Mock sessions',
                    value: '${archive.mockSessions}',
                  ),
                  const SizedBox(height: 10),
                  _HeroStat(
                    label: 'Registry records',
                    value: '${archive.studentRegistryCount}',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordsBoard extends StatelessWidget {
  const _RecordsBoard({
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final Color tone;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE6ECF5)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: tone.withValues(alpha: 0.08),
              blurRadius: 32,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569)),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.tone,
  });

  final String label;
  final String value;
  final String detail;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE8EDF5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: tone,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardBadge extends StatelessWidget {
  const _BoardBadge({
    required this.label,
    required this.tone,
    required this.textColor,
  });

  final String label;
  final Color tone;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.76),
            ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

String _dateLabel(DateTime value) {
  return '${value.month}/${value.day}/${value.year}';
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) {
      return null;
    }
    return first;
  }
}
