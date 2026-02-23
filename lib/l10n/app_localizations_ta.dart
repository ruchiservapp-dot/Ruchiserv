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
  String get signInContinue => 'தொடர உள்நுழையவும்';

  @override
  String get firmId => 'நிறுவன ஐடி';

  @override
  String get enterFirmId => 'நிறுவன ஐடியை உள்ளிடவும்';

  @override
  String get mobileNumber => 'மொபைல் எண்';

  @override
  String get enterMobile => 'மொபைல் எண்ணை உள்ளிடவும்';

  @override
  String get password => 'கடவுச்சொல்';

  @override
  String get enterPassword => 'கடவுச்சொல்லை உள்ளிடவும்';

  @override
  String get loginButton => 'உள்நுழை';

  @override
  String get enableBiometricLogin => 'பயோமெட்ரிக் உள்நுழைவை இயக்கு';

  @override
  String get enableBiometricPrompt =>
      'அடுத்த முறை விரைவாக உள்நுழைய பயோமெட்ரிக் அங்கீகாரத்தைப் பயன்படுத்த விரும்புகிறீர்களா?';

  @override
  String get notNow => 'இப்போது இல்லை';

  @override
  String get enable => 'இயக்கு';

  @override
  String get biometricEnabled => 'பயோமெட்ரிக் உள்நுழைவு இயக்கப்பட்டது!';

  @override
  String failedEnableBiometric(String error) {
    return 'பயோமெட்ரிக்கை இயக்குவதில் தோல்வி: $error';
  }

  @override
  String get biometricNotAllowed =>
      'பயோமெட்ரிக் உள்நுழைவு அனுமதிக்கப்படவில்லை. ஆன்லைனில் உள்நுழையவும்.';

  @override
  String biometricFailed(String error) {
    return 'பயோமெட்ரிக் தோல்வியடைந்தது: $error';
  }

  @override
  String get subscription => 'சந்தா';

  @override
  String get subscriptionExpired =>
      'உங்கள் சந்தா காலாவதியாகிவிட்டது. தொடர புதுப்பிக்கவும்.';

  @override
  String subscriptionExpiresIn(int days) {
    return 'உங்கள் சந்தா $days நாட்களில் காலாவதியாகிறது. தயவுசெய்து புதுப்பிக்கவும்.';
  }

  @override
  String get ok => 'சரி';

  @override
  String loginError(String error) {
    return 'உள்நுழைவு பிழை: $error';
  }

  @override
  String get register => 'பதிவு';

  @override
  String get forgotPassword => 'கடவுச்சொல் மறந்துவிட்டதா?';

  @override
  String get invalidCredentials => 'தவறான தகவல்கள்.';

  @override
  String get offlineLoginNotAllowed =>
      'ஆஃப்லைன் உள்நுழைவு அனுமதிக்கப்படவில்லை. இணையத்துடன் இணைக்கவும்.';

  @override
  String get mainMenuTitle => 'மெனு';

  @override
  String get moduleOrders => 'ஆர்டர்கள்';

  @override
  String get moduleOperations => 'செயல்பாடுகள்';

  @override
  String get moduleInventory => 'சரக்கு';

  @override
  String get moduleFinance => 'நிதி';

  @override
  String get moduleReports => 'அறிக்கைகள்';

  @override
  String get moduleSettings => 'அமைப்புகள்';

  @override
  String get moduleInsights => 'Insights';

  @override
  String get moduleAttendance => 'வருகை பதிவு';

  @override
  String get noModulesAvailable => 'தொகுதிகள் இல்லை';

  @override
  String get contactAdministrator => 'நிர்வாகியைத் தொடர்பு கொள்ளவும்';

  @override
  String get firmProfile => 'நிறுவன விவரம்';

  @override
  String get viewUpdateFirm => 'விவரங்களைப் பார்க்கவும்/புதுப்பிக்கவும்';

  @override
  String get userProfile => 'பயனர் விவரம்';

  @override
  String get manageLoginPrefs => 'உள்நுழைவு விருப்பங்களை நிர்வகிக்கவும்';

  @override
  String get manageUsers => 'பயனர்கள்';

  @override
  String get manageUsersSubtitle => 'பயனர்களைச் சேர்க்கவும்';

  @override
  String get authMobiles => 'அங்கீகரிக்கப்பட்ட எண்கள்';

  @override
  String get authMobilesSubtitle => 'மொபைல் எண்களை நிர்வகிக்கவும்';

  @override
  String get paymentSettings => 'கட்டண அமைப்புகள்';

  @override
  String get paymentSettingsSubtitle => 'கட்டண நுழைவாயில்கள்';

  @override
  String get generalSettings => 'பொது அமைப்புகள்';

  @override
  String get generalSettingsSubtitle => 'தீம், பாதுகாப்பு';

  @override
  String get vehicleMaster => 'வாகனங்கள்';

  @override
  String get vehicleMasterSubtitle => 'வாகனங்களை நிர்வகிக்கவும்';

  @override
  String get utensilMaster => 'பாத்திரங்கள்';

  @override
  String get utensilMasterSubtitle => 'பாத்திரங்களை நிர்வகிக்கவும்';

  @override
  String get backupAWS => 'AWS காப்புப் பிரதி';

  @override
  String get backupSubtitle => 'மேகக்கணிக்கு பதிவேற்றவும்';

  @override
  String get auditLogs => 'தணிக்கை பதிவுகள்';

  @override
  String get auditLogsSubtitle => 'இணக்கப் பதிவுகள்';

  @override
  String get aboutApp => 'பற்றி';

  @override
  String get logout => 'வெளியேறு';

  @override
  String get selectLanguage => 'மொழியைத் தேர்ந்தெடுக்கவும்';

  @override
  String get attendanceTitle => 'என் வருகை பதிவு';

  @override
  String get noStaffRecord => 'ஊழியர் பதிவு இல்லை';

  @override
  String get mobileNotLinked =>
      'உங்கள் மொபைல் எண் எந்த ஊழியர் பதிவுடனும் இணைக்கப்படவில்லை.\nநிர்வாகியைத் தொடர்பு கொள்ளவும்.';

  @override
  String get checkingLocation => 'இடத்தைச் சரிபார்க்கிறது...';

  @override
  String get punchIn => 'பஞ்ச் இன்';

  @override
  String get punchOut => 'பஞ்ச் அவுட்';

  @override
  String get punching => 'பதிவு செய்கிறது...';

  @override
  String get readyToPunchIn => 'பஞ்ச் இன் செய்யத் தயார்';

  @override
  String workingSince(String time) {
    return '$time முதல் வேலை செய்கிறீர்கள்';
  }

  @override
  String get todayShiftCompleted => 'இன்றைய ஷிப்ட் முடிந்தது';

  @override
  String elapsedTime(int hours, int minutes) {
    return '$hours மணி $minutes நிமிடம் முடிந்தது';
  }

  @override
  String get todayDetails => 'இன்றைய விவரங்கள்';

  @override
  String get punchedIn => 'பஞ்ச் இன் செய்யப்பட்டது';

  @override
  String get punchedOut => 'பஞ்ச் அவுட் செய்யப்பட்டது';

  @override
  String get location => 'இடம்';

  @override
  String get withinKitchen => 'சமையலறை எல்லைக்குள்';

  @override
  String get outsideKitchen => 'சமையலறைக்கு வெளியே';

  @override
  String get punchSuccess => '✅ வெற்றிகரமாக பஞ்ச் இன் செய்யப்பட்டது!';

  @override
  String get punchWarning => '⚠️ பஞ்ச் இன் செய்யப்பட்டது (சமையலறைக்கு வெளியே)';

  @override
  String punchOutSuccess(String hours) {
    return '✅ பஞ்ச் அவுட் செய்யப்பட்டது - $hours மணிநேரம்';
  }

  @override
  String get refresh => 'புதுப்பி';

  @override
  String get loading => 'ஏற்றுகிறது...';

  @override
  String get ordersCalendarTitle => 'ஆர்டர் காலண்டர்';

  @override
  String get openSystemCalendar => 'சிஸ்டம் காலண்டரைத் திற';

  @override
  String get utilizationLow => 'குறைவு (<50%)';

  @override
  String get utilizationMed => 'நடுத்தரம் (50-90%)';

  @override
  String get utilizationHigh => 'அதிகம் (>90%)';

  @override
  String get editOrder => 'ஆர்டரைத் திருத்து';

  @override
  String get addOrder => 'ஆர்டரைச் சேர்';

  @override
  String get viewOrder => 'View Order';

  @override
  String get viewOnlyMode => 'Viewing order details. Editing is not available.';

  @override
  String dateLabel(String date) {
    return 'தேதி';
  }

  @override
  String totalPax(int pax) {
    return 'மொத்த நபர்கள்: $pax';
  }

  @override
  String get deliveryTime => 'டெலிவரி நேரம்';

  @override
  String get tapToSelectTime => 'நேரத்தைத் தேர்ந்தெடுக்க தட்டவும்';

  @override
  String get customerName => 'வாடிக்கையாளர் பெயர்';

  @override
  String get digitsOnly => 'எண்கள் மட்டும்';

  @override
  String get mobileLengthError => 'சரியாக 10 இலக்கங்கள் இருக்க வேண்டும்';

  @override
  String get mealType => 'உணவு வகை';

  @override
  String get foodType => 'உணவு';

  @override
  String get menuItems => 'மெனு உருப்படிகள்';

  @override
  String get addItem => 'உருப்படியைச் சேர்';

  @override
  String get subtotal => 'மொத்தம் (₹)';

  @override
  String get discPercent => 'தள்ளுபடி %';

  @override
  String get dishTotal => 'உணவு மொத்தம்:';

  @override
  String get serviceAndCounterSetup => 'சேவை & கவுண்டர் அமைப்பு';

  @override
  String get serviceRequiredQuestion => 'சேவை தேவையா?';

  @override
  String get serviceType => 'சேவை வகை: ';

  @override
  String get countersCount => 'கவுண்டர்களின் எண்ணிக்கை';

  @override
  String get ratePerStaff => 'விலை/ஊழியர் (₹)';

  @override
  String get staffRequired => 'தேவையான ஊழியர்கள்';

  @override
  String costWithRupee(String cost) {
    return 'செலவு: ₹$cost';
  }

  @override
  String get counterSetupNeeded => 'கவுண்டர் அமைப்பு தேவையா?';

  @override
  String get ratePerCounter => 'விலை/கவுண்டர் (₹)';

  @override
  String counterCostWithRupee(String cost) {
    return 'கவுண்டர் செலவு: ₹$cost';
  }

  @override
  String discountWithPercent(String percent) {
    return 'தள்ளுபடி ($percent%):';
  }

  @override
  String get serviceCost => 'சேவை செலவு:';

  @override
  String get counterSetup => 'கவுண்டர் அமைப்பு:';

  @override
  String get grandTotal => 'மொத்த தொகை:';

  @override
  String get notes => 'குறிப்புகள்';

  @override
  String get saveOrder => 'ஆர்டரைச் சேமி';

  @override
  String get orderSaved => '✅ ஆர்டர் சேமிக்கப்பட்டது';

  @override
  String saveOrderError(String error) {
    return 'ஆர்டரைச் சேமிப்பதில் பிழை: $error';
  }

  @override
  String get typeDishName => 'உணவு பெயரை தட்டச்சு செய்க';

  @override
  String get rate => 'விலை';

  @override
  String get qty => 'எண்ணிக்கை';

  @override
  String get cost => 'செலவு';

  @override
  String get required => 'தேவை';

  @override
  String get resetCalculation => 'கணக்கீட்டை மீட்டமை';

  @override
  String get breakfast => 'காலை உணவு';

  @override
  String get lunch => 'மதிய உணவு';

  @override
  String get dinner => 'இரவு உணவு';

  @override
  String get snacksOthers => 'சிற்றுண்டி/மற்றவை';

  @override
  String get veg => 'சைவம்';

  @override
  String get nonVeg => 'அசைவம்';

  @override
  String failedLoadOrders(String error) {
    return 'ஆர்டர்களை ஏற்றுவதில் தோல்வி: $error';
  }

  @override
  String errorLoadingOrders(String error) {
    return 'பிழை: $error';
  }

  @override
  String get cannotEditPastOrders => 'கடந்த ஆர்டர்களைத் திருத்த முடியாது.';

  @override
  String get cannotDeletePastOrders => 'கடந்த ஆர்டர்களை நீக்க முடியாது.';

  @override
  String get deleteOrderTitle => 'ஆர்டரை நீக்கவா?';

  @override
  String get deleteOrderConfirm =>
      'இது உள்ளூர் பதிப்பை நீக்கும். (ஆன்லைனில் ஒத்திசைக்கப்படும்)';

  @override
  String get cancel => 'ரத்துசெய்';

  @override
  String get delete => 'நீக்கு';

  @override
  String get confirm => 'உறுதிசெய்';

  @override
  String get requiredField => 'தேவை';

  @override
  String error(String error) {
    return 'பிழை: $error';
  }

  @override
  String get orderDeleted => 'ஆர்டர் நீக்கப்பட்டது';

  @override
  String errorDeletingOrder(String error) {
    return 'நீக்குவதில் பிழை: $error';
  }

  @override
  String ordersCount(int count) {
    return '$count ஆர்டர்கள்';
  }

  @override
  String get noLocation => 'இடம் இல்லை';

  @override
  String get unnamed => 'பெயரிடப்படாத';

  @override
  String ordersDateTitle(String date) {
    return 'ஆர்டர்கள் - $date';
  }

  @override
  String get dishSummary => 'உணவுச் சுருக்கம்';

  @override
  String get retry => 'மீண்டும் முயற்சி';

  @override
  String get noOrdersFound => 'இந்தத் தேதியில் ஆர்டர்கள் இல்லை';

  @override
  String vegCount(int count) {
    return 'சைவம்: $count';
  }

  @override
  String nonVegCount(int count) {
    return 'அசைவம்: $count';
  }

  @override
  String totalCount(int count) {
    return 'மொத்தம்: $count';
  }

  @override
  String failedLoadSummary(String error) {
    return 'சுருக்கத்தை ஏற்றுவதில் தோல்வி: $error';
  }

  @override
  String errorLoadingSummary(String error) {
    return 'பிழை: $error';
  }

  @override
  String summaryDateTitle(String date) {
    return 'சுருக்கம் - $date';
  }

  @override
  String get noDishesFound => 'உணவுகள் எதுவும் இல்லை';

  @override
  String get unnamedDish => 'பெயரிடப்படாத உணவு';

  @override
  String qtyWithCount(int count) {
    return 'எண்ணிக்கை: $count';
  }

  @override
  String get kitchenView => 'சமையலறை';

  @override
  String get dispatchView => 'அனுப்புதல்';

  @override
  String get punchInOut => 'பஞ்ச் இன்/அவுட்';

  @override
  String get staffManagement => 'ஊழியர் மேலாண்மை';

  @override
  String get adminOnly => 'நிர்வாகி மட்டும்';

  @override
  String get restrictedToAdmins => '⛔ நிர்வாகிகளுக்கு மட்டும்';

  @override
  String get utensils => 'பாத்திரங்கள்';

  @override
  String get kitchenOperations => 'சமையலறை செயல்பாடுகள்';

  @override
  String get ordersView => 'ஆர்டர்கள்';

  @override
  String get productionQueue => 'உற்பத்தி வரிசை';

  @override
  String get ready => 'தயார்';

  @override
  String get other => 'மற்றவை';

  @override
  String get internalKitchen => 'உள் சமையலறை';

  @override
  String get subcontract => 'துணை ஒப்பந்தம்';

  @override
  String get liveCounter => 'லைவ் கவுண்டர்';

  @override
  String get prepIngredients => '🔥 பொருட்களை தயார் செய்';

  @override
  String get live => 'லைவ்';

  @override
  String get prep => 'தயாரிப்பு';

  @override
  String get start => 'தொடங்கு';

  @override
  String get prepping => 'தயாராகிறது';

  @override
  String get inQueue => 'வரிசையில்';

  @override
  String get assignEdit => 'ஒதுக்கு / திருத்து';

  @override
  String get productionSettings => 'உற்பத்தி அமைப்புகள்';

  @override
  String get noItemsInQueue => 'வரிசையில் உருப்படிகள் இல்லை';

  @override
  String get done => 'முடிந்தது';

  @override
  String get noRecipeDefined => 'செய்முறை இல்லை';

  @override
  String get ingredientsRequired => '📋 தேவையான பொருட்கள்:';

  @override
  String get noReadyItems => 'தயாரான உருப்படிகள் இல்லை';

  @override
  String get returnItem => 'திருப்பி அனுப்பு';

  @override
  String paxLabel(int count) {
    return 'நபர்கள்: $count';
  }

  @override
  String locLabel(String location) {
    return 'இடம்: $location';
  }

  @override
  String get na => 'N/A';

  @override
  String get noOrdersForDispatch => 'அனுப்ப ஆர்டர்கள் இல்லை';

  @override
  String get createDispatch => 'அனுப்புதலை உருவாக்கு';

  @override
  String get dispatchDetails => 'விவரங்கள்';

  @override
  String get driverName => 'ஓட்டுநர் பெயர்';

  @override
  String get vehicleNumber => 'வாகன எண்';

  @override
  String get noPendingDispatches => 'நிலுவையில் இல்லை!';

  @override
  String get tapToAddDispatch => '+ தட்டி சேர்க்கவும்.';

  @override
  String orderFor(String name) {
    return 'ஆர்டர்: $name';
  }

  @override
  String driverWithVehicle(String driver, String vehicle) {
    return 'ஓட்டுநர்: $driver ($vehicle)';
  }

  @override
  String get statusPending => 'நிலுவையில்';

  @override
  String get statusDispatched => 'அனுப்பப்பட்டது';

  @override
  String get statusDelivered => 'வழங்கப்பட்டது';

  @override
  String failedUpdateStatus(String error) {
    return 'தோல்வி: $error';
  }

  @override
  String get payroll => 'சம்பளம்';

  @override
  String get staff => 'ஊழியர்கள்';

  @override
  String get today => 'இன்று';

  @override
  String get noStaffMembers => 'ஊழியர்கள் இல்லை';

  @override
  String get tapToAddStaff => '+ தட்டி ஊழியரைச் சேர்';

  @override
  String get unknown => 'தெரியாத';

  @override
  String get noMobile => 'மொபைல் இல்லை';

  @override
  String get permanent => 'நிரந்தரம்';

  @override
  String get dailyWage => 'தினக்கூலி';

  @override
  String get contractor => 'ஒப்பந்தம்';

  @override
  String get alreadyPunchedIn => 'ஏற்கனவே பஞ்ச் இன் செய்துள்ளீர்கள்!';

  @override
  String get couldNotGetLocation => 'இடத்தைக் கண்டறிய முடியவில்லை';

  @override
  String get punchedInGeo => '✓ பஞ்ச் இன் (எல்லைக்குள்)';

  @override
  String get punchedInNoGeo => '⚠️ பஞ்ச் இன் (எல்லைக்கு வெளியே)';

  @override
  String punchedOutMsg(String hours, String ot) {
    return 'பஞ்ச் அவுட் - $hours மணி $ot';
  }

  @override
  String get totalStaff => 'மொத்த ஊழியர்கள்';

  @override
  String get present => 'வருகை';

  @override
  String get absent => 'வரவில்லை';

  @override
  String get noAttendanceToday => 'இன்று பதிவு இல்லை';

  @override
  String get workingStatus => 'வேலை செய்கிறார்';

  @override
  String get otLabel => 'OT';

  @override
  String get addStaff => 'ஊழியரைச் சேர்';

  @override
  String get staffDetails => 'ஊழியர் விவரங்கள்';

  @override
  String tapToPhoto(String action) {
    return 'புகைப்படம் $action தட்டவும்';
  }

  @override
  String get basicInfo => 'அடிப்படைத் தகவல்';

  @override
  String get fullName => 'முழுப் பெயர் *';

  @override
  String get roleDesignation => 'பதவி';

  @override
  String get staffType => 'வகை';

  @override
  String get email => 'மின்னஞ்சல்';

  @override
  String get salaryRates => 'சம்பள விகிதங்கள்';

  @override
  String get monthlySalary => 'மாதச் சம்பளம் (₹)';

  @override
  String get payoutFrequency => 'வழங்கும் முறை';

  @override
  String get dailyWageLabel => 'தினக்கூலி (₹)';

  @override
  String get hourlyRate => 'மணிநேர விகிதம் (₹)';

  @override
  String get bankIdDetails => 'வங்கி & அடையாள விவரங்கள்';

  @override
  String get bankName => 'வங்கி பெயர்';

  @override
  String get accountNumber => 'கணக்கு எண்';

  @override
  String get ifscCode => 'IFSC குறியீடு';

  @override
  String get aadharNumber => 'ஆதார் எண்';

  @override
  String get emergencyContact => 'அவசரத் தொடர்பு';

  @override
  String get contactName => 'பெயர்';

  @override
  String get contactNumber => 'எண்';

  @override
  String get address => 'முகவரி';

  @override
  String get addStaffBtn => 'சேர்';

  @override
  String get saveChanges => 'மாற்றங்களைச் சேமி';

  @override
  String get advances => 'முன்பணம்';

  @override
  String get attendance => 'வருகை';

  @override
  String get totalAdvances => 'மொத்த முன்பணம்';

  @override
  String get pendingDeduction => 'நிலுவை பிடித்தம்';

  @override
  String get addAdvance => 'முன்பணம் சேர்';

  @override
  String get noAdvances => 'முன்பணம் இல்லை';

  @override
  String get deducted => 'பிடிக்கப்பட்டது';

  @override
  String get pending => 'நிலுவையில்';

  @override
  String reason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get deleteStaff => 'ஊழியரை நீக்கு';

  @override
  String get deleteStaffConfirm => 'நிச்சயமாக நீக்கவா? இதை மாற்ற முடியாது.';

  @override
  String get staffDeleted => 'நீக்கப்பட்டது';

  @override
  String get staffAdded => 'சேர்க்கப்பட்டது!';

  @override
  String get staffUpdated => 'புதுப்பிக்கப்பட்டது!';

  @override
  String get selectPhoto => 'புகைப்படம் தேர்ந்தெடு';

  @override
  String get camera => 'கேமரா';

  @override
  String get gallery => 'கேலரி';

  @override
  String get photoSelectedWeb => 'புகைப்படம் தேர்ந்தெடுக்கப்பட்டது';

  @override
  String get photoUpdated => 'புதுப்பிக்கப்பட்டது';

  @override
  String get amountRupee => 'தொகை (₹)';

  @override
  String get staffPayroll => 'சம்பள பட்டியல்';

  @override
  String get basePay => 'அடிப்படை ஊதியம்';

  @override
  String get otPay => 'கூடுதல் நேர ஊதியம்';

  @override
  String get netPay => 'நிகர ஊதியம்';

  @override
  String get noStaffData => 'தரவு இல்லை';

  @override
  String get processPayroll => 'சம்பளம் கணக்கிடு';

  @override
  String processPayrollConfirm(String name, String date) {
    return '$name-க்கு முன்பணத்தைக் கழித்து விடவா ($date)?';
  }

  @override
  String payrollProcessed(String name) {
    return '$name-க்கு சம்பளம் கணக்கிடப்பட்டது';
  }

  @override
  String get advanceDeduction => 'முன்பணக் கழிவு';

  @override
  String get netPayable => 'செலுத்த வேண்டியது';

  @override
  String get markAdvancesDeducted => 'கழித்ததாகக் குறிக்கவும்';

  @override
  String otMultiplierInfo(String rate) {
    return 'OT பெருக்கி: ${rate}x | 8 மணிக்கு மேல்';
  }

  @override
  String get utensilsTracking => 'பாத்திரக் கண்காணிப்பு';

  @override
  String get noUtensilsAdded => 'பாத்திரங்கள் இல்லை';

  @override
  String get addFirstUtensil => 'முதல் பாத்திரத்தைச் சேர்';

  @override
  String get addUtensil => 'பாத்திரம் சேர்';

  @override
  String get utensilName => 'பாத்திரப் பெயர்';

  @override
  String get utensilNameHint => 'எ.கா. தட்டு, குவளை';

  @override
  String get totalStock => 'மொத்த இருப்பு';

  @override
  String get enterQuantity => 'எண்ணிக்கை';

  @override
  String get availableStock => 'கையிருப்பு';

  @override
  String get enterUtensilName => 'பெயர்';

  @override
  String get utensilAdded => '✅ சேர்க்கப்பட்டது';

  @override
  String get utensilUpdated => '✅ புதுப்பிக்கப்பட்டது';

  @override
  String get utensilDeleted => 'நீக்கப்பட்டது';

  @override
  String editUtensil(String name) {
    return 'திருத்து: $name';
  }

  @override
  String get deleteUtensil => 'நீக்கவா?';

  @override
  String deleteUtensilConfirm(String name) {
    return '\"$name\"-ஐ நீக்கவா?';
  }

  @override
  String get save => 'சேமி';

  @override
  String get add => 'சேர்';

  @override
  String availableCount(int available, int total) {
    return 'கிடைப்பது: $available / $total';
  }

  @override
  String issuedCount(int issued, String percent) {
    return 'வழங்கியது: $issued ($percent%)';
  }

  @override
  String get inventoryHub => 'சரக்கு மையம்';

  @override
  String get ingredients => 'பொருட்கள்';

  @override
  String get masterList => 'முதன்மை பட்டியல்';

  @override
  String get bom => 'BOM';

  @override
  String get recipeMapping => 'செய்முறை';

  @override
  String get mrpRun => 'MRP இயக்கம்';

  @override
  String get calculate => 'கணக்கிடு';

  @override
  String get purchaseOrders => 'கொள்முதல் ஆர்டர்கள்';

  @override
  String get purchaseOrderShort => 'PO';

  @override
  String get trackOrders => 'ஆர்டர்கள்';

  @override
  String get suppliers => 'விநியோகஸ்தர்கள்';

  @override
  String get vendors => 'வியாபாரிகள்';

  @override
  String get subcontractors => 'துணை ஒப்பந்தக்காரர்கள்';

  @override
  String get kitchens => 'சமையலறைகள்';

  @override
  String get ingredientsMaster => 'பொருட்கள் முதன்மை';

  @override
  String get ingredientName => 'பொருள் பெயர்';

  @override
  String get skuBrandOptional => 'SKU / பிராண்ட் (விருப்பத் தேர்வு)';

  @override
  String get costPerUnit => 'அலகு விலை (₹)';

  @override
  String get category => 'வகை';

  @override
  String get unit => 'அலகு';

  @override
  String get unitKg => 'கிலோ (kg)';

  @override
  String get unitG => 'கிராம் (g)';

  @override
  String get unitL => 'லிட்டர்';

  @override
  String get unitMl => 'மில்லி லிட்டர் (ml)';

  @override
  String get unitNos => 'எண்கள் (nos)';

  @override
  String get unitBunch => 'கட்டு';

  @override
  String get unitPcs => 'துண்டுகள் (pcs)';

  @override
  String get enterIngredientName => 'பெயரை உள்ளிடு';

  @override
  String get ingredientAdded => '✅ சேர்க்கப்பட்டது';

  @override
  String get editIngredient => 'திருத்து';

  @override
  String get ingredientUpdated => '✅ புதுப்பிக்கப்பட்டது';

  @override
  String get searchPlaceholder => 'தேடு...';

  @override
  String get noResultsFound => 'முடிவுகள் இல்லை';

  @override
  String ingredientsCount(int count) {
    return '$count பொருட்கள்';
  }

  @override
  String categoriesCount(int count) {
    return '$count வகைகள்';
  }

  @override
  String get catAll => 'எல்லாம்';

  @override
  String get catVegetable => 'காய்கறி';

  @override
  String get catMeat => 'இறைச்சி';

  @override
  String get catSeafood => 'கடல் உணவு';

  @override
  String get catSpice => 'மசாலா';

  @override
  String get catDairy => 'பால் பொருட்கள்';

  @override
  String get catGrain => 'தானியம்';

  @override
  String get catOil => 'எண்ணெய்';

  @override
  String get catBeverage => 'பானம்';

  @override
  String get catOther => 'மற்றவை';

  @override
  String get bomManagement => 'BOM நிர்வாகம்';

  @override
  String get bomInfo => '100 நபர்களுக்கு தேவையான பொருட்கள்';

  @override
  String get searchDishes => 'உணவுகளைத் தேடு...';

  @override
  String get addDishesHint => 'முதலில் மெனுவில் உணவுகளைச் சேர்க்கவும்';

  @override
  String itemsCount(int count) {
    return '$count உருப்படிகள்';
  }

  @override
  String get quantity100Pax => '100 நபர்களுக்கான அளவு';

  @override
  String get selectIngredient => 'பொருளைத் தேர்ந்தெடு';

  @override
  String get selectIngredientHint => 'தேர்ந்தெடுத்து அளவை உள்ளிடு';

  @override
  String get allIngredientsAdded => 'எல்லாம் சேர்க்கப்பட்டது';

  @override
  String get quantityUpdated => '✅ அளவு புதுப்பிக்கப்பட்டது';

  @override
  String get ingredientRemoved => 'நீக்கப்பட்டது';

  @override
  String get pax100 => '100 நபர்';

  @override
  String get noIngredientsAdded => 'பொருட்கள் இல்லை';

  @override
  String get mrpRunScreenTitle => 'MRP இயக்கம்';

  @override
  String get changeDate => 'தேதி மாற்று';

  @override
  String get totalOrders => 'மொத்த ஆர்டர்கள்';

  @override
  String get liveKitchen => 'லைவ் சமையலறை';

  @override
  String get subcontracted => 'ஒப்பந்தம்';

  @override
  String get noOrdersForDate => 'ஆர்டர்கள் இல்லை';

  @override
  String get selectDifferentDate => 'வேறொரு தேதியைத் தேர்ந்தெடு';

  @override
  String get runMrp => 'MRP இயக்கு';

  @override
  String get calculating => 'கணக்கிடுகிறது...';

  @override
  String get noOrdersToProcess => 'ஆர்டர்கள் இல்லை';

  @override
  String get venueNotSpecified => 'இடம் குறிக்கப்படவில்லை';

  @override
  String get selectSubcontractor => 'ஒப்பந்தக்காரரைத் தேர்ந்தெடு';

  @override
  String get liveKitchenChip => 'லைவ்';

  @override
  String get subcontractChip => 'ஒப்பந்தம்';

  @override
  String get orderLockedCannotModify =>
      'ஆர்டர் இறுதியானது/பூட்டப்பட்டது. மாற்ற இயலாது.';

  @override
  String get mrpOutputTitle => 'MRP வெளியீடு';

  @override
  String get noIngredientsCalculated => 'கணக்கிடப்படவில்லை';

  @override
  String get checkBomDefined => 'BOM உள்ளதா எனப் பார்';

  @override
  String get total => 'மொத்தம்';

  @override
  String get proceedToAllotment => 'ஒதுக்கீட்டிற்குச் செல்';

  @override
  String get allotmentTitle => 'ஒதுக்கீடு';

  @override
  String get supplierAllotment => 'விநியோகஸ்தர் ஒதுக்கீடு';

  @override
  String get summary => 'சுருக்கம்';

  @override
  String get assignIngredientHint => 'விநியோகஸ்தர்களுக்கு ஒதுக்கவும்';

  @override
  String assignedStatus(int assigned, int total) {
    return '$assigned/$total ஒதுக்கப்பட்டது';
  }

  @override
  String get supplier => 'விநியோகஸ்தர்';

  @override
  String get generateAndSendPos => 'PO உருவாக்கி அனுப்பு';

  @override
  String posWillBeGenerated(int count) {
    return '$count PO உருவாக்கப்படும்';
  }

  @override
  String get noAllocationsMade => 'ஒதுக்கீடுகள் இல்லை';

  @override
  String get allocateIngredientsFirst => 'முதலில் ஒதுக்கீடு செய்';

  @override
  String posGeneratedSuccess(int count) {
    return '✅ $count PO உருவாக்கப்பட்டது';
  }

  @override
  String get catGrocery => 'மளிகை';

  @override
  String get supplierMaster => 'விநியோகஸ்தர்கள்';

  @override
  String get addSupplier => 'விநியோகஸ்தரைச் சேர்';

  @override
  String get editSupplier => 'திருத்து';

  @override
  String get nameRequired => 'பெயர் *';

  @override
  String get mobile => 'மொபைல்';

  @override
  String get gstNumber => 'GST எண்';

  @override
  String get bankDetails => 'வங்கி விவரங்கள்';

  @override
  String get enterSupplierName => 'பெயரை உள்ளிடு';

  @override
  String get supplierUpdated => '✅ புதுப்பிக்கப்பட்டது';

  @override
  String get supplierAdded => '✅ சேர்க்கப்பட்டது';

  @override
  String get noSuppliersAdded => 'விநியோகஸ்தர்கள் இல்லை';

  @override
  String get noPhone => 'போன் இல்லை';

  @override
  String get subcontractorMaster => 'துணை ஒப்பந்தக்காரர்கள்';

  @override
  String get editSubcontractor => 'திருத்து';

  @override
  String get addSubcontractor => 'சேர்';

  @override
  String get kitchenBusinessName => 'பெயர் *';

  @override
  String get mobileRequired => 'மொபைல் *';

  @override
  String get specialization => 'சிறப்பு';

  @override
  String get specializationHint => 'எ.கா. பிரியாணி';

  @override
  String get ratePerPax => 'விலை (ஒரு நபர் - ₹)';

  @override
  String get enterNameMobile => 'பெயர் மற்றும் எண்';

  @override
  String get subcontractorUpdated => '✅ புதுப்பிக்கப்பட்டது';

  @override
  String get subcontractorAdded => '✅ சேர்க்கப்பட்டது';

  @override
  String get noSubcontractorsAdded => 'யாரும் இல்லை';

  @override
  String get perPax => 'ஒரு நபர்';

  @override
  String get purchaseOrdersTitle => 'கொள்முதல் ஆர்டர்கள்';

  @override
  String get statusSent => 'அனுப்பப்பட்டது';

  @override
  String get statusViewed => 'பார்க்கப்பட்டது';

  @override
  String get statusAccepted => 'ஏற்கப்பட்டது';

  @override
  String purchaseOrdersCount(int count) {
    return '$count கொள்முதல் ஆர்டர்கள்';
  }

  @override
  String get noPurchaseOrders => 'இல்லை';

  @override
  String get runMrpHint => 'PO பெற MRP இயக்கு';

  @override
  String get dispatchTitle => 'அனுப்புதல்';

  @override
  String get tabList => 'பட்டியல்';

  @override
  String get tabActive => 'செயலில்';

  @override
  String get tabReturns => 'திரும்பியவை';

  @override
  String get tabUnload => 'இறக்குதல்';

  @override
  String noPendingOrdersDate(String date) {
    return 'நிலுவை ஆர்டர்கள் இல்லை';
  }

  @override
  String get noActiveDispatches => 'செயலில் இல்லை';

  @override
  String get noReturnTracking => 'இல்லை';

  @override
  String get noUnloadItems => 'இறக்க எதுவுமில்லை';

  @override
  String get upgradeToEnterprise => 'Upgrade to Enterprise for this feature';

  @override
  String get startDispatch => 'தொடங்கு';

  @override
  String get waitingForKitchen => 'சமையலறைக்காகக் காத்திருப்பு';

  @override
  String get track => 'கண்காணி';

  @override
  String get verify => 'சரிபார்';

  @override
  String get trackReturn => 'Track Return';

  @override
  String get locationLabel => 'Location';

  @override
  String locationValues(double lat, double lng) {
    return 'Location: $lat, $lng';
  }

  @override
  String get tapToViewItems => 'Tap to view loaded items ->';

  @override
  String get loadedItems => 'Loaded Items';

  @override
  String get noItemsRecorded => 'No items recorded';

  @override
  String get kitchenItems => 'Kitchen Items';

  @override
  String get kitchenItemsSubtitle => 'Prepared in kitchen';

  @override
  String get subcontractItems => 'Subcontract Items';

  @override
  String get subcontractItemsSubtitle => 'Direct to venue';

  @override
  String get liveCookingItems => 'Live Cooking Items';

  @override
  String get liveCookingItemsSubtitle => 'On-site cooking';

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
  String get qtyLabel => 'எண்ணிக்கை';

  @override
  String get reportsTitle => 'அறிக்கைகள்';

  @override
  String get periodLabel => 'காலம்: ';

  @override
  String get day => 'நாள்';

  @override
  String get week => 'வாரம்';

  @override
  String get month => 'மாதம்';

  @override
  String get year => 'வருடம்';

  @override
  String get orders => 'ஆர்டர்கள்';

  @override
  String get kitchen => 'சமையலறை';

  @override
  String get dispatch => 'அனுப்புதல்';

  @override
  String get hr => 'ஊழியர் வளம்';

  @override
  String get noDataSelectedPeriod => 'தேர்ந்தெடுத்த காலத்தில் தரவு இல்லை';

  @override
  String get revenue => 'வருவாய்';

  @override
  String get confirmed => 'உறுதி செய்யப்பட்டது';

  @override
  String get completed => 'முடிந்தது';

  @override
  String get cancelled => 'ரத்து செய்யப்பட்டது';

  @override
  String get inProgress => 'செயல்பாட்டில்';

  @override
  String get delivered => 'வழங்கப்பட்டது';

  @override
  String get inTransit => 'வழியில்';

  @override
  String get totalDispatches => 'மொத்த அனுப்புதல்கள்';

  @override
  String get hours => 'மணிநேரம்';

  @override
  String get overtime => 'கூடுதல் நேரம்';

  @override
  String get staffWithOt => 'கூடுதல் நேரம் செய்தவர்கள்';

  @override
  String get totalOt => 'மொத்த கூடுதல் நேரம்';

  @override
  String get noOvertime => 'கூடுதல் நேரம் இல்லை';

  @override
  String get financeTitle => 'நிதி';

  @override
  String get income => 'வருமானம்';

  @override
  String get expense => 'செலவு';

  @override
  String get netBalance => 'நிகர இருப்பு';

  @override
  String get transactions => 'பரிவர்த்தனைகள்';

  @override
  String get ledgers => 'கணக்கேடுகள்';

  @override
  String get export => 'ஏற்றுமதி';

  @override
  String get recentTransactions => 'சமீபத்திய பரிவர்த்தனைகள்';

  @override
  String get noTransactionsFound => 'பரிவர்த்தனைகள் இல்லை';

  @override
  String get exportingReport => 'ஏற்றுமதி செய்கிறது...';

  @override
  String get filterAll => 'எல்லாம்';

  @override
  String get deleteTransactionTitle => 'நீக்கவா?';

  @override
  String get deleteTransactionContent => 'இதை மாற்ற முடியாது.';

  @override
  String get customers => 'வாடிக்கையாளர்கள்';

  @override
  String get comingSoon => 'விரைவில்';

  @override
  String get addIncome => 'வருமானம் சேர்';

  @override
  String get addExpense => 'செலவு சேர்';

  @override
  String get amountLabel => 'தொகை';

  @override
  String get categoryLabel => 'வகை';

  @override
  String get paymentModeLabel => 'கட்டண முறை';

  @override
  String get descriptionLabel => 'விளக்கம் / குறிப்புகள்';

  @override
  String get saveTransaction => 'சேமி';

  @override
  String get enterAmount => 'தொகையை உள்ளிடு';

  @override
  String get invalidAmount => 'தவறான தொகை';

  @override
  String get transactionSaved => 'பரிவர்த்தனை சேமிக்கப்பட்டது';

  @override
  String get collectPayment => 'கட்டணம் பெறு';

  @override
  String get selectPaymentMethod => 'முறையைத் தேர்ந்தெடு';

  @override
  String get upiRazorpay => 'UPI (Razorpay)';

  @override
  String get cardRazorpay => 'Card (Razorpay)';

  @override
  String get cash => 'Cash';

  @override
  String get paymentSuccessful => 'கட்டணம் வெற்றி!';

  @override
  String paymentReceivedMsg(String amount, int orderId) {
    return '₹$amount பெறப்பட்டது (ஆர்டர் #$orderId)';
  }

  @override
  String paymentFailed(Object error) {
    return 'தோல்வி: $error';
  }

  @override
  String get chooseSubscription => 'சந்தா திட்டத்தைத் தேர்ந்தெடு';

  @override
  String get selectStartPlan => 'திட்டத்தைத் தேர்ந்தெடு';

  @override
  String payBtn(String amount) {
    return 'செலுத்து ₹$amount';
  }

  @override
  String get subscriptionActivated => 'சந்தா செயல்படுத்தப்பட்டது!';

  @override
  String planActiveUntil(String date) {
    return '$date வரை செயலில் இருக்கும்.';
  }

  @override
  String get continueBtn => 'தொடர்';

  @override
  String get auditReportTitle => 'தணிக்கை அறிக்கை';

  @override
  String get noLogsExport => 'ஏற்றுமதி செய்ய பதிவுகள் இல்லை';

  @override
  String exportFailed(Object error) {
    return 'தோல்வி: $error';
  }

  @override
  String get startDate => 'தொடக்க தேதி';

  @override
  String get endDate => 'முடிவு தேதி';

  @override
  String get userIdLabel => 'பயனர் ஐடி';

  @override
  String get tableLabel => 'அட்டவணை';

  @override
  String get noAuditLogs => 'பதிவுகள் இல்லை';

  @override
  String changedFields(String fields) {
    return 'மாற்றம்: $fields';
  }

  @override
  String beforeVal(String val) {
    return 'முன்: $val';
  }

  @override
  String afterVal(String val) {
    return 'பின்: $val';
  }

  @override
  String get addIngredient => 'Add Ingredient';

  @override
  String get noIngredientsFound => 'No ingredients found';

  @override
  String get totalHours => 'Total Hours';

  @override
  String get history => 'History';

  @override
  String get profile => 'Profile';

  @override
  String get orderDetails => 'Order Details';

  @override
  String get unlockToEdit => 'Unlock to Edit';

  @override
  String get editModeActive => 'Edit Mode Active';

  @override
  String get editModeEnabled =>
      'Edit mode enabled! You can now modify the order.';

  @override
  String get adminPasswordRequired =>
      'Admin authentication required to modify locked orders.';

  @override
  String get incorrectPassword => 'Incorrect password. Please try again.';

  @override
  String get unlock => 'Unlock';

  @override
  String get rerunMRPTitle => 'Re-run MRP Required';

  @override
  String get rerunMRPMessage =>
      'Saving changes to this order will require re-running MRP. This will:';

  @override
  String get cancelOldPOs => 'Cancel all existing Purchase Orders';

  @override
  String get notifySuppliers => 'Notify suppliers about cancellation';

  @override
  String get notifyCustomer => 'Notify customer about order changes';

  @override
  String get generateNewPOs =>
      'Generate new Purchase Orders after next MRP run';

  @override
  String get rerunMRP => 'Re-run MRP';

  @override
  String get saveAndRerunMRP => 'Save & Re-run MRP';

  @override
  String get orderUpdatedRerunMRP =>
      'Order updated! Please run MRP again to generate new POs.';

  @override
  String get poSentStatus => 'Purchase Orders Sent';

  @override
  String get mrpProcessedStatus => 'MRP Processed - Locked';

  @override
  String get pendingStatus => 'Pending MRP';

  @override
  String get editModeActiveMessage =>
      'Edit mode active - changes will require MRP re-run';

  @override
  String get orderInformation => 'Order Information';

  @override
  String get date => 'Date';

  @override
  String get dishes => 'Dishes';

  @override
  String get noDishes => 'No dishes in this order';

  @override
  String get pricingSummary => 'Pricing Summary';

  @override
  String get counterSetupCost => 'Counter Setup';

  @override
  String get addDish => 'Add Dish';

  @override
  String get dishName => 'Dish Name';

  @override
  String get region => 'Region';

  @override
  String get enterDishName => 'Please enter dish name';

  @override
  String get dishAdded => '✅ Dish added';
}
