// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tamil (`ta`).
class AppLocalizationsTa extends AppLocalizations {
  AppLocalizationsTa([String locale = 'ta']) : super(locale);

  @override
  String get appTitle => 'RuchiServ';

  @override
  String get signInContinue => 'Sign in to continue';

  @override
  String get firmId => 'Firm ID';

  @override
  String get enterFirmId => 'Enter firm ID';

  @override
  String get mobileNumber => 'Mobile Number';

  @override
  String get enterMobile => 'Enter mobile';

  @override
  String get password => 'Password';

  @override
  String get enterPassword => 'Enter password';

  @override
  String get loginButton => 'LOGIN';

  @override
  String get enableBiometricLogin => 'Enable Biometric Login';

  @override
  String get enableBiometricPrompt =>
      'Would you like to enable biometric authentication for faster login next time?';

  @override
  String get notNow => 'Not Now';

  @override
  String get enable => 'Enable';

  @override
  String get biometricEnabled => 'Biometric login enabled!';

  @override
  String failedEnableBiometric(String error) {
    return 'Failed to enable biometrics: $error';
  }

  @override
  String get biometricNotAllowed =>
      'Biometric login not allowed. Please login online once.';

  @override
  String biometricFailed(String error) {
    return 'Biometric failed: $error';
  }

  @override
  String get subscription => 'Subscription';

  @override
  String get subscriptionExpired =>
      'Your subscription has expired. Please renew to continue.';

  @override
  String subscriptionExpiresIn(int days) {
    return 'Your subscription expires in $days day(s). Please renew.';
  }

  @override
  String get ok => 'OK';

  @override
  String loginError(String error) {
    return 'Login error: $error';
  }

  @override
  String get register => 'Register';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get invalidCredentials => 'Invalid credentials.';

  @override
  String get offlineLoginNotAllowed =>
      'Offline login not allowed. Please connect to the internet.';

  @override
  String get mainMenuTitle => 'Menu';

  @override
  String get moduleOrders => 'Orders';

  @override
  String get moduleOperations => 'Operations';

  @override
  String get moduleInventory => 'Inventory';

  @override
  String get moduleFinance => 'Finance';

  @override
  String get moduleReports => 'Reports';

  @override
  String get moduleSettings => 'Settings';

  @override
  String get moduleAttendance => 'My Attendance';

  @override
  String get noModulesAvailable => 'No modules available';

  @override
  String get contactAdministrator => 'Contact your administrator';

  @override
  String get firmProfile => 'Firm Profile';

  @override
  String get viewUpdateFirm => 'View or update your firm details';

  @override
  String get userProfile => 'User Profile';

  @override
  String get manageLoginPrefs => 'Manage your login and preferences';

  @override
  String get manageUsers => 'Manage Users';

  @override
  String get manageUsersSubtitle => 'Add users and set permissions';

  @override
  String get authMobiles => 'Authorized Mobiles';

  @override
  String get authMobilesSubtitle => 'Manage pre-approved mobile numbers';

  @override
  String get paymentSettings => 'Payment Settings';

  @override
  String get paymentSettingsSubtitle => 'Configure payment gateways';

  @override
  String get generalSettings => 'General Settings';

  @override
  String get generalSettingsSubtitle => 'Theme, Notifications, Security';

  @override
  String get vehicleMaster => 'Vehicle Master';

  @override
  String get vehicleMasterSubtitle => 'Manage fleet vehicles';

  @override
  String get utensilMaster => 'Utensil Master';

  @override
  String get utensilMasterSubtitle => 'Manage utensils & consumables';

  @override
  String get backupAWS => 'Backup to AWS';

  @override
  String get backupSubtitle => 'Upload all data to cloud';

  @override
  String get auditLogs => 'Audit Logs';

  @override
  String get auditLogsSubtitle => 'View and export compliance logs';

  @override
  String get aboutApp => 'About RuchiServ';

  @override
  String get logout => 'Logout';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get attendanceTitle => 'My Attendance';

  @override
  String get noStaffRecord => 'No Staff Record Found';

  @override
  String get mobileNotLinked =>
      'Your mobile number is not linked to any staff record.\nPlease contact your administrator.';

  @override
  String get checkingLocation => 'Checking location...';

  @override
  String get punchIn => 'PUNCH IN';

  @override
  String get punchOut => 'PUNCH OUT';

  @override
  String get punching => 'Punching...';

  @override
  String get readyToPunchIn => 'Ready to Punch In';

  @override
  String workingSince(String time) {
    return 'Working since $time';
  }

  @override
  String get todayShiftCompleted => 'Today\'s Shift Completed';

  @override
  String elapsedTime(int hours, int minutes) {
    return '${hours}h ${minutes}m elapsed';
  }

  @override
  String get todayDetails => 'Today\'s Details';

  @override
  String get punchedIn => 'Punched In';

  @override
  String get punchedOut => 'Punched Out';

  @override
  String get location => 'Location';

  @override
  String get withinKitchen => 'Within Kitchen Area';

  @override
  String get outsideKitchen => 'Outside Kitchen Area';

  @override
  String get punchSuccess => '✅ Punched In Successfully!';

  @override
  String get punchWarning => '⚠️ Punched In (Outside Kitchen Area)';

  @override
  String punchOutSuccess(String hours) {
    return '✅ Punched Out - $hours hours';
  }

  @override
  String get refresh => 'Refresh';

  @override
  String get loading => 'Loading...';

  @override
  String get ordersCalendarTitle => 'Orders Calendar';

  @override
  String get openSystemCalendar => 'Open System Calendar';

  @override
  String get utilizationLow => 'Low (<50%)';

  @override
  String get utilizationMed => 'Med (50-90%)';

  @override
  String get utilizationHigh => 'High (>90%)';

  @override
  String get editOrder => 'Edit Order';

  @override
  String get addOrder => 'Add Order';

  @override
  String dateLabel(String date) {
    return 'Date';
  }

  @override
  String totalPax(int pax) {
    return 'Total Pax: $pax';
  }

  @override
  String get deliveryTime => 'Delivery Time';

  @override
  String get tapToSelectTime => 'Tap to select time';

  @override
  String get customerName => 'Customer Name';

  @override
  String get digitsOnly => 'Digits only';

  @override
  String get mobileLengthError => 'Must be exactly 10 digits';

  @override
  String get mealType => 'Meal Type';

  @override
  String get foodType => 'Food Type';

  @override
  String get menuItems => 'Menu Items';

  @override
  String get addItem => 'Add Item';

  @override
  String get subtotal => 'Subtotal (₹)';

  @override
  String get discPercent => 'Disc %';

  @override
  String get dishTotal => 'Dish Total:';

  @override
  String get serviceAndCounterSetup => 'Service & Counter Setup';

  @override
  String get serviceRequiredQuestion => 'Service Required?';

  @override
  String get serviceType => 'Service Type: ';

  @override
  String get countersCount => 'No. of Counters';

  @override
  String get ratePerStaff => 'Rate/Staff (₹)';

  @override
  String get staffRequired => 'Staff Required';

  @override
  String costWithRupee(String cost) {
    return 'Cost: ₹$cost';
  }

  @override
  String get counterSetupNeeded => 'Counter Setup Needed?';

  @override
  String get ratePerCounter => 'Rate/Counter (₹)';

  @override
  String counterCostWithRupee(String cost) {
    return 'Counter Cost: ₹$cost';
  }

  @override
  String discountWithPercent(String percent) {
    return 'Discount ($percent%):';
  }

  @override
  String get serviceCost => 'Service Cost:';

  @override
  String get counterSetup => 'Counter Setup:';

  @override
  String get grandTotal => 'GRAND TOTAL:';

  @override
  String get notes => 'Notes';

  @override
  String get saveOrder => 'SAVE ORDER';

  @override
  String get orderSaved => '✅ Order saved';

  @override
  String saveOrderError(String error) {
    return 'Error saving order: $error';
  }

  @override
  String get typeDishName => 'Type dish name';

  @override
  String get rate => 'Rate';

  @override
  String get qty => 'Qty';

  @override
  String get cost => 'Cost';

  @override
  String get required => 'Required';

  @override
  String get resetCalculation => 'Reset Calculation';

  @override
  String get breakfast => 'Breakfast';

  @override
  String get lunch => 'Lunch';

  @override
  String get dinner => 'Dinner';

  @override
  String get snacksOthers => 'Snacks/Others';

  @override
  String get veg => 'Veg';

  @override
  String get nonVeg => 'Non-Veg';

  @override
  String failedLoadOrders(String error) {
    return 'Failed to load orders: $error';
  }

  @override
  String errorLoadingOrders(String error) {
    return 'Error loading orders: $error';
  }

  @override
  String get cannotEditPastOrders => 'Cannot edit past orders.';

  @override
  String get cannotDeletePastOrders => 'Cannot delete past orders.';

  @override
  String get deleteOrderTitle => 'Delete Order?';

  @override
  String get deleteOrderConfirm =>
      'This will remove the order locally. (Will sync when online)';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get confirm => 'Confirm';

  @override
  String get requiredField => 'Required';

  @override
  String error(String error) {
    return 'Error: $error';
  }

  @override
  String get orderDeleted => 'Order deleted (will sync when online)';

  @override
  String errorDeletingOrder(String error) {
    return 'Error deleting order: $error';
  }

  @override
  String ordersCount(int count) {
    return '$count orders';
  }

  @override
  String get noLocation => 'No location';

  @override
  String get unnamed => 'Unnamed';

  @override
  String ordersDateTitle(String date) {
    return 'Orders - $date';
  }

  @override
  String get dishSummary => 'Dish Summary';

  @override
  String get retry => 'Retry';

  @override
  String get noOrdersFound => 'No orders found for this date';

  @override
  String vegCount(int count) {
    return 'Veg: $count';
  }

  @override
  String nonVegCount(int count) {
    return 'Non-Veg: $count';
  }

  @override
  String totalCount(int count) {
    return 'Total: $count';
  }

  @override
  String failedLoadSummary(String error) {
    return 'Failed to load summary: $error';
  }

  @override
  String errorLoadingSummary(String error) {
    return 'Error loading summary: $error';
  }

  @override
  String summaryDateTitle(String date) {
    return 'Summary - $date';
  }

  @override
  String get noDishesFound => 'No dishes found for this date';

  @override
  String get unnamedDish => 'Unnamed dish';

  @override
  String qtyWithCount(int count) {
    return 'Qty: $count';
  }

  @override
  String get kitchenView => 'Kitchen View';

  @override
  String get dispatchView => 'Dispatch View';

  @override
  String get punchInOut => 'Punch In/Out';

  @override
  String get staffManagement => 'Staff Management';

  @override
  String get adminOnly => 'Admin Only';

  @override
  String get restrictedToAdmins => '⛔ Staff Management is restricted to Admins';

  @override
  String get utensils => 'Utensils';

  @override
  String get kitchenOperations => 'Kitchen Operations';

  @override
  String get ordersView => 'Orders View';

  @override
  String get productionQueue => 'Production Queue';

  @override
  String get ready => 'Ready';

  @override
  String get other => 'Other';

  @override
  String get internalKitchen => 'Internal Kitchen';

  @override
  String get subcontract => 'Subcontract';

  @override
  String get liveCounter => 'Live Counter';

  @override
  String get prepIngredients => '🔥 PREP INGREDIENTS';

  @override
  String get live => 'LIVE';

  @override
  String get prep => 'Prep';

  @override
  String get start => 'Start';

  @override
  String get prepping => 'Prepping';

  @override
  String get inQueue => 'In Queue';

  @override
  String get assignEdit => 'Assign / Edit';

  @override
  String get productionSettings => 'Production Settings';

  @override
  String get noItemsInQueue => 'No items in production queue';

  @override
  String get done => 'Done';

  @override
  String get noRecipeDefined => 'No recipe defined for this dish';

  @override
  String get ingredientsRequired => '📋 Ingredients Required:';

  @override
  String get noReadyItems => 'No ready items';

  @override
  String get returnItem => 'Return';

  @override
  String paxLabel(int count) {
    return 'Pax: $count';
  }

  @override
  String locLabel(String location) {
    return 'Loc: $location';
  }

  @override
  String get na => 'N/A';

  @override
  String get noOrdersForDispatch => 'No orders available for dispatch today';

  @override
  String get createDispatch => 'Create Dispatch';

  @override
  String get dispatchDetails => 'Dispatch Details';

  @override
  String get driverName => 'Driver Name';

  @override
  String get vehicleNumber => 'Vehicle Number';

  @override
  String get noPendingDispatches => 'No pending dispatches yet!';

  @override
  String get tapToAddDispatch =>
      'Tap the \'+\' button to create a new dispatch.';

  @override
  String orderFor(String name) {
    return 'Order for: $name';
  }

  @override
  String driverWithVehicle(String driver, String vehicle) {
    return 'Driver: $driver ($vehicle)';
  }

  @override
  String get statusPending => 'Pending';

  @override
  String get statusDispatched => 'DISPATCHED';

  @override
  String get statusDelivered => 'DELIVERED';

  @override
  String failedUpdateStatus(String error) {
    return 'Failed to update status: $error';
  }

  @override
  String get payroll => 'Payroll';

  @override
  String get staff => 'Staff';

  @override
  String get today => 'Today';

  @override
  String get noStaffMembers => 'No staff members';

  @override
  String get tapToAddStaff => 'Tap + to add staff';

  @override
  String get unknown => 'Unknown';

  @override
  String get noMobile => 'No mobile';

  @override
  String get permanent => 'Permanent';

  @override
  String get dailyWage => 'Daily Wage';

  @override
  String get contractor => 'Contractor';

  @override
  String get alreadyPunchedIn => 'Already punched in today!';

  @override
  String get couldNotGetLocation => 'Could not get location';

  @override
  String get punchedInGeo => '✓ Punched In (Within Geo-fence)';

  @override
  String get punchedInNoGeo => '⚠️ Punched In (Outside Geo-fence)';

  @override
  String punchedOutMsg(String hours, String ot) {
    return 'Punched Out - $hours hrs$ot';
  }

  @override
  String get totalStaff => 'Total Staff';

  @override
  String get present => 'Present';

  @override
  String get absent => 'Absent';

  @override
  String get noAttendanceToday => 'No attendance records today';

  @override
  String get workingStatus => 'working';

  @override
  String get otLabel => 'OT';

  @override
  String get addStaff => 'Add Staff';

  @override
  String get staffDetails => 'Staff Details';

  @override
  String tapToPhoto(String action) {
    return 'Tap to $action photo';
  }

  @override
  String get basicInfo => 'Basic Information';

  @override
  String get fullName => 'Full Name *';

  @override
  String get roleDesignation => 'Role/Designation';

  @override
  String get staffType => 'Staff Type';

  @override
  String get email => 'Email';

  @override
  String get salaryRates => 'Salary & Rates';

  @override
  String get monthlySalary => 'Monthly Salary (₹)';

  @override
  String get payoutFrequency => 'Payout Frequency';

  @override
  String get dailyWageLabel => 'Daily Wage (₹)';

  @override
  String get hourlyRate => 'Hourly Rate (₹)';

  @override
  String get bankIdDetails => 'Bank & ID Details';

  @override
  String get bankName => 'Bank Name';

  @override
  String get accountNumber => 'Account Number';

  @override
  String get ifscCode => 'IFSC Code';

  @override
  String get aadharNumber => 'Aadhar Number';

  @override
  String get emergencyContact => 'Emergency Contact';

  @override
  String get contactName => 'Contact Name';

  @override
  String get contactNumber => 'Contact Number';

  @override
  String get address => 'Address';

  @override
  String get addStaffBtn => 'ADD STAFF';

  @override
  String get saveChanges => 'SAVE CHANGES';

  @override
  String get advances => 'Advances';

  @override
  String get attendance => 'Attendance';

  @override
  String get totalAdvances => 'Total Advances';

  @override
  String get pendingDeduction => 'Pending Deduction';

  @override
  String get addAdvance => 'Add Advance';

  @override
  String get noAdvances => 'No advances recorded';

  @override
  String get deducted => 'Deducted';

  @override
  String get pending => 'Pending';

  @override
  String reason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get deleteStaff => 'Delete Staff';

  @override
  String get deleteStaffConfirm =>
      'Are you sure you want to delete this staff member? This cannot be undone.';

  @override
  String get staffDeleted => 'Staff deleted';

  @override
  String get staffAdded => 'Staff added!';

  @override
  String get staffUpdated => 'Staff updated!';

  @override
  String get selectPhoto => 'Select Photo';

  @override
  String get camera => 'Camera';

  @override
  String get gallery => 'Gallery';

  @override
  String get photoSelectedWeb => 'Photo selected (Web Mode)';

  @override
  String get photoUpdated => 'Photo updated';

  @override
  String get amountRupee => 'Amount (₹)';

  @override
  String get staffPayroll => 'Staff Payroll';

  @override
  String get basePay => 'Base Pay';

  @override
  String get otPay => 'OT Pay';

  @override
  String get netPay => 'Net Pay';

  @override
  String get noStaffData => 'No staff data';

  @override
  String get processPayroll => 'Process Payroll';

  @override
  String processPayrollConfirm(String name, String date) {
    return 'Mark all pending advances as deducted for $name for $date?';
  }

  @override
  String payrollProcessed(String name) {
    return 'Payroll processed for $name';
  }

  @override
  String get advanceDeduction => 'Advance Deduction';

  @override
  String get netPayable => 'Net Payable';

  @override
  String get markAdvancesDeducted => 'Mark Advances Deducted';

  @override
  String otMultiplierInfo(String rate) {
    return 'OT Multiplier: ${rate}x | OT = hours > 8 × hourly rate × $rate';
  }

  @override
  String get utensilsTracking => 'Utensils Tracking';

  @override
  String get noUtensilsAdded => 'No utensils added yet';

  @override
  String get addFirstUtensil => 'Add First Utensil';

  @override
  String get addUtensil => 'Add Utensil';

  @override
  String get utensilName => 'Utensil Name';

  @override
  String get utensilNameHint => 'e.g., Plates, Spoons, Cups';

  @override
  String get totalStock => 'Total Stock';

  @override
  String get enterQuantity => 'Enter quantity';

  @override
  String get availableStock => 'Available Stock';

  @override
  String get enterUtensilName => 'Please enter utensil name';

  @override
  String get utensilAdded => '✅ Utensil added';

  @override
  String get utensilUpdated => '✅ Utensil updated';

  @override
  String get utensilDeleted => 'Utensil deleted';

  @override
  String editUtensil(String name) {
    return 'Edit: $name';
  }

  @override
  String get deleteUtensil => 'Delete Utensil?';

  @override
  String deleteUtensilConfirm(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get save => 'Save';

  @override
  String get add => 'Add';

  @override
  String availableCount(int available, int total) {
    return 'Available: $available / $total';
  }

  @override
  String issuedCount(int issued, String percent) {
    return 'Issued: $issued ($percent% utilized)';
  }

  @override
  String get inventoryHub => 'Inventory Hub';

  @override
  String get ingredients => 'Ingredients';

  @override
  String get masterList => 'Master List';

  @override
  String get bom => 'BOM';

  @override
  String get recipeMapping => 'Recipe Mapping';

  @override
  String get mrpRun => 'MRP Run';

  @override
  String get calculate => 'Calculate';

  @override
  String get purchaseOrders => 'Purchase Orders';

  @override
  String get purchaseOrderShort => 'PO';

  @override
  String get trackOrders => 'Track Orders';

  @override
  String get suppliers => 'Suppliers';

  @override
  String get vendors => 'Vendors';

  @override
  String get subcontractors => 'Subcontractors';

  @override
  String get kitchens => 'Kitchens';

  @override
  String get ingredientsMaster => 'Ingredients Master';

  @override
  String get ingredientName => 'Ingredient Name';

  @override
  String get skuBrandOptional => 'SKU / Brand Name (Optional)';

  @override
  String get costPerUnit => 'Cost per Unit (₹)';

  @override
  String get category => 'Category';

  @override
  String get unit => 'Unit';

  @override
  String get unitKg => 'Kilogram (kg)';

  @override
  String get unitG => 'Gram (g)';

  @override
  String get unitL => 'Liter';

  @override
  String get unitMl => 'Milliliter (ml)';

  @override
  String get unitNos => 'Numbers (nos)';

  @override
  String get unitBunch => 'Bunch';

  @override
  String get unitPcs => 'Pieces (pcs)';

  @override
  String get enterIngredientName => 'Enter ingredient name';

  @override
  String get ingredientAdded => '✅ Ingredient added';

  @override
  String get editIngredient => 'Edit Ingredient';

  @override
  String get ingredientUpdated => '✅ Ingredient updated';

  @override
  String get searchPlaceholder => 'Search...';

  @override
  String ingredientsCount(int count) {
    return '$count ingredients';
  }

  @override
  String categoriesCount(int count) {
    return '$count categories';
  }

  @override
  String get catAll => 'All';

  @override
  String get catVegetable => 'Vegetable';

  @override
  String get catMeat => 'Meat';

  @override
  String get catSeafood => 'Seafood';

  @override
  String get catSpice => 'Spice';

  @override
  String get catDairy => 'Dairy';

  @override
  String get catGrain => 'Grain';

  @override
  String get catOil => 'Oil';

  @override
  String get catBeverage => 'Beverage';

  @override
  String get catOther => 'Other';

  @override
  String get bomManagement => 'BOM Management';

  @override
  String get bomInfo =>
      'Define ingredients required for each dish at 100 pax standard';

  @override
  String get searchDishes => 'Search dishes...';

  @override
  String get addDishesHint => 'Add dishes in Menu Management first';

  @override
  String itemsCount(int count) {
    return '$count items';
  }

  @override
  String get quantity100Pax => 'Quantity for 100 pax';

  @override
  String get selectIngredient => 'Select Ingredient';

  @override
  String get selectIngredientHint => 'Select ingredient and enter quantity';

  @override
  String get allIngredientsAdded => 'All ingredients already added';

  @override
  String get quantityUpdated => '✅ Quantity updated';

  @override
  String get ingredientRemoved => 'Ingredient removed';

  @override
  String get pax100 => '100 PAX';

  @override
  String get noIngredientsAdded => 'No ingredients added';

  @override
  String get mrpRunScreenTitle => 'MRP Run';

  @override
  String get changeDate => 'Change Date';

  @override
  String get totalOrders => 'Total Orders';

  @override
  String get liveKitchen => 'Live Kitchen';

  @override
  String get subcontracted => 'Subcontracted';

  @override
  String get noOrdersForDate => 'No orders for selected date';

  @override
  String get selectDifferentDate => 'Select Different Date';

  @override
  String get runMrp => 'RUN MRP';

  @override
  String get calculating => 'Calculating...';

  @override
  String get noOrdersToProcess => 'No orders to process';

  @override
  String get venueNotSpecified => 'Venue not specified';

  @override
  String get selectSubcontractor => 'Select Subcontractor';

  @override
  String get liveKitchenChip => 'Live Kitchen';

  @override
  String get subcontractChip => 'Subcontract';

  @override
  String get mrpOutputTitle => 'MRP Output';

  @override
  String get noIngredientsCalculated => 'No ingredients calculated';

  @override
  String get checkBomDefined => 'Check if dishes have BOM defined';

  @override
  String get total => 'total';

  @override
  String get proceedToAllotment => 'PROCEED TO ALLOTMENT';

  @override
  String get allotmentTitle => 'Allotment';

  @override
  String get supplierAllotment => 'Supplier Allotment';

  @override
  String get summary => 'Summary';

  @override
  String get assignIngredientHint => 'Assign each ingredient to a supplier';

  @override
  String assignedStatus(int assigned, int total) {
    return '$assigned/$total assigned';
  }

  @override
  String get supplier => 'Supplier';

  @override
  String get generateAndSendPos => 'GENERATE & SEND POs';

  @override
  String posWillBeGenerated(int count) {
    return '$count POs will be generated';
  }

  @override
  String get noAllocationsMade => 'No allocations made yet';

  @override
  String get allocateIngredientsFirst =>
      'Allocate ingredients to suppliers first';

  @override
  String posGeneratedSuccess(int count) {
    return '✅ $count POs generated and sent';
  }

  @override
  String get catGrocery => 'Grocery';

  @override
  String get supplierMaster => 'Supplier Master';

  @override
  String get addSupplier => 'Add Supplier';

  @override
  String get editSupplier => 'Edit Supplier';

  @override
  String get nameRequired => 'Name *';

  @override
  String get mobile => 'Mobile';

  @override
  String get gstNumber => 'GST Number';

  @override
  String get bankDetails => 'Bank Details';

  @override
  String get enterSupplierName => 'Enter supplier name';

  @override
  String get supplierUpdated => '✅ Supplier updated';

  @override
  String get supplierAdded => '✅ Supplier added';

  @override
  String get noSuppliersAdded => 'No suppliers added';

  @override
  String get noPhone => 'No phone';

  @override
  String get subcontractorMaster => 'Subcontractor Master';

  @override
  String get editSubcontractor => 'Edit Subcontractor';

  @override
  String get addSubcontractor => 'Add Subcontractor';

  @override
  String get kitchenBusinessName => 'Kitchen/Business Name *';

  @override
  String get mobileRequired => 'Mobile *';

  @override
  String get specialization => 'Specialization';

  @override
  String get specializationHint => 'e.g., Biriyani, Chinese, Sweets';

  @override
  String get ratePerPax => 'Rate per Pax (₹)';

  @override
  String get enterNameMobile => 'Enter name and mobile';

  @override
  String get subcontractorUpdated => '✅ Subcontractor updated';

  @override
  String get subcontractorAdded => '✅ Subcontractor added';

  @override
  String get noSubcontractorsAdded => 'No subcontractors added';

  @override
  String get perPax => 'per pax';

  @override
  String get purchaseOrdersTitle => 'Purchase Orders';

  @override
  String get statusSent => 'SENT';

  @override
  String get statusViewed => 'VIEWED';

  @override
  String get statusAccepted => 'ACCEPTED';

  @override
  String purchaseOrdersCount(int count) {
    return '$count purchase orders';
  }

  @override
  String get noPurchaseOrders => 'No purchase orders';

  @override
  String get runMrpHint => 'Run MRP to generate POs';

  @override
  String get dispatchTitle => 'Dispatch';

  @override
  String get tabList => 'List';

  @override
  String get tabActive => 'Active';

  @override
  String get tabReturns => 'Returns';

  @override
  String get tabUnload => 'Unload';

  @override
  String noPendingOrdersDate(String date) {
    return 'No pending orders for $date';
  }

  @override
  String get noActiveDispatches => 'No active dispatches';

  @override
  String get noReturnTracking => 'No items for return tracking';

  @override
  String get noUnloadItems => 'No items ready for unload';

  @override
  String get startDispatch => 'Start Dispatch';

  @override
  String get waitingForKitchen => 'Waiting for Kitchen';

  @override
  String get track => 'Track';

  @override
  String get verify => 'Verify';

  @override
  String get trackReturn => 'Track Return';

  @override
  String get locationLabel => 'Location';

  @override
  String locationValues(double lat, double lng) {
    return 'Location: $lat, $lng';
  }

  @override
  String get tapToViewItems => 'Tap to view loaded items →';

  @override
  String get loadedItems => 'Loaded Items';

  @override
  String get noItemsRecorded => 'No items recorded';

  @override
  String get kitchenItems => '🍳 Kitchen Items';

  @override
  String get kitchenItemsSubtitle => 'Prepared in kitchen - tick when loaded';

  @override
  String get subcontractItems => '🏪 Subcontract Items';

  @override
  String get subcontractItemsSubtitle =>
      'Optional - may come directly to venue';

  @override
  String get liveCookingItems => '🔥 Live Cooking Items';

  @override
  String get liveCookingItemsSubtitle => 'Load ingredients for on-site cooking';

  @override
  String get selectVehicle => 'Select Vehicle';

  @override
  String get dispatchedMsg => 'Dispatched!';

  @override
  String dispatchError(Object error) {
    return 'Error: $error';
  }

  @override
  String get dispatchListTitle => 'Dispatch List';

  @override
  String inHouseReady(int ready, int total) {
    return '$ready/$total In-House Ready';
  }

  @override
  String get noInHouseItems => 'No in-house items';

  @override
  String get statusInProduction => 'In Production';

  @override
  String get statusReady => 'Ready';

  @override
  String dispatchCustomerTitle(String customer) {
    return 'Dispatch: $customer';
  }

  @override
  String get chooseVehicle => 'Choose vehicle';

  @override
  String get completeDispatchNotify => 'Complete Dispatch & Notify Customer';

  @override
  String get pleaseSelectVehicle => 'Please select a vehicle';

  @override
  String get savedMsg => 'Saved!';

  @override
  String get loadAllDishesFirst => 'Please load all dishes first';

  @override
  String get dispatchedNotifiedMsg => 'Dispatched! Customer notified.';

  @override
  String get utensilsEquipment => 'Utensils & Equipment';

  @override
  String returnTitle(String customer) {
    return 'Return: $customer';
  }

  @override
  String get returnVehicle => 'Return Vehicle';

  @override
  String get items => 'Items';

  @override
  String get noUtensilsReturn => 'No Utensils to return.';

  @override
  String get returnSaved => 'Return saved successfully!';

  @override
  String saveFailed(Object error) {
    return 'Save failed: $error';
  }

  @override
  String get completeReturn => 'Complete Return';

  @override
  String unloadTitle(String customer) {
    return 'Unload: $customer';
  }

  @override
  String get verifyItems => 'Verify Items';

  @override
  String get noUtensilsUnload => 'No Utensils to Unload.';

  @override
  String get closeOrder => 'Close Order';

  @override
  String get missingItems => 'Missing Items';

  @override
  String get acknowledgeClose => 'Acknowledge & Close';

  @override
  String get reasonMismatch => 'Reason for mismatch';

  @override
  String loadedQty(int qty) {
    return 'Loaded: $qty';
  }

  @override
  String get qtyLabel => 'Qty';

  @override
  String get reportsTitle => 'Reports';

  @override
  String get periodLabel => 'Period: ';

  @override
  String get day => 'Day';

  @override
  String get week => 'Week';

  @override
  String get month => 'Month';

  @override
  String get year => 'Year';

  @override
  String get orders => 'Orders';

  @override
  String get kitchen => 'Kitchen';

  @override
  String get dispatch => 'Dispatch';

  @override
  String get hr => 'HR';

  @override
  String get noDataSelectedPeriod => 'No data for selected period';

  @override
  String get revenue => 'Revenue';

  @override
  String get confirmed => 'Confirmed';

  @override
  String get completed => 'Completed';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get inProgress => 'In Progress';

  @override
  String get delivered => 'Delivered';

  @override
  String get inTransit => 'In Transit';

  @override
  String get totalDispatches => 'Dispatches';

  @override
  String get hours => 'Hours';

  @override
  String get overtime => 'OT';

  @override
  String get staffWithOt => 'Staff with OT';

  @override
  String get totalOt => 'Total OT';

  @override
  String get noOvertime => 'No overtime recorded';

  @override
  String get financeTitle => 'Finance';

  @override
  String get income => 'Income';

  @override
  String get expense => 'Expense';

  @override
  String get netBalance => 'Net Balance';

  @override
  String get transactions => 'Transactions';

  @override
  String get ledgers => 'Ledgers';

  @override
  String get export => 'Export';

  @override
  String get recentTransactions => 'Recent Transactions';

  @override
  String get noTransactionsFound => 'No transactions found';

  @override
  String get exportingReport => 'Exporting Finance Report... (Mock)';

  @override
  String get filterAll => 'All';

  @override
  String get deleteTransactionTitle => 'Delete Transaction?';

  @override
  String get deleteTransactionContent => 'This cannot be undone.';

  @override
  String get customers => 'Customers';

  @override
  String get comingSoon => 'Coming Soon';

  @override
  String get addIncome => 'Add Income';

  @override
  String get addExpense => 'Add Expense';

  @override
  String get amountLabel => 'Amount';

  @override
  String get categoryLabel => 'Category';

  @override
  String get paymentModeLabel => 'Payment Mode';

  @override
  String get descriptionLabel => 'Description / Notes';

  @override
  String get saveTransaction => 'Save Transaction';

  @override
  String get enterAmount => 'Enter amount';

  @override
  String get invalidAmount => 'Invalid amount';

  @override
  String get transactionSaved => 'Transaction Saved';

  @override
  String get collectPayment => 'Collect Payment';

  @override
  String get selectPaymentMethod => 'Select Payment Method';

  @override
  String get upiRazorpay => 'UPI (Razorpay)';

  @override
  String get cardRazorpay => 'Credit/Debit Card (Razorpay)';

  @override
  String get cash => 'Cash';

  @override
  String get paymentSuccessful => 'Payment Successful!';

  @override
  String paymentReceivedMsg(String amount, int orderId) {
    return 'Payment of $amount received for Order #$orderId';
  }

  @override
  String paymentFailed(Object error) {
    return 'Payment Failed: $error';
  }

  @override
  String get chooseSubscription => 'Choose Subscription Plan';

  @override
  String get selectStartPlan => 'Select Your Plan';

  @override
  String payBtn(String amount) {
    return 'Pay $amount';
  }

  @override
  String get subscriptionActivated => 'Subscription Activated!';

  @override
  String planActiveUntil(String date) {
    return 'Your plan is now active until $date.';
  }

  @override
  String get continueBtn => 'Continue';

  @override
  String get auditReportTitle => 'Audit Report';

  @override
  String get noLogsExport => 'No logs to export';

  @override
  String exportFailed(Object error) {
    return 'Export failed: $error';
  }

  @override
  String get startDate => 'Start Date';

  @override
  String get endDate => 'End Date';

  @override
  String get userIdLabel => 'User ID';

  @override
  String get tableLabel => 'Table';

  @override
  String get noAuditLogs => 'No audit logs found';

  @override
  String changedFields(String fields) {
    return 'Changed: $fields';
  }

  @override
  String beforeVal(String val) {
    return 'Before: $val';
  }

  @override
  String afterVal(String val) {
    return 'After: $val';
  }

  @override
  String get addIngredient => 'Add Ingredient';

  @override
  String get noIngredientsFound => 'No ingredients found';
}
