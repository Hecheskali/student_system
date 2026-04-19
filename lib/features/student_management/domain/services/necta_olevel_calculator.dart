import '../entities/education_entities.dart';

class NectaOLevelGrade {
  const NectaOLevelGrade({
    required this.letter,
    required this.point,
    required this.passed,
  });

  final String letter;
  final int point;
  final bool passed;
}

class NectaOLevelDivisionSummary {
  const NectaOLevelDivisionSummary({
    required this.points,
    required this.division,
    required this.consideredSubjects,
    required this.passedSubjects,
  });

  final int points;
  final String division;
  final int consideredSubjects;
  final int passedSubjects;
}

class NectaOLevelCalculator {
  static const int bestSubjectsCount = 7;

  static NectaOLevelGrade gradeForScore(double score) {
    final double normalized = score.clamp(0, 100).toDouble();
    if (normalized >= 75) {
      return const NectaOLevelGrade(letter: 'A', point: 1, passed: true);
    }
    if (normalized >= 65) {
      return const NectaOLevelGrade(letter: 'B', point: 2, passed: true);
    }
    if (normalized >= 45) {
      return const NectaOLevelGrade(letter: 'C', point: 3, passed: true);
    }
    if (normalized >= 30) {
      return const NectaOLevelGrade(letter: 'D', point: 4, passed: true);
    }
    return const NectaOLevelGrade(letter: 'F', point: 5, passed: false);
  }

  static NectaOLevelDivisionSummary divisionForSubjects(
    Iterable<SubjectResult> subjects, {
    bool coreOnly = false,
  }) {
    final List<SubjectResult> scoped = subjects.where((SubjectResult subject) {
      return !coreOnly || subject.isCoreSubject;
    }).toList();

    final List<int> points = scoped
        .map((SubjectResult subject) => subject.gradePoint)
        .toList()
      ..sort();

    while (points.length < bestSubjectsCount) {
      points.add(5);
    }

    final List<int> best = points.take(bestSubjectsCount).toList();
    final int total = best.fold<int>(0, (int sum, int point) => sum + point);
    final int passed = scoped
        .map((SubjectResult subject) => subject.grade)
        .where((String grade) => grade != 'F')
        .length;

    return NectaOLevelDivisionSummary(
      points: total,
      division: divisionForPoints(total),
      consideredSubjects: best.length,
      passedSubjects: passed,
    );
  }

  static NectaOLevelDivisionSummary divisionForScores(Iterable<double> scores) {
    final List<int> points = scores
        .map((double score) => gradeForScore(score).point)
        .toList()
      ..sort();

    while (points.length < bestSubjectsCount) {
      points.add(5);
    }

    final List<int> best = points.take(bestSubjectsCount).toList();
    final int total = best.fold<int>(0, (int sum, int point) => sum + point);
    final int passed = scores
        .where((double score) => gradeForScore(score).passed)
        .length;

    return NectaOLevelDivisionSummary(
      points: total,
      division: divisionForPoints(total),
      consideredSubjects: best.length,
      passedSubjects: passed,
    );
  }

  static String divisionForPoints(int points) {
    if (points >= 7 && points <= 17) {
      return 'Division I';
    }
    if (points >= 18 && points <= 21) {
      return 'Division II';
    }
    if (points >= 22 && points <= 25) {
      return 'Division III';
    }
    if (points >= 26 && points <= 33) {
      return 'Division IV';
    }
    return 'Division 0';
  }

  static String projectedDivisionForAverage(double averageScore) {
    return divisionForScores(
      List<double>.filled(bestSubjectsCount, averageScore.clamp(0, 100).toDouble()),
    ).division;
  }
}
