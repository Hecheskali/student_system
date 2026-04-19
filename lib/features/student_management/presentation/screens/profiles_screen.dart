import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/education_entities.dart';
import '../../domain/entities/school_records_entities.dart';
import '../providers/school_records_providers.dart';
import '../providers/student_management_providers.dart';
import '../widgets/motion_widgets.dart';
import '../widgets/workspace_shell.dart';

class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SchoolAdminState adminState = ref.watch(schoolAdminProvider);
    final SchoolRecordsState records = ref.watch(schoolRecordsProvider);
    final SessionUser? session = adminState.session;

    if (session == null) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Login to open school profiles'),
          ),
        ),
      );
    }

    return WorkspaceShell(
      currentSection: WorkspaceSection.profiles,
      session: session,
      eyebrow: 'Profiles And Media',
      title: 'School And Teacher Profiles',
      subtitle:
          'Maintain the school biography, media gallery, and teacher profile pages with text, image links, and video links.',
      actions: <Widget>[
        FilledButton.tonalIcon(
          onPressed: () => context.go('/records'),
          icon: const Icon(Icons.history_edu_rounded),
          label: const Text('Records Center'),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: <Widget>[
          const RevealMotion(child: _ProfilesHero()),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool stacked = constraints.maxWidth < 1180;
              final Widget left = _ProfileBoard(
                tone: const Color(0xFF155EEF),
                title: 'School Profile Page',
                subtitle:
                    'Capture the school story, mission, visual identity, and media links so the platform introduces the institution properly.',
                child: _SchoolProfileEditor(profile: records.schoolProfile),
              );
              final Widget right = _ProfileBoard(
                tone: const Color(0xFF0F766E),
                title: 'Teacher Biography Pages',
                subtitle:
                    'Each teacher can have a profile with biography, qualifications, image links, and video links for a more complete school directory.',
                child: _TeacherBiographyEditor(
                  biographies: records.teacherBiographies,
                ),
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

class _SchoolProfileEditor extends ConsumerStatefulWidget {
  const _SchoolProfileEditor({required this.profile});

  final SchoolProfile profile;

  @override
  ConsumerState<_SchoolProfileEditor> createState() =>
      _SchoolProfileEditorState();
}

class _SchoolProfileEditorState extends ConsumerState<_SchoolProfileEditor> {
  late final TextEditingController _taglineController;
  late final TextEditingController _aboutController;
  late final TextEditingController _missionController;
  late final TextEditingController _visionController;
  late final TextEditingController _logoController;
  late final TextEditingController _heroImageController;
  late final TextEditingController _videoController;
  late final TextEditingController _galleryImagesController;
  late final TextEditingController _galleryVideosController;

  @override
  void initState() {
    super.initState();
    final SchoolProfile profile = widget.profile;
    _taglineController = TextEditingController(text: profile.tagline);
    _aboutController = TextEditingController(text: profile.about);
    _missionController = TextEditingController(text: profile.mission);
    _visionController = TextEditingController(text: profile.vision);
    _logoController = TextEditingController(text: profile.logoUrl);
    _heroImageController = TextEditingController(text: profile.heroImageUrl);
    _videoController = TextEditingController(text: profile.introVideoUrl);
    _galleryImagesController = TextEditingController(
      text: profile.galleryImageUrls.join('\n'),
    );
    _galleryVideosController = TextEditingController(
      text: profile.galleryVideoUrls.join('\n'),
    );
  }

  @override
  void dispose() {
    _taglineController.dispose();
    _aboutController.dispose();
    _missionController.dispose();
    _visionController.dispose();
    _logoController.dispose();
    _heroImageController.dispose();
    _videoController.dispose();
    _galleryImagesController.dispose();
    _galleryVideosController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SchoolProfile liveProfile = ref
        .watch(schoolRecordsProvider)
        .schoolProfile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _MediaPreviewCard(
          title: liveProfile.schoolName,
          subtitle: liveProfile.tagline,
          imageUrl: liveProfile.heroImageUrl,
          supportingLabel: liveProfile.introVideoUrl,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _taglineController,
          decoration: const InputDecoration(labelText: 'Tagline'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _aboutController,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'About the school'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _missionController,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Mission'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _visionController,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Vision'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _logoController,
          decoration: const InputDecoration(labelText: 'Logo image URL'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _heroImageController,
          decoration: const InputDecoration(labelText: 'Hero image URL'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _videoController,
          decoration: const InputDecoration(labelText: 'Intro video URL'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _galleryImagesController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Gallery image URLs',
            hintText: 'One link per line',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _galleryVideosController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Gallery video URLs',
            hintText: 'One link per line',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_rounded),
          label: const Text('Save School Profile'),
        ),
      ],
    );
  }

  void _save() {
    final SchoolProfile current = widget.profile;
    ref
        .read(schoolRecordsProvider.notifier)
        .saveSchoolProfile(
          current.copyWith(
            tagline: _taglineController.text.trim(),
            about: _aboutController.text.trim(),
            mission: _missionController.text.trim(),
            vision: _visionController.text.trim(),
            logoUrl: _logoController.text.trim(),
            heroImageUrl: _heroImageController.text.trim(),
            introVideoUrl: _videoController.text.trim(),
            galleryImageUrls: _splitLines(_galleryImagesController.text),
            galleryVideoUrls: _splitLines(_galleryVideosController.text),
          ),
        );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('School profile saved.')));
  }
}

class _TeacherBiographyEditor extends ConsumerStatefulWidget {
  const _TeacherBiographyEditor({required this.biographies});

  final List<TeacherBiography> biographies;

  @override
  ConsumerState<_TeacherBiographyEditor> createState() =>
      _TeacherBiographyEditorState();
}

class _TeacherBiographyEditorState
    extends ConsumerState<_TeacherBiographyEditor> {
  String? _selectedTeacherId;
  final TextEditingController _roleController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _qualificationController =
      TextEditingController();
  final TextEditingController _yearsController = TextEditingController();
  final TextEditingController _photoController = TextEditingController();
  final TextEditingController _videoController = TextEditingController();
  final TextEditingController _galleryImagesController =
      TextEditingController();
  final TextEditingController _galleryVideosController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.biographies.isNotEmpty) {
      _load(widget.biographies.first);
      _selectedTeacherId = widget.biographies.first.id;
    }
  }

  @override
  void dispose() {
    _roleController.dispose();
    _bioController.dispose();
    _qualificationController.dispose();
    _yearsController.dispose();
    _photoController.dispose();
    _videoController.dispose();
    _galleryImagesController.dispose();
    _galleryVideosController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<TeacherBiography> biographies = ref
        .watch(schoolRecordsProvider)
        .teacherBiographies;
    final TeacherBiography? selected = biographies.where((
      TeacherBiography item,
    ) {
      return item.id == _selectedTeacherId;
    }).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DropdownButtonFormField<String>(
          initialValue: _selectedTeacherId,
          decoration: const InputDecoration(labelText: 'Teacher'),
          items: biographies.map((TeacherBiography biography) {
            return DropdownMenuItem<String>(
              value: biography.id,
              child: Text('${biography.name} • ${biography.subject}'),
            );
          }).toList(),
          onChanged: (String? value) {
            setState(() {
              _selectedTeacherId = value;
            });
            final TeacherBiography? biography = biographies.where((
              TeacherBiography item,
            ) {
              return item.id == value;
            }).firstOrNull;
            if (biography != null) {
              _load(biography);
            }
          },
        ),
        if (selected != null) ...<Widget>[
          const SizedBox(height: 16),
          _MediaPreviewCard(
            title: selected.name,
            subtitle: '${selected.roleTitle} • ${selected.assignedClass}',
            imageUrl: selected.photoUrl,
            supportingLabel: selected.introVideoUrl,
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _roleController,
          decoration: const InputDecoration(labelText: 'Role title'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bioController,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Biography'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _qualificationController,
          decoration: const InputDecoration(labelText: 'Qualifications'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _yearsController,
          decoration: const InputDecoration(labelText: 'Years of service'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _photoController,
          decoration: const InputDecoration(labelText: 'Photo URL'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _videoController,
          decoration: const InputDecoration(labelText: 'Intro video URL'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _galleryImagesController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Gallery image URLs',
            hintText: 'One link per line',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _galleryVideosController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Gallery video URLs',
            hintText: 'One link per line',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: selected == null ? null : () => _save(selected),
          icon: const Icon(Icons.save_rounded),
          label: const Text('Save Teacher Biography'),
        ),
      ],
    );
  }

  void _load(TeacherBiography biography) {
    _roleController.text = biography.roleTitle;
    _bioController.text = biography.biography;
    _qualificationController.text = biography.qualifications;
    _yearsController.text = '${biography.yearsOfService}';
    _photoController.text = biography.photoUrl;
    _videoController.text = biography.introVideoUrl;
    _galleryImagesController.text = biography.galleryImageUrls.join('\n');
    _galleryVideosController.text = biography.galleryVideoUrls.join('\n');
  }

  void _save(TeacherBiography biography) {
    ref
        .read(schoolRecordsProvider.notifier)
        .saveTeacherBiography(
          biography.copyWith(
            roleTitle: _roleController.text.trim(),
            biography: _bioController.text.trim(),
            qualifications: _qualificationController.text.trim(),
            yearsOfService: int.tryParse(_yearsController.text.trim()) ?? 0,
            photoUrl: _photoController.text.trim(),
            introVideoUrl: _videoController.text.trim(),
            galleryImageUrls: _splitLines(_galleryImagesController.text),
            galleryVideoUrls: _splitLines(_galleryVideosController.text),
          ),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${biography.name} biography saved.')),
    );
  }
}

class _ProfilesHero extends StatelessWidget {
  const _ProfilesHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF0B132B), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'School identity belongs in the same system as school performance',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Give the platform real profile pages for the school and teachers, with writing, image links, and video links that can later connect to backend media storage.',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileBoard extends StatelessWidget {
  const _ProfileBoard({
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE8EDF5)),
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

class _MediaPreviewCard extends StatelessWidget {
  const _MediaPreviewCard({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.supportingLabel,
  });

  final String title;
  final String subtitle;
  final String imageUrl;
  final String supportingLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: AspectRatio(
              aspectRatio: 16 / 8,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) {
                  return Container(
                    color: const Color(0xFFE2E8F0),
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_not_supported_rounded),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  supportingLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF0F766E),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<String> _splitLines(String value) {
  return value
      .split('\n')
      .map((String item) => item.trim())
      .where((String item) => item.isNotEmpty)
      .toList();
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) {
      return null;
    }
    return first;
  }
}
