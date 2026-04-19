import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  SupabaseClient get client => _client;

  static const String _usersTable = 'users';
  static const String _teachersTable = 'teachers';
  static const String _examsTable = 'exams';
  static const String _resultsTable = 'results';
  static const String _settingsTable = 'settings';
  static const String _studentsTable = 'students';

  GoTrueClient get auth => _client.auth;

  User? get currentUser => auth.currentUser;

  Stream<AuthState> get authStateChanges => auth.onAuthStateChange;

  Future<AuthResponse> signInWithEmailAndPassword(
    String email,
    String password,
  ) {
    return auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> createUserWithEmailAndPassword(
    String email,
    String password,
  ) {
    return auth.signUp(email: email, password: password);
  }

  Future<void> signOut() async {
    await auth.signOut();
  }

  Future<void> createUserProfile(String uid, Map<String, dynamic> userData) async {
    await _client.from(_usersTable).upsert(<String, dynamic>{
      'id': uid,
      ...userData,
    });
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) {
    return _client.from(_usersTable).select().eq('id', uid).maybeSingle();
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> updates) async {
    await _client.from(_usersTable).update(updates).eq('id', uid);
  }

  Future<void> addTeacher(Map<String, dynamic> teacherData) async {
    await _client.from(_teachersTable).insert(teacherData);
  }

  Future<void> removeTeacher(String teacherId) async {
    await _client.from(_teachersTable).delete().eq('id', teacherId);
  }

  Stream<List<Map<String, dynamic>>> getTeachers() {
    return _client.from(_teachersTable).stream(primaryKey: <String>['id']);
  }

  Future<void> uploadExam(Map<String, dynamic> examData) async {
    await _client.from(_examsTable).insert(examData);
  }

  Future<void> updateExam(String examId, Map<String, dynamic> updates) async {
    await _client.from(_examsTable).update(updates).eq('id', examId);
  }

  Stream<List<Map<String, dynamic>>> getExams() {
    return _client.from(_examsTable).stream(primaryKey: <String>['id']);
  }

  Future<void> uploadStudentResult(Map<String, dynamic> resultData) async {
    await _client.from(_resultsTable).insert(resultData);
  }

  Future<void> updateStudentResult(
    String resultId,
    Map<String, dynamic> updates,
  ) async {
    await _client.from(_resultsTable).update(updates).eq('id', resultId);
  }

  Stream<List<Map<String, dynamic>>> getStudentResults() {
    return _client.from(_resultsTable).stream(primaryKey: <String>['id']);
  }

  Future<void> setUploadDeadline(DateTime deadline) {
    return _upsertDeadlineField(
      <String, dynamic>{'upload_deadline': deadline.toIso8601String()},
    );
  }

  Future<void> setEditDeadline(DateTime deadline) {
    return _upsertDeadlineField(
      <String, dynamic>{'edit_deadline': deadline.toIso8601String()},
    );
  }

  Future<Map<String, dynamic>?> getDeadlines() {
    return _client
        .from(_settingsTable)
        .select()
        .eq('id', 'deadlines')
        .maybeSingle();
  }

  Future<void> addStudent(Map<String, dynamic> studentData) async {
    await _client.from(_studentsTable).insert(studentData);
  }

  Stream<List<Map<String, dynamic>>> getStudents() {
    return _client.from(_studentsTable).stream(primaryKey: <String>['id']);
  }

  Future<void> _upsertDeadlineField(Map<String, dynamic> value) async {
    await _client.from(_settingsTable).upsert(
      <String, dynamic>{'id': 'deadlines', ...value},
      onConflict: 'id',
    );
  }
}
