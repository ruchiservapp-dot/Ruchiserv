class Attendance {
  final int? id;
  final int staffId;
  final String date; // YYYY-MM-DD
  final String? punchInTime;
  final String? punchOutTime;
  final String? location; // Kitchen, Site, etc.
  final String status; // Present, Absent, Half-day

  Attendance({
    this.id,
    required this.staffId,
    required this.date,
    this.punchInTime,
    this.punchOutTime,
    this.location,
    this.status = 'Present',
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['id'],
      staffId: json['staffId'],
      date: json['date'],
      punchInTime: json['punchInTime'],
      punchOutTime: json['punchOutTime'],
      location: json['location'],
      status: json['status'] ?? 'Present',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staffId': staffId,
      'date': date,
      'punchInTime': punchInTime,
      'punchOutTime': punchOutTime,
      'location': location,
      'status': status,
    };
  }
}
