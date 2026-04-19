import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/education_entities.dart';
import '../../domain/entities/school_records_entities.dart';
import '../../domain/repositories/student_management_repository.dart';

class SupabaseStudentManagementRepository
    implements StudentManagementRepository {
  SupabaseStudentManagementRepository({required SupabaseClient? client})
    : _client = client;

  final SupabaseClient? _client;

  @override
  Future<List<District>> getDistricts() async {
    return _safe(
      () async {
        final List<Map<String, dynamic>> rows = await _selectRows('districts');
        return rows.map(_districtFromRow).toList(growable: false);
      },
      fallback: const <District>[],
    );
  }

  @override
  Future<List<School>> getSchools(String districtId) async {
    return _safe(
      () async {
        final List<Map<String, dynamic>> rows = await _selectRows(
          'schools',
          filterColumn: 'district_id',
          filterValue: districtId,
        );
        return rows.map(_schoolFromRow).toList(growable: false);
      },
      fallback: const <School>[],
    );
  }

  @override
  Future<List<SchoolClass>> getClasses(String schoolId) async {
    return _safe(
      () async {
        final List<Map<String, dynamic>> rows = await _selectRows(
          'classes',
          filterColumn: 'school_id',
          filterValue: schoolId,
        );
        return rows.map(_classFromRow).toList(growable: false);
      },
      fallback: const <SchoolClass>[],
    );
  }

  @override
  Future<List<Student>> getStudents(String classId) async {
    return _safe(
      () async {
        final List<Map<String, dynamic>> rows = await _selectRows(
          'students',
          filterColumn: 'class_id',
          filterValue: classId,
        );
        return rows.map(_studentFromRow).toList(growable: false);
      },
      fallback: const <Student>[],
    );
  }

  @override
  Future<Student?> getStudent(String studentId) async {
    return _safe(
      () async {
        final Map<String, dynamic>? row = await _maybeSingleRow(
          'students',
          filterColumn: 'id',
          filterValue: studentId,
        );
        return row == null ? null : _studentFromRow(row);
      },
      fallback: null,
    );
  }

  @override
  Future<DashboardSummary> getDashboardSummary() async {
    return _safe(
      () async {
        final List<District> districts = await getDistricts();
        final List<School> schools = await _loadAllSchools();
        final List<Student> students = await _loadAllStudents();

        if (students.isEmpty) {
          return DashboardSummary(
            totalDistricts: districts.length,
            totalSchools: schools.length,
            totalStudents: 0,
            averageAttendance: 0,
            averageScore: 0,
            atRiskStudents: 0,
            focusStudentId: 'none',
            focusStudentName: 'No student data',
            districtPerformance: districts
                .map(
                  (District district) => ScorePoint(
                    label: district.name.split(' ').first,
                    value: district.averageScore,
                  ),
                )
                .toList(growable: false),
            systemTrend: const <ScorePoint>[],
          );
        }

        final Student focusStudent = students.reduce((Student current, Student next) {
          if (next.riskLevel == RiskLevel.urgent &&
              current.riskLevel != RiskLevel.urgent) {
            return next;
          }
          if (next.riskLevel == current.riskLevel &&
              next.attendanceRate < current.attendanceRate) {
            return next;
          }
          return current;
        });

        return DashboardSummary(
          totalDistricts: districts.length,
          totalSchools: schools.length,
          totalStudents: students.length,
          averageAttendance: _average(
            students.map((Student student) => student.attendanceRate),
          ),
          averageScore: _average(
            students.map((Student student) => student.averageScore),
          ),
          atRiskStudents: students
              .where((Student student) => student.riskLevel != RiskLevel.stable)
              .length,
          focusStudentId: focusStudent.id,
          focusStudentName: focusStudent.fullName,
          districtPerformance: districts
              .map(
                (District district) => ScorePoint(
                  label: district.name.split(' ').first,
                  value: district.averageScore,
                ),
              )
              .toList(growable: false),
          systemTrend: _systemTrend(students),
        );
      },
      fallback: const DashboardSummary(
        totalDistricts: 0,
        totalSchools: 0,
        totalStudents: 0,
        averageAttendance: 0,
        averageScore: 0,
        atRiskStudents: 0,
        focusStudentId: 'none',
        focusStudentName: 'No student data',
        districtPerformance: <ScorePoint>[],
        systemTrend: <ScorePoint>[],
      ),
    );
  }

  @override
  Future<ScopeSummary> getScopeSummary(ScopeRequest request) async {
    return _safe(
      () async {
        final List<District> districts = await getDistricts();
        final List<School> schools = await _loadAllSchools();
        final List<SchoolClass> classes = await _loadAllClasses();
        final List<Student> students = await _loadAllStudents();

        if (students.isEmpty) {
          return const ScopeSummary(
            title: 'No data',
            subtitle: 'No student records found in Supabase yet.',
            totalStudents: 0,
            averageAttendance: 0,
            averageScore: 0,
            atRiskStudents: 0,
            topPerformer: 'N/A',
            riskDistribution: <String, int>{
              'Stable': 0,
              'Watch': 0,
              'Urgent': 0,
            },
            trend: <ScorePoint>[],
          );
        }

        Iterable<Student> scopedStudents = students;
        String title = 'System overview';
        String subtitle = 'District-wide readiness, attendance, and learner risk.';

        if (request.studentId != null) {
          final Student? student = _findById(
            students,
            request.studentId!,
            (Student item) => item.id,
          );
          if (student != null) {
            return ScopeSummary(
              title: student.fullName,
              subtitle: '${student.gradeLevel} learner profile',
              totalStudents: 1,
              averageAttendance: student.attendanceRate,
              averageScore: student.averageScore,
              atRiskStudents: student.riskLevel == RiskLevel.stable ? 0 : 1,
              topPerformer: student.fullName,
              riskDistribution: <String, int>{
                'Stable': student.riskLevel == RiskLevel.stable ? 1 : 0,
                'Watch': student.riskLevel == RiskLevel.watch ? 1 : 0,
                'Urgent': student.riskLevel == RiskLevel.urgent ? 1 : 0,
              },
              trend: _studentTrend(student),
            );
          }
        } else if (request.classId != null) {
          scopedStudents = students.where(
            (Student student) => student.classId == request.classId,
          );
          final SchoolClass? schoolClass = _findById(
            classes,
            request.classId!,
            (SchoolClass item) => item.id,
          );
          if (schoolClass != null) {
            title = schoolClass.name;
            subtitle =
                '${schoolClass.teacher} • ${schoolClass.totalStudents} learners';
          }
        } else if (request.schoolId != null) {
          scopedStudents = students.where(
            (Student student) => student.schoolId == request.schoolId,
          );
          final School? school = _findById(
            schools,
            request.schoolId!,
            (School item) => item.id,
          );
          if (school != null) {
            title = school.name;
            subtitle =
                '${school.principal} • ${school.totalClasses} active classes';
          }
        } else if (request.districtId != null) {
          scopedStudents = students.where(
            (Student student) => student.districtId == request.districtId,
          );
          final District? district = _findById(
            districts,
            request.districtId!,
            (District item) => item.id,
          );
          if (district != null) {
            title = district.name;
            subtitle = '${district.regionLabel} • ${district.focusArea}';
          }
        }

        final List<Student> list = scopedStudents.toList(growable: false);
        if (list.isEmpty) {
          return ScopeSummary(
            title: title,
            subtitle: subtitle,
            totalStudents: 0,
            averageAttendance: 0,
            averageScore: 0,
            atRiskStudents: 0,
            topPerformer: 'N/A',
            riskDistribution: const <String, int>{
              'Stable': 0,
              'Watch': 0,
              'Urgent': 0,
            },
            trend: const <ScorePoint>[],
          );
        }

        final Student topPerformer = list.reduce(
          (Student current, Student next) =>
              next.averageScore > current.averageScore ? next : current,
        );

        return ScopeSummary(
          title: title,
          subtitle: subtitle,
          totalStudents: list.length,
          averageAttendance: _average(
            list.map((Student student) => student.attendanceRate),
          ),
          averageScore: _average(
            list.map((Student student) => student.averageScore),
          ),
          atRiskStudents: list
              .where((Student student) => student.riskLevel != RiskLevel.stable)
              .length,
          topPerformer: topPerformer.fullName,
          riskDistribution: <String, int>{
            'Stable': list
                .where((Student student) => student.riskLevel == RiskLevel.stable)
                .length,
            'Watch': list
                .where((Student student) => student.riskLevel == RiskLevel.watch)
                .length,
            'Urgent': list
                .where((Student student) => student.riskLevel == RiskLevel.urgent)
                .length,
          },
          trend: _systemTrend(list),
        );
      },
      fallback: const ScopeSummary(
        title: 'No data',
        subtitle: 'No live records found yet.',
        totalStudents: 0,
        averageAttendance: 0,
        averageScore: 0,
        atRiskStudents: 0,
        topPerformer: 'N/A',
        riskDistribution: <String, int>{
          'Stable': 0,
          'Watch': 0,
          'Urgent': 0,
        },
        trend: <ScorePoint>[],
      ),
    );
  }

  @override
  Future<List<ExamSession>> getExamSessions() async {
    return const <ExamSession>[];
  }

  @override
  Future<List<HistoricalExamRecord>> getHistoricalExamRecords() async {
    return const <HistoricalExamRecord>[];
  }

  @override
  Future<List<HistoricalImportBatch>> getHistoricalImportBatches() async {
    return const <HistoricalImportBatch>[];
  }

  @override
  Future<List<StudentMasterRecord>> getStudentMasterRecords() async {
    final List<Map<String, dynamic>> rows = await _safe(
      () => _selectRows('students'),
      fallback: const <Map<String, dynamic>>[],
    );

    return rows.map((Map<String, dynamic> row) {
      return StudentMasterRecord(
        id: _string(row, 'id'),
        admissionNumber: _string(row, 'admission_number'),
        fullName: _string(row, 'full_name'),
        formLevel: _string(row, 'grade_level'),
        className: _string(row, 'class_name'),
        guardianName: '',
        guardianPhone: '',
        gender: StudentGender.female,
        dateOfBirth: DateTime(2009, 1, 1),
        admissionDate: DateTime.now(),
        status: StudentStatus.active,
        subjectCombination: _listValue(row, 'subjects')
            .map<String>((dynamic value) => value.toString())
            .toList(growable: false),
        notes: '',
        latestAverage: _doubleValue(row, 'average_score'),
        latestDivision: _string(
          _mapValue(row, 'student_profile'),
          'division',
          fallback: 'Division 0',
        ),
        riskLevel: _riskLevelFromString(
          _string(row, 'risk_level', fallback: 'stable'),
        ),
      );
    }).toList(growable: false);
  }

  @override
  Future<SchoolProfile> getSchoolProfile() async {
    final Map<String, dynamic>? row = await _safe(
      () => _maybeSingleRow(
        'settings',
        filterColumn: 'id',
        filterValue: 'deadlines',
      ),
      fallback: null,
    );
    final Map<String, dynamic> payload = row == null
        ? const <String, dynamic>{}
        : _mapValue(row, 'payload');

    return SchoolProfile(
      schoolName: _string(payload, 'school_name'),
      districtName: _string(payload, 'district_name'),
      tagline: '',
      about: '',
      mission: '',
      vision: '',
      logoUrl: '',
      heroImageUrl: '',
      introVideoUrl: '',
      galleryImageUrls: const <String>[],
      galleryVideoUrls: const <String>[],
    );
  }

  @override
  Future<List<TeacherBiography>> getTeacherBiographies() async {
    final List<Map<String, dynamic>> rows = await _safe(
      () => _selectRows('teachers'),
      fallback: const <Map<String, dynamic>>[],
    );

    return rows.map((Map<String, dynamic> row) {
      final String subject = _string(row, 'subject');
      return TeacherBiography(
        id: _string(row, 'id'),
        name: _string(row, 'name'),
        subject: subject,
        assignedClass: _string(row, 'assigned_class'),
        roleTitle: subject.isEmpty ? 'Teacher' : '$subject Teacher',
        biography: '',
        qualifications: '',
        yearsOfService: 0,
        photoUrl: '',
        introVideoUrl: '',
        galleryImageUrls: const <String>[],
        galleryVideoUrls: const <String>[],
      );
    }).toList(growable: false);
  }

  Future<T> _safe<T>(Future<T> Function() action, {required T fallback}) async {
    if (_client == null) {
      return fallback;
    }

    try {
      return await action();
    } on Object {
      return fallback;
    }
  }

  Future<List<School>> _loadAllSchools() async {
    final List<Map<String, dynamic>> rows = await _selectRows('schools');
    return rows.map(_schoolFromRow).toList(growable: false);
  }

  Future<List<SchoolClass>> _loadAllClasses() async {
    final List<Map<String, dynamic>> rows = await _selectRows('classes');
    return rows.map(_classFromRow).toList(growable: false);
  }

  Future<List<Student>> _loadAllStudents() async {
    final List<Map<String, dynamic>> rows = await _selectRows('students');
    return rows.map(_studentFromRow).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _selectRows(
    String table, {
    String? filterColumn,
    Object? filterValue,
  }) async {
    if (_client == null) {
      return const <Map<String, dynamic>>[];
    }

    dynamic query = _client.from(table).select();
    if (filterColumn != null) {
      query = query.eq(filterColumn, filterValue);
    }

    final dynamic response = await query;
    final List<dynamic> rows = List<dynamic>.from(response as List);
    return rows.map(_asMap).toList(growable: false);
  }

  Future<Map<String, dynamic>?> _maybeSingleRow(
    String table, {
    required String filterColumn,
    required Object filterValue,
  }) async {
    if (_client == null) {
      return null;
    }

    final dynamic row = await _client
        .from(table)
        .select()
        .eq(filterColumn, filterValue)
        .maybeSingle();
    if (row == null) {
      return null;
    }
    return _asMap(row);
  }

  District _districtFromRow(Map<String, dynamic> row) {
    return District(
      id: _string(row, 'id'),
      name: _string(row, 'name'),
      regionLabel: _string(row, 'region_label', fallback: 'Unknown region'),
      totalSchools: _intValue(row, 'total_schools'),
      totalStudents: _intValue(row, 'total_students'),
      averageAttendance: _doubleValue(row, 'average_attendance'),
      averageScore: _doubleValue(row, 'average_score'),
      focusArea: _string(row, 'focus_area', fallback: 'General monitoring'),
    );
  }

  School _schoolFromRow(Map<String, dynamic> row) {
    return School(
      id: _string(row, 'id'),
      districtId: _string(row, 'district_id'),
      name: _string(row, 'name'),
      principal: _string(row, 'principal', fallback: 'Unknown principal'),
      totalClasses: _intValue(row, 'total_classes'),
      totalStudents: _intValue(row, 'total_students'),
      averageAttendance: _doubleValue(row, 'average_attendance'),
      averageScore: _doubleValue(row, 'average_score'),
    );
  }

  SchoolClass _classFromRow(Map<String, dynamic> row) {
    return SchoolClass(
      id: _string(row, 'id'),
      schoolId: _string(row, 'school_id'),
      districtId: _string(row, 'district_id'),
      name: _string(row, 'name'),
      teacher: _string(row, 'teacher', fallback: 'Unassigned'),
      totalStudents: _intValue(row, 'total_students'),
      averageAttendance: _doubleValue(row, 'average_attendance'),
      averageScore: _doubleValue(row, 'average_score'),
    );
  }

  Student _studentFromRow(Map<String, dynamic> row) {
    final Map<String, dynamic> subjectScores = _mapValue(
      row,
      'subject_scores',
    );
    final List<dynamic> monthlyPerformance = _listValue(
      row,
      'monthly_performance',
    );

    return Student(
      id: _string(row, 'id'),
      districtId: _string(row, 'district_id'),
      schoolId: _string(row, 'school_id'),
      classId: _string(row, 'class_id'),
      fullName: _string(row, 'full_name'),
      gradeLevel: _string(row, 'grade_level', fallback: 'Unknown class'),
      averageScore: _doubleValue(row, 'average_score'),
      gpa: _doubleValue(row, 'gpa'),
      attendanceRate: _doubleValue(row, 'attendance_rate'),
      riskLevel: _riskLevelFromString(
        _string(row, 'risk_level', fallback: 'stable'),
      ),
      subjectScores: subjectScores.map<String, double>((
        String key,
        dynamic value,
      ) {
        return MapEntry<String, double>(key, _numToDouble(value));
      }),
      monthlyPerformance: monthlyPerformance
          .map<double>(_numToDouble)
          .toList(growable: false),
    );
  }

  T? _findById<T>(List<T> items, String id, String Function(T item) getId) {
    for (final T item in items) {
      if (getId(item) == id) {
        return item;
      }
    }
    return null;
  }

  List<ScorePoint> _studentTrend(Student student) {
    return List<ScorePoint>.generate(student.monthlyPerformance.length, (
      int index,
    ) {
      return ScorePoint(
        label: 'P${index + 1}',
        value: student.monthlyPerformance[index],
      );
    });
  }

  List<ScorePoint> _systemTrend(List<Student> students) {
    if (students.isEmpty) {
      return const <ScorePoint>[];
    }

    final int longestSeries = students.fold<int>(0, (int current, Student next) {
      return next.monthlyPerformance.length > current
          ? next.monthlyPerformance.length
          : current;
    });

    return List<ScorePoint>.generate(longestSeries, (int index) {
      final List<double> values = students
          .where((Student student) => student.monthlyPerformance.length > index)
          .map((Student student) => student.monthlyPerformance[index])
          .toList(growable: false);
      return ScorePoint(
        label: 'P${index + 1}',
        value: _average(values),
      );
    });
  }

  double _average(Iterable<double> values) {
    final List<double> list = values.toList(growable: false);
    if (list.isEmpty) {
      return 0;
    }
    final double total = list.fold<double>(0, (double sum, double value) {
      return sum + value;
    });
    return total / list.length;
  }

  Map<String, dynamic> _asMap(dynamic row) {
    return Map<String, dynamic>.from(row as Map);
  }

  String _string(
    Map<String, dynamic> row,
    String key, {
    String fallback = '',
  }) {
    final dynamic value = row[key];
    if (value == null) {
      return fallback;
    }
    return value.toString();
  }

  int _intValue(Map<String, dynamic> row, String key) {
    final dynamic value = row[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _doubleValue(Map<String, dynamic> row, String key) {
    return _numToDouble(row[key]);
  }

  double _numToDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic> _mapValue(Map<String, dynamic> row, String key) {
    final dynamic value = row[key];
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return const <String, dynamic>{};
  }

  List<dynamic> _listValue(Map<String, dynamic> row, String key) {
    final dynamic value = row[key];
    if (value is List) {
      return value;
    }
    return const <dynamic>[];
  }

  RiskLevel _riskLevelFromString(String value) {
    switch (value.toLowerCase()) {
      case 'urgent':
        return RiskLevel.urgent;
      case 'watch':
        return RiskLevel.watch;
      default:
        return RiskLevel.stable;
    }
  }
}
