enum NectaOLevelSubjectCategory {
  compulsory,
  scienceBusiness,
  optionalTechnical,
}

extension NectaOLevelSubjectCategoryX on NectaOLevelSubjectCategory {
  String get label {
    switch (this) {
      case NectaOLevelSubjectCategory.compulsory:
        return 'Compulsory';
      case NectaOLevelSubjectCategory.scienceBusiness:
        return 'Science and Business';
      case NectaOLevelSubjectCategory.optionalTechnical:
        return 'Optional and Technical';
    }
  }
}

class NectaOLevelSubjectDefinition {
  const NectaOLevelSubjectDefinition({
    required this.name,
    required this.category,
    this.isCompulsory = false,
  });

  final String name;
  final NectaOLevelSubjectCategory category;
  final bool isCompulsory;
}

const List<NectaOLevelSubjectDefinition> kNectaOLevelSubjects =
    <NectaOLevelSubjectDefinition>[
      NectaOLevelSubjectDefinition(
        name: 'Civics',
        category: NectaOLevelSubjectCategory.compulsory,
        isCompulsory: true,
      ),
      NectaOLevelSubjectDefinition(
        name: 'History',
        category: NectaOLevelSubjectCategory.compulsory,
        isCompulsory: true,
      ),
      NectaOLevelSubjectDefinition(
        name: 'Geography',
        category: NectaOLevelSubjectCategory.compulsory,
        isCompulsory: true,
      ),
      NectaOLevelSubjectDefinition(
        name: 'Kiswahili',
        category: NectaOLevelSubjectCategory.compulsory,
        isCompulsory: true,
      ),
      NectaOLevelSubjectDefinition(
        name: 'English Language',
        category: NectaOLevelSubjectCategory.compulsory,
        isCompulsory: true,
      ),
      NectaOLevelSubjectDefinition(
        name: 'Biology',
        category: NectaOLevelSubjectCategory.compulsory,
        isCompulsory: true,
      ),
      NectaOLevelSubjectDefinition(
        name: 'Basic Mathematics',
        category: NectaOLevelSubjectCategory.compulsory,
        isCompulsory: true,
      ),
      NectaOLevelSubjectDefinition(
        name: 'Physics',
        category: NectaOLevelSubjectCategory.scienceBusiness,
      ),
      NectaOLevelSubjectDefinition(
        name: 'Chemistry',
        category: NectaOLevelSubjectCategory.scienceBusiness,
      ),
      NectaOLevelSubjectDefinition(
        name: 'Commerce',
        category: NectaOLevelSubjectCategory.scienceBusiness,
      ),
      NectaOLevelSubjectDefinition(
        name: 'Book-keeping',
        category: NectaOLevelSubjectCategory.scienceBusiness,
      ),
      NectaOLevelSubjectDefinition(
        name: 'Bible Knowledge',
        category: NectaOLevelSubjectCategory.optionalTechnical,
      ),
      NectaOLevelSubjectDefinition(
        name: 'EDK',
        category: NectaOLevelSubjectCategory.optionalTechnical,
      ),
      NectaOLevelSubjectDefinition(
        name: 'Literature in English',
        category: NectaOLevelSubjectCategory.optionalTechnical,
      ),
      NectaOLevelSubjectDefinition(
        name: 'French',
        category: NectaOLevelSubjectCategory.optionalTechnical,
      ),
      NectaOLevelSubjectDefinition(
        name: 'Arabic',
        category: NectaOLevelSubjectCategory.optionalTechnical,
      ),
      NectaOLevelSubjectDefinition(
        name: 'Chinese',
        category: NectaOLevelSubjectCategory.optionalTechnical,
      ),
      NectaOLevelSubjectDefinition(
        name: 'Additional Mathematics',
        category: NectaOLevelSubjectCategory.optionalTechnical,
      ),
      NectaOLevelSubjectDefinition(
        name: 'Fine Art',
        category: NectaOLevelSubjectCategory.optionalTechnical,
      ),
      NectaOLevelSubjectDefinition(
        name: 'Music',
        category: NectaOLevelSubjectCategory.optionalTechnical,
      ),
      NectaOLevelSubjectDefinition(
        name: 'Physics',
        category: NectaOLevelSubjectCategory.optionalTechnical,
      ),
      NectaOLevelSubjectDefinition(
        name: 'Agricultural Science',
        category: NectaOLevelSubjectCategory.optionalTechnical,
      ),
      NectaOLevelSubjectDefinition(
        name: 'Computer Science',
        category: NectaOLevelSubjectCategory.optionalTechnical,
      ),
      NectaOLevelSubjectDefinition(
        name: 'Historia ya Tanzania na Maadili',
        category: NectaOLevelSubjectCategory.optionalTechnical,
      ),
      NectaOLevelSubjectDefinition(
        name: 'Business Studies',
        category: NectaOLevelSubjectCategory.optionalTechnical,
      ),
    ];

final List<String> kNectaOLevelSubjectNames = kNectaOLevelSubjects
    .map((NectaOLevelSubjectDefinition subject) => subject.name)
    .toList(growable: false);

final List<String> kNectaOLevelCompulsorySubjectNames = kNectaOLevelSubjects
    .where((NectaOLevelSubjectDefinition subject) => subject.isCompulsory)
    .map((NectaOLevelSubjectDefinition subject) => subject.name)
    .toList(growable: false);

const List<String> kNectaOLevelDefaultSubjectNames = <String>[
  'Civics',
  'History',
  'Geography',
  'Kiswahili',
  'English Language',
  'Computer Science',
  'Business Studies',
  'Historia ya Tanzania na Maadili',
  'Biology',
  'Basic Mathematics',
  'Physics',
  'Chemistry',
];
