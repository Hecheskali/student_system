import '../entities/education_entities.dart';
import '../entities/school_records_entities.dart';

abstract class StudentManagementRepository {
  Future<List<District>> getDistricts();
  Future<List<School>> getSchools(String districtId);
  Future<List<SchoolClass>> getClasses(String schoolId);
  Future<List<Student>> getStudents(String classId);
  Future<Student?> getStudent(String studentId);
  Future<DashboardSummary> getDashboardSummary();
  Future<ScopeSummary> getScopeSummary(ScopeRequest request);
  Future<List<ExamSession>> getExamSessions();
  Future<List<HistoricalExamRecord>> getHistoricalExamRecords();
  Future<List<HistoricalImportBatch>> getHistoricalImportBatches();
  Future<List<StudentMasterRecord>> getStudentMasterRecords();
  Future<SchoolProfile> getSchoolProfile();
  Future<List<TeacherBiography>> getTeacherBiographies();
}
