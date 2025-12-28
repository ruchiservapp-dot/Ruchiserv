import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

/// Seeds sample dishes and ingredients for catering business
Future<void> seedDishesAndIngredients() async {
  final db = DatabaseHelper();
  final database = await db.database;
  
  // Check if dishes already exist
  final existingDishes = Sqflite.firstIntValue(
    await database.rawQuery('SELECT COUNT(*) FROM dish_master')
  );
  
  if ((existingDishes ?? 0) > 5) {
    print('⚠️ Dishes already seeded. Skipping.');
    return;
  }

  print('🍽️ Seeding Dishes and Ingredients...');
  
  // ========== INGREDIENTS MASTER ==========
  final ingredients = <Map<String, dynamic>>[
    // Rice & Grains
    {'name': 'Basmati Rice', 'category': 'Grains', 'subcategory': 'Rice', 'unit_of_measure': 'kg', 'cost_per_unit': 80},
    {'name': 'Sona Masoori Rice', 'category': 'Grains', 'subcategory': 'Rice', 'unit_of_measure': 'kg', 'cost_per_unit': 55},
    {'name': 'Idli Rice', 'category': 'Grains', 'subcategory': 'Rice', 'unit_of_measure': 'kg', 'cost_per_unit': 50},
    {'name': 'Wheat Flour (Atta)', 'category': 'Grains', 'subcategory': 'Flour', 'unit_of_measure': 'kg', 'cost_per_unit': 45},
    {'name': 'Maida', 'category': 'Grains', 'subcategory': 'Flour', 'unit_of_measure': 'kg', 'cost_per_unit': 40},
    {'name': 'Besan', 'category': 'Grains', 'subcategory': 'Flour', 'unit_of_measure': 'kg', 'cost_per_unit': 90},
    {'name': 'Semolina (Rava)', 'category': 'Grains', 'subcategory': 'Flour', 'unit_of_measure': 'kg', 'cost_per_unit': 50},
    
    // Dals & Lentils
    {'name': 'Toor Dal', 'category': 'Pulses', 'subcategory': 'Dal', 'unit_of_measure': 'kg', 'cost_per_unit': 140},
    {'name': 'Urad Dal', 'category': 'Pulses', 'subcategory': 'Dal', 'unit_of_measure': 'kg', 'cost_per_unit': 120},
    {'name': 'Chana Dal', 'category': 'Pulses', 'subcategory': 'Dal', 'unit_of_measure': 'kg', 'cost_per_unit': 100},
    {'name': 'Moong Dal', 'category': 'Pulses', 'subcategory': 'Dal', 'unit_of_measure': 'kg', 'cost_per_unit': 130},
    {'name': 'Rajma', 'category': 'Pulses', 'subcategory': 'Beans', 'unit_of_measure': 'kg', 'cost_per_unit': 150},
    {'name': 'Chole (Chickpeas)', 'category': 'Pulses', 'subcategory': 'Beans', 'unit_of_measure': 'kg', 'cost_per_unit': 100},
    
    // Vegetables
    {'name': 'Onion', 'category': 'Vegetables', 'subcategory': 'Root', 'unit_of_measure': 'kg', 'cost_per_unit': 40},
    {'name': 'Tomato', 'category': 'Vegetables', 'subcategory': 'Fresh', 'unit_of_measure': 'kg', 'cost_per_unit': 50},
    {'name': 'Potato', 'category': 'Vegetables', 'subcategory': 'Root', 'unit_of_measure': 'kg', 'cost_per_unit': 35},
    {'name': 'Green Chilli', 'category': 'Vegetables', 'subcategory': 'Fresh', 'unit_of_measure': 'kg', 'cost_per_unit': 80},
    {'name': 'Ginger', 'category': 'Vegetables', 'subcategory': 'Fresh', 'unit_of_measure': 'kg', 'cost_per_unit': 150},
    {'name': 'Garlic', 'category': 'Vegetables', 'subcategory': 'Fresh', 'unit_of_measure': 'kg', 'cost_per_unit': 200},
    {'name': 'Carrot', 'category': 'Vegetables', 'subcategory': 'Fresh', 'unit_of_measure': 'kg', 'cost_per_unit': 60},
    {'name': 'Beans', 'category': 'Vegetables', 'subcategory': 'Fresh', 'unit_of_measure': 'kg', 'cost_per_unit': 80},
    {'name': 'Cabbage', 'category': 'Vegetables', 'subcategory': 'Fresh', 'unit_of_measure': 'kg', 'cost_per_unit': 40},
    {'name': 'Capsicum', 'category': 'Vegetables', 'subcategory': 'Fresh', 'unit_of_measure': 'kg', 'cost_per_unit': 100},
    {'name': 'Cauliflower', 'category': 'Vegetables', 'subcategory': 'Fresh', 'unit_of_measure': 'kg', 'cost_per_unit': 50},
    {'name': 'Paneer', 'category': 'Dairy', 'subcategory': 'Cheese', 'unit_of_measure': 'kg', 'cost_per_unit': 350},
    {'name': 'Peas (Frozen)', 'category': 'Vegetables', 'subcategory': 'Frozen', 'unit_of_measure': 'kg', 'cost_per_unit': 120},
    
    // Spices
    {'name': 'Turmeric Powder', 'category': 'Spices', 'subcategory': 'Ground', 'unit_of_measure': 'kg', 'cost_per_unit': 200},
    {'name': 'Red Chilli Powder', 'category': 'Spices', 'subcategory': 'Ground', 'unit_of_measure': 'kg', 'cost_per_unit': 300},
    {'name': 'Coriander Powder', 'category': 'Spices', 'subcategory': 'Ground', 'unit_of_measure': 'kg', 'cost_per_unit': 250},
    {'name': 'Cumin Powder', 'category': 'Spices', 'subcategory': 'Ground', 'unit_of_measure': 'kg', 'cost_per_unit': 400},
    {'name': 'Garam Masala', 'category': 'Spices', 'subcategory': 'Blends', 'unit_of_measure': 'kg', 'cost_per_unit': 500},
    {'name': 'Mustard Seeds', 'category': 'Spices', 'subcategory': 'Whole', 'unit_of_measure': 'kg', 'cost_per_unit': 180},
    {'name': 'Cumin Seeds', 'category': 'Spices', 'subcategory': 'Whole', 'unit_of_measure': 'kg', 'cost_per_unit': 400},
    {'name': 'Curry Leaves', 'category': 'Spices', 'subcategory': 'Fresh', 'unit_of_measure': 'bunch', 'cost_per_unit': 10},
    {'name': 'Coriander Leaves', 'category': 'Spices', 'subcategory': 'Fresh', 'unit_of_measure': 'bunch', 'cost_per_unit': 15},
    {'name': 'Salt', 'category': 'Spices', 'subcategory': 'Basic', 'unit_of_measure': 'kg', 'cost_per_unit': 20},
    
    // Oils & Fats
    {'name': 'Vegetable Oil', 'category': 'Oil', 'subcategory': 'Cooking', 'unit_of_measure': 'litre', 'cost_per_unit': 150},
    {'name': 'Ghee', 'category': 'Oil', 'subcategory': 'Cooking', 'unit_of_measure': 'kg', 'cost_per_unit': 550},
    {'name': 'Coconut Oil', 'category': 'Oil', 'subcategory': 'Cooking', 'unit_of_measure': 'litre', 'cost_per_unit': 200},
    
    // Dairy
    {'name': 'Milk', 'category': 'Dairy', 'subcategory': 'Fresh', 'unit_of_measure': 'litre', 'cost_per_unit': 60},
    {'name': 'Curd', 'category': 'Dairy', 'subcategory': 'Fresh', 'unit_of_measure': 'kg', 'cost_per_unit': 80},
    {'name': 'Cream', 'category': 'Dairy', 'subcategory': 'Fresh', 'unit_of_measure': 'litre', 'cost_per_unit': 300},
    {'name': 'Butter', 'category': 'Dairy', 'subcategory': 'Fresh', 'unit_of_measure': 'kg', 'cost_per_unit': 500},
    
    // Non-Veg
    {'name': 'Chicken', 'category': 'Meat', 'subcategory': 'Poultry', 'unit_of_measure': 'kg', 'cost_per_unit': 220},
    {'name': 'Mutton', 'category': 'Meat', 'subcategory': 'Red Meat', 'unit_of_measure': 'kg', 'cost_per_unit': 700},
    {'name': 'Fish (Pomfret)', 'category': 'Seafood', 'subcategory': 'Fresh', 'unit_of_measure': 'kg', 'cost_per_unit': 500},
    {'name': 'Prawns', 'category': 'Seafood', 'subcategory': 'Fresh', 'unit_of_measure': 'kg', 'cost_per_unit': 600},
    {'name': 'Egg', 'category': 'Meat', 'subcategory': 'Poultry', 'unit_of_measure': 'pcs', 'cost_per_unit': 7},
    
    // Others
    {'name': 'Tamarind', 'category': 'Others', 'subcategory': 'Paste', 'unit_of_measure': 'kg', 'cost_per_unit': 150},
    {'name': 'Jaggery', 'category': 'Others', 'subcategory': 'Sweetener', 'unit_of_measure': 'kg', 'cost_per_unit': 80},
    {'name': 'Sugar', 'category': 'Others', 'subcategory': 'Sweetener', 'unit_of_measure': 'kg', 'cost_per_unit': 45},
    {'name': 'Coconut (Fresh)', 'category': 'Others', 'subcategory': 'Fresh', 'unit_of_measure': 'pcs', 'cost_per_unit': 40},
    {'name': 'Coconut Milk', 'category': 'Others', 'subcategory': 'Canned', 'unit_of_measure': 'litre', 'cost_per_unit': 200},
    {'name': 'Cashew', 'category': 'Dry Fruits', 'subcategory': 'Nuts', 'unit_of_measure': 'kg', 'cost_per_unit': 900},
    {'name': 'Almond', 'category': 'Dry Fruits', 'subcategory': 'Nuts', 'unit_of_measure': 'kg', 'cost_per_unit': 800},
    {'name': 'Raisins', 'category': 'Dry Fruits', 'subcategory': 'Dried', 'unit_of_measure': 'kg', 'cost_per_unit': 300},
  ];
  
  final ingIdMap = <String, int>{};
  for (final ing in ingredients) {
    final id = await database.insert('ingredients_master', {
      ...ing,
      'firmId': 'SEED',
      'isSystemPreloaded': 1,
      'isActive': 1,
      'createdAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    if (id > 0) ingIdMap[ing['name'] as String] = id;
  }
  print('✅ Seeded ${ingIdMap.length} ingredients.');

  // ========== DISH MASTER ==========
  final dishes = <Map<String, dynamic>>[
    // South Indian - Rice
    {'name': 'Sambar Rice', 'category': 'Rice', 'region': 'South Indian', 'base_pax': 1},
    {'name': 'Lemon Rice', 'category': 'Rice', 'region': 'South Indian', 'base_pax': 1},
    {'name': 'Curd Rice', 'category': 'Rice', 'region': 'South Indian', 'base_pax': 1},
    {'name': 'Tamarind Rice (Puliyodharai)', 'category': 'Rice', 'region': 'South Indian', 'base_pax': 1},
    {'name': 'Coconut Rice', 'category': 'Rice', 'region': 'South Indian', 'base_pax': 1},
    {'name': 'Ghee Rice', 'category': 'Rice', 'region': 'South Indian', 'base_pax': 1},
    {'name': 'Plain Rice', 'category': 'Rice', 'region': 'South Indian', 'base_pax': 1},
    
    // South Indian - Breakfast
    {'name': 'Idli', 'category': 'Breakfast', 'region': 'South Indian', 'base_pax': 1},
    {'name': 'Dosa', 'category': 'Breakfast', 'region': 'South Indian', 'base_pax': 1},
    {'name': 'Vada', 'category': 'Breakfast', 'region': 'South Indian', 'base_pax': 1},
    {'name': 'Pongal', 'category': 'Breakfast', 'region': 'South Indian', 'base_pax': 1},
    {'name': 'Upma', 'category': 'Breakfast', 'region': 'South Indian', 'base_pax': 1},
    {'name': 'Rava Kesari', 'category': 'Sweets', 'region': 'South Indian', 'base_pax': 1},
    
    // South Indian - Curries
    {'name': 'Sambar', 'category': 'Curry', 'region': 'South Indian', 'base_pax': 1},
    {'name': 'Rasam', 'category': 'Curry', 'region': 'South Indian', 'base_pax': 1},
    {'name': 'Avial', 'category': 'Curry', 'region': 'South Indian', 'base_pax': 1},
    {'name': 'Kootu', 'category': 'Curry', 'region': 'South Indian', 'base_pax': 1},
    {'name': 'Poriyal (Beans)', 'category': 'Curry', 'region': 'South Indian', 'base_pax': 1},
    {'name': 'Potato Roast', 'category': 'Curry', 'region': 'South Indian', 'base_pax': 1},
    {'name': 'Cabbage Poriyal', 'category': 'Curry', 'region': 'South Indian', 'base_pax': 1},
    
    // North Indian - Rice
    {'name': 'Jeera Rice', 'category': 'Rice', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Veg Biryani', 'category': 'Rice', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Chicken Biryani', 'category': 'Rice', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Mutton Biryani', 'category': 'Rice', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Pulao', 'category': 'Rice', 'region': 'North Indian', 'base_pax': 1},
    
    // North Indian - Breads
    {'name': 'Roti/Chapati', 'category': 'Bread', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Naan', 'category': 'Bread', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Paratha', 'category': 'Bread', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Puri', 'category': 'Bread', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Bhatura', 'category': 'Bread', 'region': 'North Indian', 'base_pax': 1},
    
    // North Indian - Curries (Veg)
    {'name': 'Paneer Butter Masala', 'category': 'Curry', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Palak Paneer', 'category': 'Curry', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Dal Makhani', 'category': 'Curry', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Dal Tadka', 'category': 'Curry', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Chole (Chana Masala)', 'category': 'Curry', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Rajma Masala', 'category': 'Curry', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Aloo Gobi', 'category': 'Curry', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Mixed Veg Curry', 'category': 'Curry', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Matar Paneer', 'category': 'Curry', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Kadai Paneer', 'category': 'Curry', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Malai Kofta', 'category': 'Curry', 'region': 'North Indian', 'base_pax': 1},
    
    // North Indian - Curries (Non-Veg)
    {'name': 'Butter Chicken', 'category': 'Curry', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Chicken Curry', 'category': 'Curry', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Kadai Chicken', 'category': 'Curry', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Mutton Rogan Josh', 'category': 'Curry', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Mutton Curry', 'category': 'Curry', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Fish Curry', 'category': 'Curry', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Egg Curry', 'category': 'Curry', 'region': 'North Indian', 'base_pax': 1},
    
    // Snacks & Starters
    {'name': 'Samosa', 'category': 'Snacks', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Pakoda/Bhajji', 'category': 'Snacks', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Paneer Tikka', 'category': 'Starters', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Chicken Tikka', 'category': 'Starters', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Gobi Manchurian', 'category': 'Starters', 'region': 'Indo-Chinese', 'base_pax': 1},
    {'name': 'Chilli Chicken', 'category': 'Starters', 'region': 'Indo-Chinese', 'base_pax': 1},
    {'name': 'Paneer 65', 'category': 'Starters', 'region': 'South Indian', 'base_pax': 1},
    {'name': 'Chicken 65', 'category': 'Starters', 'region': 'South Indian', 'base_pax': 1},
    
    // Sweets & Desserts
    {'name': 'Gulab Jamun', 'category': 'Sweets', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Rasgulla', 'category': 'Sweets', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Kheer (Rice Pudding)', 'category': 'Sweets', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Payasam', 'category': 'Sweets', 'region': 'South Indian', 'base_pax': 1},
    {'name': 'Jalebi', 'category': 'Sweets', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Ice Cream', 'category': 'Desserts', 'region': 'Western', 'base_pax': 1},
    
    // Accompaniments
    {'name': 'Raita', 'category': 'Accompaniments', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Papad', 'category': 'Accompaniments', 'region': 'Indian', 'base_pax': 1},
    {'name': 'Pickle', 'category': 'Accompaniments', 'region': 'Indian', 'base_pax': 1},
    {'name': 'Coconut Chutney', 'category': 'Accompaniments', 'region': 'South Indian', 'base_pax': 1},
    {'name': 'Tomato Chutney', 'category': 'Accompaniments', 'region': 'South Indian', 'base_pax': 1},
    {'name': 'Green Chutney', 'category': 'Accompaniments', 'region': 'North Indian', 'base_pax': 1},
    
    // Beverages
    {'name': 'Buttermilk (Chaas)', 'category': 'Beverages', 'region': 'Indian', 'base_pax': 1},
    {'name': 'Mango Lassi', 'category': 'Beverages', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Sweet Lassi', 'category': 'Beverages', 'region': 'North Indian', 'base_pax': 1},
    {'name': 'Filter Coffee', 'category': 'Beverages', 'region': 'South Indian', 'base_pax': 1},
    {'name': 'Masala Tea', 'category': 'Beverages', 'region': 'Indian', 'base_pax': 1},
  ];
  
  int dishCount = 0;
  for (final dish in dishes) {
    await database.insert('dish_master', {
      ...dish,
      'firmId': 'SEED',
      'createdAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    dishCount++;
  }
  print('✅ Seeded $dishCount dishes.');
  
  print('🎉 Dishes and Ingredients seeding complete!');
}
