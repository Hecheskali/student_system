// Form validation utilities for student addition and mark entry.
// Ensures data quality and system integrity.

class FormValidators {
  /// Validates student full name:
  /// - Must have at least 3 words
  /// - All uppercase letters
  /// - No numbers or special characters
  static String? validateStudentFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Student full name is required';
    }

    final String trimmed = value.trim();
    final List<String> words = trimmed.split(RegExp(r'\s+'));

    if (words.length < 3) {
      return 'Full name must have at least 3 names (e.g., JOHN PAUL SMITH)';
    }

    // Check if all words are alphabetic
    for (final String word in words) {
      if (!RegExp(r'^[A-Z]+$').hasMatch(word)) {
        return 'All names must be in CAPITAL LETTERS and contain only letters';
      }
    }

    return null;
  }

  /// Validates theory marks: must be between 0-100
  static String? validateTheoryMarks(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Theory mark is required';
    }

    final double? score = double.tryParse(value.trim());
    if (score == null) {
      return 'Enter a valid number';
    }

    if (score < 0 || score > 100) {
      return 'Theory marks must be between 0 and 100';
    }

    return null;
  }

  /// Validates practical marks: must be between 0-50
  static String? validatePracticalMarks(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Practical mark is required';
    }

    final double? score = double.tryParse(value.trim());
    if (score == null) {
      return 'Enter a valid number';
    }

    if (score < 0 || score > 50) {
      return 'Practical marks must be between 0 and 50';
    }

    return null;
  }

  /// Validates marks for non-science subjects: must be between 0-100
  static String? validateStandardMarks(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Mark is required';
    }

    final double? score = double.tryParse(value.trim());
    if (score == null) {
      return 'Enter a valid number';
    }

    if (score < 0 || score > 100) {
      return 'Marks must be between 0 and 100';
    }

    return null;
  }

  /// Validates exam/test label
  static String? validateExamLabel(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Exam label is required';
    }

    if (value.trim().length < 2) {
      return 'Label must be at least 2 characters';
    }

    if (value.trim().length > 50) {
      return 'Label must be less than 50 characters';
    }

    return null;
  }

  /// Checks if a subject is a science subject requiring practical marks
  static bool isScienceSubject(String subject) {
    final lower = subject.toLowerCase();
    return lower.contains('biology') ||
        lower.contains('physics') ||
        lower.contains('chemistry');
  }

  /// Converts student name to proper capital format
  static String formatStudentName(String name) {
    return name
        .trim()
        .split(RegExp(r'\s+'))
        .map((word) => word.toUpperCase())
        .join(' ');
  }
}

/// Helper class for managing admission numbers
class AdmissionNumberGenerator {
  /// Generates next admission number in sequence
  /// Format: "SCHOOL_PREFIX + 001, 002, etc."
  static String generateNextAdmissionNumber({
    required String schoolPrefix,
    required int nextSequenceNumber,
  }) {
    final String sequence = nextSequenceNumber.toString().padLeft(3, '0');
    return '$schoolPrefix-$sequence';
  }

  /// Validates admission number format
  static bool isValidAdmissionNumber(String admissionNumber) {
    return RegExp(r'^[A-Z0-9]+-\d{3}$').hasMatch(admissionNumber);
  }

  /// Extracts sequence number from admission number
  static int? extractSequenceNumber(String admissionNumber) {
    try {
      final List<String> parts = admissionNumber.split('-');
      if (parts.length == 2) {
        return int.tryParse(parts[1]);
      }
    } catch (e) {
      return null;
    }
    return null;
  }
}
