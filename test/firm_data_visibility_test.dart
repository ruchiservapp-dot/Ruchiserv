import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ruchiserv/db/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Set up sqflite_common_ffi
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper dbHelper;

  setUp(() async {
    // Mock path_provider
    const MethodChannel('plugins.flutter.io/path_provider')
      .setMockMethodCallHandler((MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return '.';
        }
        return null;
      });

    // Reset SharedPreferences
    SharedPreferences.setMockInitialValues({});
    
    // Initialize DatabaseHelper
    dbHelper = DatabaseHelper();
    // We need to ensure we are using an in-memory database for testing
    // However, DatabaseHelper is a singleton that typically uses a file path.
    // For this test, we might simply rely on the fact that we are running in a test environment
    // and hopefully manipulate the database directly if needed, or we might need to modify DatabaseHelper
    // to accept a database factory or path for testing. 
    //
    // Since we cannot easily inject dependency into the singleton without changing code,
    // we will start by initializing it which will create a DB file.
    // To keep it isolated, we should ideally use a different path, but since we are running locally
    // let's just proceed carefully or use the fact that sqflite_common_ffi supports in-memory if we pass null path?
    // The current DatabaseHelper implementation likely defines a specific path.
  });

  test('Verify Show Universal Data Logic', () async {
    // 1. Mock SharedPreferences
    SharedPreferences.setMockInitialValues({
      'last_firm': 'TEST_FIRM',
    });

    // 2. Initialize Database and Insert Mock Data
    // We'll access the database directly via the helper's internal getter if possible, 
    // or just assume standard init.
    final db = await dbHelper.database;
    
    // Clear existing tables to ensure clean state
    await db.delete('firms');
    await db.delete('ingredients_master');
    await db.delete('dish_master');
    await db.delete('recipe_detail');

    // Insert Firm
    await db.insert('firms', {
      'firmId': 'TEST_FIRM',
      'firmName': 'Test Firm',
      'showUniversalData': 1, // Default: ON
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });

    // Insert Ingredients
    // 1. Seed Data (Universal)
    await db.insert('ingredients_master', {
      'firmId': 'SEED',
      'name': 'Universal Salt',
      'category': 'Spice',
      'unit_of_measure': 'kg',
    });
    // 2. Firm Data
    await db.insert('ingredients_master', {
      'firmId': 'TEST_FIRM',
      'name': 'Firm Pepper',
      'category': 'Spice',
      'unit_of_measure': 'kg',
    });

    // --- TEST CASE 1: Show Universal Data = ON ---
    List<Map<String, dynamic>> ingredients = await dbHelper.getAllIngredients('TEST_FIRM');
    expect(ingredients.any((i) => i['name'] == 'Universal Salt'), true, reason: 'Universal data should be visible');
    expect(ingredients.any((i) => i['name'] == 'Firm Pepper'), true, reason: 'Firm data should be visible');

    // --- TEST CASE 2: Show Universal Data = OFF ---
    // Toggle the setting using the helper method
    await dbHelper.setFirmUniversalDataVisibility('TEST_FIRM', false);
    
    // Verify setting was updated
    bool isVisible = await dbHelper.getFirmUniversalDataVisibility('TEST_FIRM');
    expect(isVisible, false);

    // Fetch ingredients again
    ingredients = await dbHelper.getAllIngredients('TEST_FIRM');
    expect(ingredients.any((i) => i['name'] == 'Universal Salt'), false, reason: 'Universal data should be HIDDEN');
    expect(ingredients.any((i) => i['name'] == 'Firm Pepper'), true, reason: 'Firm data set MUST still be visible');
    
    
    // --- TEST CASE 3: Dish Suggestions ---
    // Insert Dishes
    await db.insert('dish_master', {
      'firmId': 'SEED',
      'name': 'Universal Pasta',
      'category': 'Main Course',
    });
    await db.insert('dish_master', {
      'firmId': 'TEST_FIRM',
      'name': 'Firm Pizza',
      'category': 'Main Course',
    });

    // Current State: OFF
    List<Map<String, dynamic>> dishes = await dbHelper.getDishSuggestions(null); // Fetch all
    expect(dishes.any((d) => d['name'] == 'Universal Pasta'), false, reason: 'Universal Dish should be hidden');
    expect(dishes.any((d) => d['name'] == 'Firm Pizza'), true, reason: 'Firm Dish should be visible');

    // Turn ON again
    await dbHelper.setFirmUniversalDataVisibility('TEST_FIRM', true);
    dishes = await dbHelper.getDishSuggestions(null);
    expect(dishes.any((d) => d['name'] == 'Universal Pasta'), true, reason: 'Universal Dish should be visible again');


    // --- TEST CASE 4: Recipe Resolution ---
    // Universal Recipe
    int uId = await db.insert('dish_master', {
      'firmId': 'SEED',
      'name': 'Burger',
      'category': 'Snack',
      'base_pax': 1
    });
    // Firm Recipe (Override)
    int fId = await db.insert('dish_master', {
      'firmId': 'TEST_FIRM',
      'name': 'Burger', // Same name
      'category': 'Snack',
      'base_pax': 1
    });

    // Currently ON: Should prefer Firm
    // But we need to check if logic respects the flag.
    // Actually the logic says:
    // CASE 1: showUniversal = ON. Query: name = ? AND (firmId = ? OR firmId = 'SEED'). Order by Firm First.
    // Result: Firm Burger.
    
    // CASE 2: showUniversal = OFF. Query: name = ? AND (firmId = ?). 
    // Result: Firm Burger.
    
    // To verify logic difference, we need a case where ONLY Universal exists.
    // Let's rely on 'Universal Pasta' which only exists in SEED.
    
    // Turn OFF
    await dbHelper.setFirmUniversalDataVisibility('TEST_FIRM', false);
    var recipe = await dbHelper.getRecipeForDishByName('Universal Pasta', 10);
    expect(recipe, isEmpty, reason: 'Should not find recipe for hidden universal dish');

    // Turn ON
    await dbHelper.setFirmUniversalDataVisibility('TEST_FIRM', true);
    // Note: We need recipe details for it to return anything, but checking if it queries is enough?
    // actually getRecipeForDishByName returns empty if dish not found OR invalid.
    // Let's assume emptiness implies not found.
    
    // To be sure, let's look at what getRecipeForDishByName returns. It returns List<Map>. 
    // If dish is found but no recipe details, it still might return empty list or maybe throw? 
    // The code: "if (dishMaster.isEmpty) return [];"
    // So if dish is filtered out, it returns empty.
    
    // If dish IS found (universal visible), it proceeds to query recipe_detail.
    // Since we haven't added recipe_detail, it will return empty list EITHER WAY.
    // So this specific test case is ambiguous unless we check side effects or add recipe detail.
    
    // Let's add recipe detail for Universal Pasta
    int pastaId = (await db.query('dish_master', where: "name='Universal Pasta'")).first['id'] as int;
    int saltId = (await db.query('ingredients_master', where: "name='Universal Salt'")).first['id'] as int;
    
    await db.insert('recipe_detail', {
      'dish_id': pastaId,
      'ing_id': saltId,
      'quantity_per_base_pax': 0.1
    });

    // NOW:
    // ON -> Should return valid list
    var pastaRecipe = await dbHelper.getRecipeForDishByName('Universal Pasta', 10);
    expect(pastaRecipe, isNotEmpty, reason: 'Should return recipe when Universal is ON');
    
    // OFF -> Should return empty
    await dbHelper.setFirmUniversalDataVisibility('TEST_FIRM', false);
    pastaRecipe = await dbHelper.getRecipeForDishByName('Universal Pasta', 10);
    expect(pastaRecipe, isEmpty, reason: 'Should return empty when Universal is OFF');

  });
}
