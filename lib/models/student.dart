class Student {
  final String id; // Firestore document ID
  final String studentId;
  final String name;
  final String course;
  final String yearLevel;
  /// Section letter: 'A', 'B', or 'C'. Empty string for legacy students.
  final String section;
  final String qrHash;
  final String email;
  final String avatarUrl;
  final bool isArchived;

  Student({
    required this.id,
    required this.studentId,
    required this.name,
    required this.course,
    required this.yearLevel,
    this.section = '',
    required this.qrHash,
    this.email = '',
    this.avatarUrl = '',
    this.isArchived = false,
  });

  factory Student.fromMap(Map<String, dynamic> data, String documentId) {
    return Student(
      id: documentId,
      studentId: data['student_id'] ?? '',
      name: data['name'] ?? '',
      course: data['course'] ?? '',
      yearLevel: data['year_level'] ?? '',
      section: data['section'] ?? '',
      qrHash: data['qr_hash'] ?? '',
      email: data['email'] ?? '',
      avatarUrl: data['avatar_url'] ?? '',
      isArchived: data['is_archived'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'student_id': studentId,
      'name': name,
      'course': course,
      'year_level': yearLevel,
      'section': section,
      'qr_hash': qrHash,
      'email': email,
      'avatar_url': avatarUrl,
      'is_archived': isArchived,
    };
  }
}
