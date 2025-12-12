class Ingredient {
  final int? id;
  final String name;
  final String unit; // kg, gm, ltr, pcs
  final String category; // Vegetables, Meat, Spices, Grocery
  final double currentStock;
  final double reorderLevel;

  Ingredient({
    this.id,
    required this.name,
    required this.unit,
    required this.category,
    this.currentStock = 0,
    this.reorderLevel = 0,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: json['id'],
      name: json['name'],
      unit: json['unit'],
      category: json['category'],
      currentStock: (json['currentStock'] as num?)?.toDouble() ?? 0,
      reorderLevel: (json['reorderLevel'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
      'category': category,
      'currentStock': currentStock,
      'reorderLevel': reorderLevel,
    };
  }
}

class BOM {
  final int? id;
  final String dishName; // Linking by name for simplicity as Dish ID might change if deleted/re-added
  final int ingredientId;
  final double quantity; // Qty per 1 Pax or per Dish Unit? Let's assume per 1 Pax for scalable MRP
  
  // Helper for UI
  final String? ingredientName;
  final String? unit;

  BOM({
    this.id,
    required this.dishName,
    required this.ingredientId,
    required this.quantity,
    this.ingredientName,
    this.unit,
  });

  factory BOM.fromJson(Map<String, dynamic> json) {
    return BOM(
      id: json['id'],
      dishName: json['dishName'],
      ingredientId: json['ingredientId'],
      quantity: (json['quantity'] as num).toDouble(),
      ingredientName: json['ingredientName'],
      unit: json['unit'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dishName': dishName,
      'ingredientId': ingredientId,
      'quantity': quantity,
    };
  }
}

class Supplier {
  final int? id;
  final String name;
  final String contact;
  final String category; // e.g., "Vegetable Vendor"

  Supplier({
    this.id,
    required this.name,
    required this.contact,
    required this.category,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'],
      name: json['name'],
      contact: json['contact'],
      category: json['category'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'contact': contact,
      'category': category,
    };
  }
}

class SupplierOrder {
  final int? id;
  final int supplierId;
  final String date;
  final String status; // Pending, Received
  final double totalAmount;

  SupplierOrder({
    this.id,
    required this.supplierId,
    required this.date,
    this.status = 'Pending',
    this.totalAmount = 0,
  });

  factory SupplierOrder.fromJson(Map<String, dynamic> json) {
    return SupplierOrder(
      id: json['id'],
      supplierId: json['supplierId'],
      date: json['date'],
      status: json['status'],
      totalAmount: (json['totalAmount'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supplierId': supplierId,
      'date': date,
      'status': status,
      'totalAmount': totalAmount,
    };
  }
}
