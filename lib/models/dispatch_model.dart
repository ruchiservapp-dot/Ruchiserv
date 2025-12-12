class Dispatch {
  final int? id;
  final int orderId;
  final String dispatchTime;
  final String status; // Pending, Ready, Dispatched, Delivered
  final String? driverName;
  final String? vehicleNumber;
  final String? notes;

  Dispatch({
    this.id,
    required this.orderId,
    required this.dispatchTime,
    this.status = 'Pending',
    this.driverName,
    this.vehicleNumber,
    this.notes,
  });

  factory Dispatch.fromJson(Map<String, dynamic> json) {
    return Dispatch(
      id: json['id'],
      orderId: json['orderId'],
      dispatchTime: json['dispatchTime'],
      status: json['status'] ?? 'Pending',
      driverName: json['driverName'],
      vehicleNumber: json['vehicleNumber'],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderId': orderId,
      'dispatchTime': dispatchTime,
      'status': status,
      'driverName': driverName,
      'vehicleNumber': vehicleNumber,
      'notes': notes,
    };
  }
}
