class Staff {
  final int? id;
  final String name;
  final String role; // Chef, Helper, Driver, etc.
  final String? mobile;
  final double? salary;
  final String? joinDate;
  final int isActive; // 1 for active, 0 for inactive

  Staff({
    this.id,
    required this.name,
    required this.role,
    this.mobile,
    this.salary,
    this.joinDate,
    this.isActive = 1,
  });

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['id'],
      name: json['name'] ?? '',
      role: json['role'] ?? 'Helper',
      mobile: json['mobile'],
      salary: (json['salary'] as num?)?.toDouble(),
      joinDate: json['joinDate'],
      isActive: json['isActive'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'mobile': mobile,
      'salary': salary,
      'joinDate': joinDate,
      'isActive': isActive,
    };
  }
}
