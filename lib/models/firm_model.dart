class Firm {
  final int? id;
  final String firmId;
  final String firmName;
  final String? contactPerson;
  final String? primaryMobile;
  final String? primaryEmail;
  final String? subscriptionPlan;
  final String? subscriptionStatus;
  final String? createdAt;
  final String? updatedAt;

  Firm({
    this.id,
    required this.firmId,
    required this.firmName,
    this.contactPerson,
    this.primaryMobile,
    this.primaryEmail,
    this.subscriptionPlan,
    this.subscriptionStatus,
    this.createdAt,
    this.updatedAt,
  });

  factory Firm.fromJson(Map<String, dynamic> json) {
    return Firm(
      id: json['id'],
      firmId: json['firmId'] ?? '',
      firmName: json['firmName'] ?? '',
      contactPerson: json['contactPerson'],
      primaryMobile: json['primaryMobile'],
      primaryEmail: json['primaryEmail'],
      subscriptionPlan: json['subscriptionPlan'],
      subscriptionStatus: json['subscriptionStatus'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'firmId': firmId,
      'firmName': firmName,
      'contactPerson': contactPerson,
      'primaryMobile': primaryMobile,
      'primaryEmail': primaryEmail,
      'subscriptionPlan': subscriptionPlan,
      'subscriptionStatus': subscriptionStatus,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
