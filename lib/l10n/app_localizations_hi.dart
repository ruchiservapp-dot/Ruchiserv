// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'RuchiServ';

  @override
  String get signInContinue => 'जारी रखने के लिए साइन इन करें';

  @override
  String get firmId => 'फर्म आईडी';

  @override
  String get enterFirmId => 'फर्म आईडी दर्ज करें';

  @override
  String get mobileNumber => 'मोबाइल नंबर';

  @override
  String get enterMobile => 'मोबाइल नंबर दर्ज करें';

  @override
  String get password => 'पासवर्ड';

  @override
  String get enterPassword => 'पासवर्ड दर्ज करें';

  @override
  String get loginButton => 'लॉगिन';

  @override
  String get enableBiometricLogin => 'बायोमेट्रिक लॉगिन सक्षम करें';

  @override
  String get enableBiometricPrompt =>
      'क्या आप अगली बार तेज़ लॉगिन के लिए बायोमेट्रिक प्रमाणीकरण सक्षम करना चाहेंगे?';

  @override
  String get notNow => 'अभी नहीं';

  @override
  String get enable => 'सक्षम करें';

  @override
  String get biometricEnabled => 'बायोमेट्रिक लॉगिन सक्षम!';

  @override
  String failedEnableBiometric(String error) {
    return 'बायोमेट्रिक्स सक्षम करने में विफल: $error';
  }

  @override
  String get biometricNotAllowed =>
      'बायोमेट्रिक लॉगिन की अनुमति नहीं है। कृपया ऑनलाइन लॉगिन करें।';

  @override
  String biometricFailed(String error) {
    return 'बायोमेट्रिक विफल: $error';
  }

  @override
  String get subscription => 'सदस्यता';

  @override
  String get subscriptionExpired =>
      'आपकी सदस्यता समाप्त हो गई है। जारी रखने के लिए कृपया नवीनीकृत करें।';

  @override
  String subscriptionExpiresIn(int days) {
    return 'किरप्या नवीनीकृत करें। आपकी सदस्यता $days दिन(नों) में समाप्त हो जाएगी।';
  }

  @override
  String get ok => 'ठीक है';

  @override
  String loginError(String error) {
    return 'लॉगिन त्रुटि: $error';
  }

  @override
  String get register => 'रजिस्टर';

  @override
  String get forgotPassword => 'पासवर्ड भूल गए?';

  @override
  String get invalidCredentials => 'अमान्य क्रेडेंशियल्स।';

  @override
  String get offlineLoginNotAllowed =>
      'ऑफ़लाइन लॉगिन की अनुमति नहीं है। कृपया इंटरनेट से कनेक्ट करें।';

  @override
  String get mainMenuTitle => 'मेनू';

  @override
  String get moduleOrders => 'ऑर्डर';

  @override
  String get moduleOperations => 'संचालन';

  @override
  String get moduleInventory => 'इन्वेंट्री';

  @override
  String get moduleFinance => 'वित्त';

  @override
  String get moduleReports => 'रिपोर्ट';

  @override
  String get moduleSettings => 'सेटिंग्स';

  @override
  String get moduleInsights => 'Insights';

  @override
  String get moduleAttendance => 'मेरी उपस्थिति';

  @override
  String get noModulesAvailable => 'कोई मॉड्यूल उपलब्ध नहीं';

  @override
  String get contactAdministrator => 'प्रशासक से संपर्क करें';

  @override
  String get firmProfile => 'फर्म प्रोफाइल';

  @override
  String get viewUpdateFirm => 'विवरण देखें या अपडेट करें';

  @override
  String get userProfile => 'उपयोगकर्ता प्रोफाइल';

  @override
  String get manageLoginPrefs => 'लॉगिन प्राथमिकताएं प्रबंधित करें';

  @override
  String get manageUsers => 'उपयोगकर्ता प्रबंधित करें';

  @override
  String get manageUsersSubtitle => 'उपयोगकर्ता जोड़ें और अनुमतियां सेट करें';

  @override
  String get authMobiles => 'अधिकृत मोबाइल';

  @override
  String get authMobilesSubtitle => 'मोबाइल नंबर प्रबंधित करें';

  @override
  String get paymentSettings => 'भुगतान सेटिंग्स';

  @override
  String get paymentSettingsSubtitle => 'गेटवे कॉन्फ़िगर करें';

  @override
  String get generalSettings => 'सामान्य सेटिंग्स';

  @override
  String get generalSettingsSubtitle => 'थीम, सूचनाएं, सुरक्षा';

  @override
  String get vehicleMaster => 'वाहन';

  @override
  String get vehicleMasterSubtitle => 'वाहन प्रबंधित करें';

  @override
  String get utensilMaster => 'बर्तन';

  @override
  String get utensilMasterSubtitle => 'बर्तन प्रबंधित करें';

  @override
  String get backupAWS => 'AWS बैकअप';

  @override
  String get backupSubtitle => 'क्लाउड पर अपलोड करें';

  @override
  String get auditLogs => 'ऑडिट लॉग';

  @override
  String get auditLogsSubtitle => 'लॉग देखें';

  @override
  String get aboutApp => 'ऐप के बारे में';

  @override
  String get logout => 'लॉगआउट';

  @override
  String get selectLanguage => 'भाषा चुनें';

  @override
  String get attendanceTitle => 'मेरी उपस्थिति';

  @override
  String get noStaffRecord => 'कोई स्टाफ रिकॉर्ड नहीं मिला';

  @override
  String get mobileNotLinked =>
      'आपका मोबाइल नंबर किसी स्टाफ रिकॉर्ड से लिंक नहीं है।\nकृपया प्रशासक से संपर्क करें।';

  @override
  String get checkingLocation => 'स्थान की जाँच की जा रही है...';

  @override
  String get punchIn => 'पंच इन';

  @override
  String get punchOut => 'पंच आउट';

  @override
  String get punching => 'पंचिंग...';

  @override
  String get readyToPunchIn => 'पंच इन के लिए तैयार';

  @override
  String workingSince(String time) {
    return '$time से काम कर रहे हैं';
  }

  @override
  String get todayShiftCompleted => 'आज की शिफ्ट पूरी हुई';

  @override
  String elapsedTime(int hours, int minutes) {
    return '$hours घंटे $minutes मिनट बीते';
  }

  @override
  String get todayDetails => 'आज का विवरण';

  @override
  String get punchedIn => 'पंच इन किया गया';

  @override
  String get punchedOut => 'पंच आउट किया गया';

  @override
  String get location => 'स्थान';

  @override
  String get withinKitchen => 'रसोई क्षेत्र के भीतर';

  @override
  String get outsideKitchen => 'रसोई क्षेत्र के बाहर';

  @override
  String get punchSuccess => '✅ सफलतापूर्वक पंच इन किया गया!';

  @override
  String get punchWarning => '⚠️ पंच इन किया गया (रसोई क्षेत्र के बाहर)';

  @override
  String punchOutSuccess(String hours) {
    return '✅ पंच आउट किया गया - $hours घंटे';
  }

  @override
  String get refresh => 'ताज़ा करें';

  @override
  String get loading => 'लोड हो रहा है...';

  @override
  String get ordersCalendarTitle => 'ऑर्डर कैलेंडर';

  @override
  String get openSystemCalendar => 'सिस्टम कैलेंडर खोलें';

  @override
  String get utilizationLow => 'कम (<50%)';

  @override
  String get utilizationMed => 'मध्यम (50-90%)';

  @override
  String get utilizationHigh => 'उच्च (>90%)';

  @override
  String get editOrder => 'ऑर्डर संपादित करें';

  @override
  String get addOrder => 'ऑर्डर जोड़ें';

  @override
  String get viewOrder => 'View Order';

  @override
  String get viewOnlyMode => 'Viewing order details. Editing is not available.';

  @override
  String dateLabel(String date) {
    return 'तारीख';
  }

  @override
  String totalPax(int pax) {
    return 'कुल पैक्स: $pax';
  }

  @override
  String get deliveryTime => 'डिलीवरी का समय';

  @override
  String get tapToSelectTime => 'समय चुनने के लिए टैप करें';

  @override
  String get customerName => 'ग्राहक का नाम';

  @override
  String get digitsOnly => 'केवल अंक';

  @override
  String get mobileLengthError => 'ठीक 10 अंक होने चाहिए';

  @override
  String get mealType => 'भोजन का प्रकार';

  @override
  String get foodType => 'खाद्य प्रकार';

  @override
  String get menuItems => 'मेनू आइटम';

  @override
  String get addItem => 'आइटम जोड़ें';

  @override
  String get subtotal => 'उपयोग (₹)';

  @override
  String get discPercent => 'छूट %';

  @override
  String get dishTotal => 'डिश कुल:';

  @override
  String get serviceAndCounterSetup => 'सेवा और काउंटर सेटअप';

  @override
  String get serviceRequiredQuestion => 'क्या सेवा आवश्यक है?';

  @override
  String get serviceType => 'सेवा का प्रकार: ';

  @override
  String get countersCount => 'काउंटरों की संख्या';

  @override
  String get ratePerStaff => 'दर/स्टाफ (₹)';

  @override
  String get staffRequired => 'आवश्यक स्टाफ';

  @override
  String costWithRupee(String cost) {
    return 'लागत: ₹$cost';
  }

  @override
  String get counterSetupNeeded => 'क्या काउंटर सेटअप की आवश्यकता है?';

  @override
  String get ratePerCounter => 'दर/काउंटर (₹)';

  @override
  String counterCostWithRupee(String cost) {
    return 'काउंटर लागत: ₹$cost';
  }

  @override
  String discountWithPercent(String percent) {
    return 'छूट ($percent%):';
  }

  @override
  String get serviceCost => 'सेवा लागत:';

  @override
  String get counterSetup => 'काउंटर सेटअप:';

  @override
  String get grandTotal => 'कुल योग:';

  @override
  String get notes => 'नोट्स';

  @override
  String get saveOrder => 'ऑर्डर सहेजें';

  @override
  String get orderSaved => '✅ ऑर्डर सहेजा गया';

  @override
  String saveOrderError(String error) {
    return 'ऑर्डर सहेजने में त्रुटि: $error';
  }

  @override
  String get typeDishName => 'डिश का नाम लिखें';

  @override
  String get rate => 'दर';

  @override
  String get qty => 'मात्र';

  @override
  String get cost => 'लागत';

  @override
  String get required => 'आवश्यक';

  @override
  String get resetCalculation => 'गणना रीसेट करें';

  @override
  String get breakfast => 'नाश्ता';

  @override
  String get lunch => 'दोपहर का भोजन';

  @override
  String get dinner => 'रात का खाना';

  @override
  String get snacksOthers => 'नाश्ता/अन्य';

  @override
  String get veg => 'शाकाहारी';

  @override
  String get nonVeg => 'मांषाजी';

  @override
  String failedLoadOrders(String error) {
    return 'ऑर्डर लोड करने में विफल: $error';
  }

  @override
  String errorLoadingOrders(String error) {
    return 'त्रुटि: $error';
  }

  @override
  String get cannotEditPastOrders => 'पिछले ऑर्डर संपादित नहीं कर सकते।';

  @override
  String get cannotDeletePastOrders => 'पिछले ऑर्डर हटा नहीं सकते।';

  @override
  String get deleteOrderTitle => 'ऑर्डर हटाएं?';

  @override
  String get deleteOrderConfirm =>
      'यह स्थानीय रूप से हटा देगा। (ऑनलाइन होने पर सिंक होगा)';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get delete => 'हटाएं';

  @override
  String get confirm => 'पुष्टि करें';

  @override
  String get requiredField => 'आवश्यक';

  @override
  String error(String error) {
    return 'त्रुटि: $error';
  }

  @override
  String get orderDeleted => 'ऑर्डर हटा दिया गया';

  @override
  String errorDeletingOrder(String error) {
    return 'हटाने में त्रुटि: $error';
  }

  @override
  String ordersCount(int count) {
    return '$count ऑर्डर';
  }

  @override
  String get noLocation => 'कोई स्थान नहीं';

  @override
  String get unnamed => 'बेनाम';

  @override
  String ordersDateTitle(String date) {
    return 'ऑर्डर - $date';
  }

  @override
  String get dishSummary => 'डिश सारांश';

  @override
  String get retry => 'पुनः प्रयास करें';

  @override
  String get noOrdersFound => 'इस तारीख के लिए कोई ऑर्डर नहीं';

  @override
  String vegCount(int count) {
    return 'शाकाहारी: $count';
  }

  @override
  String nonVegCount(int count) {
    return 'मांसाहारी: $count';
  }

  @override
  String totalCount(int count) {
    return 'कुल: $count';
  }

  @override
  String failedLoadSummary(String error) {
    return 'सारांश लोड करने में विफल: $error';
  }

  @override
  String errorLoadingSummary(String error) {
    return 'त्रुटि: $error';
  }

  @override
  String summaryDateTitle(String date) {
    return 'सारांश - $date';
  }

  @override
  String get noDishesFound => 'कोई व्यंजन नहीं मिला';

  @override
  String get unnamedDish => 'बेनाम व्यंजन';

  @override
  String qtyWithCount(int count) {
    return 'मात्रा: $count';
  }

  @override
  String get kitchenView => 'रसोई';

  @override
  String get dispatchView => 'डिस्पैच';

  @override
  String get punchInOut => 'पंच इन/आउट';

  @override
  String get staffManagement => 'स्टाफ प्रबंधन';

  @override
  String get adminOnly => 'केवल एडमिन';

  @override
  String get restrictedToAdmins => '⛔ केवल एडमिन के लिए';

  @override
  String get utensils => 'बर्तन';

  @override
  String get kitchenOperations => 'रसोई संचालन';

  @override
  String get ordersView => 'ऑर्डर';

  @override
  String get productionQueue => 'उत्पादन कतार';

  @override
  String get ready => 'तैयार';

  @override
  String get other => 'अन्य';

  @override
  String get internalKitchen => 'आंतरिक रसोई';

  @override
  String get subcontract => 'सबकांट्रैक्ट';

  @override
  String get liveCounter => 'लाइव काउंटर';

  @override
  String get prepIngredients => '🔥 सामग्री तैयार करें';

  @override
  String get live => 'लाइव';

  @override
  String get prep => 'तैयारी';

  @override
  String get start => 'शुरू';

  @override
  String get prepping => 'तैयारी चल रही है';

  @override
  String get inQueue => 'कतार में';

  @override
  String get assignEdit => 'सौंपें / संपादित करें';

  @override
  String get productionSettings => 'उत्पादन सेटिंग्स';

  @override
  String get noItemsInQueue => 'कतार में कोई आइटम नहीं';

  @override
  String get done => 'हो गया';

  @override
  String get noRecipeDefined => 'कोई रेसिपी नहीं';

  @override
  String get ingredientsRequired => '📋 आवश्यक सामग्री:';

  @override
  String get noReadyItems => 'कोई तैयार आइटम नहीं';

  @override
  String get returnItem => 'वापस करें';

  @override
  String paxLabel(int count) {
    return 'पैक्स: $count';
  }

  @override
  String locLabel(String location) {
    return 'स्थान: $location';
  }

  @override
  String get na => 'लागू नहीं';

  @override
  String get noOrdersForDispatch => 'डिस्पैच के लिए कोई ऑर्डर नहीं';

  @override
  String get createDispatch => 'डिस्पैच बनाएं';

  @override
  String get dispatchDetails => 'विवरण';

  @override
  String get driverName => 'ड्राइवर का नाम';

  @override
  String get vehicleNumber => 'वाहन नंबर';

  @override
  String get noPendingDispatches => 'कोई लंबित डिस्पैच नहीं!';

  @override
  String get tapToAddDispatch => '+ टैप करके जोड़ें।';

  @override
  String orderFor(String name) {
    return 'ऑर्डर: $name';
  }

  @override
  String driverWithVehicle(String driver, String vehicle) {
    return 'ड्राइवर: $driver ($vehicle)';
  }

  @override
  String get statusPending => 'लंबित';

  @override
  String get statusDispatched => 'भेजा गया';

  @override
  String get statusDelivered => 'वितरित';

  @override
  String failedUpdateStatus(String error) {
    return 'विफल: $error';
  }

  @override
  String get payroll => 'पेरोल';

  @override
  String get staff => 'स्टाफ';

  @override
  String get today => 'आज';

  @override
  String get noStaffMembers => 'कोई स्टाफ नहीं';

  @override
  String get tapToAddStaff => '+ टैप करके स्टाफ जोड़ें';

  @override
  String get unknown => 'अज्ञात';

  @override
  String get noMobile => 'मोबाइल नहीं';

  @override
  String get permanent => 'स्थायी';

  @override
  String get dailyWage => 'दैनिक वेतन';

  @override
  String get contractor => 'ठेकेदार';

  @override
  String get alreadyPunchedIn => 'आज पहले ही पंच इन कर चुके हैं!';

  @override
  String get couldNotGetLocation => 'स्थान प्राप्त नहीं कर सके';

  @override
  String get punchedInGeo => '✓ पंच इन (सीमा के भीतर)';

  @override
  String get punchedInNoGeo => '⚠️ पंच इन (सीमा के बाहर)';

  @override
  String punchedOutMsg(String hours, String ot) {
    return 'पंच आउट - $hours घंटे $ot';
  }

  @override
  String get totalStaff => 'कुल स्टाफ';

  @override
  String get present => 'उपस्थित';

  @override
  String get absent => 'अनुपस्थित';

  @override
  String get noAttendanceToday => 'आज कोई उपस्थिति नहीं';

  @override
  String get workingStatus => 'काम कर रहे हैं';

  @override
  String get otLabel => 'OT';

  @override
  String get addStaff => 'स्टाफ जोड़ें';

  @override
  String get staffDetails => 'स्टाफ विवरण';

  @override
  String tapToPhoto(String action) {
    return 'फोटो $action के लिए टैप करें';
  }

  @override
  String get basicInfo => 'बुनियादी जानकारी';

  @override
  String get fullName => 'पूरा नाम *';

  @override
  String get roleDesignation => 'पद';

  @override
  String get staffType => 'प्रकार';

  @override
  String get email => 'ईमेल';

  @override
  String get salaryRates => 'वेतन दरें';

  @override
  String get monthlySalary => 'मासिक वेतन (₹)';

  @override
  String get payoutFrequency => 'भुगतान आवृत्ति';

  @override
  String get dailyWageLabel => 'दैनिक वेतन (₹)';

  @override
  String get hourlyRate => 'प्रति घंटा दर (₹)';

  @override
  String get bankIdDetails => 'बैंक और आईडी विवरण';

  @override
  String get bankName => 'बैंक का नाम';

  @override
  String get accountNumber => 'खाता संख्या';

  @override
  String get ifscCode => 'आईएफएससी कोड';

  @override
  String get aadharNumber => 'आधार नंबर';

  @override
  String get emergencyContact => 'आपातकालीन संपर्क';

  @override
  String get contactName => 'नाम';

  @override
  String get contactNumber => 'नंबर';

  @override
  String get address => 'पता';

  @override
  String get addStaffBtn => 'जोड़ें';

  @override
  String get saveChanges => 'परिवर्तन सहेजें';

  @override
  String get advances => 'अग्रिम';

  @override
  String get attendance => 'उपस्थिति';

  @override
  String get totalAdvances => 'कुल अग्रिम';

  @override
  String get pendingDeduction => 'लंबित कटौती';

  @override
  String get addAdvance => 'अग्रिम जोड़ें';

  @override
  String get noAdvances => 'कोई अग्रिम नहीं';

  @override
  String get deducted => 'कटौती की गई';

  @override
  String get pending => 'लंबित';

  @override
  String reason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get deleteStaff => 'स्टाफ हटाएं';

  @override
  String get deleteStaffConfirm =>
      'निश्चित रूप से हटाएं? इसे पूर्ववत नहीं किया जा सकता।';

  @override
  String get staffDeleted => 'हटा दिया गया';

  @override
  String get staffAdded => 'जोड़ा गया!';

  @override
  String get staffUpdated => 'अपडेट किया गया!';

  @override
  String get selectPhoto => 'फोटो चुनें';

  @override
  String get camera => 'कैमरा';

  @override
  String get gallery => 'गेलरी';

  @override
  String get photoSelectedWeb => 'फोटो चुना गया';

  @override
  String get photoUpdated => 'अपडेट किया गया';

  @override
  String get amountRupee => 'राशि (₹)';

  @override
  String get staffPayroll => 'स्टाफ पेरोल';

  @override
  String get basePay => 'मूल वेतन';

  @override
  String get otPay => 'ओवरटाइम वेतन';

  @override
  String get netPay => 'शुद्ध वेतन';

  @override
  String get noStaffData => 'कोई डेटा नहीं';

  @override
  String get processPayroll => 'वेतन संसाधित करें';

  @override
  String processPayrollConfirm(String name, String date) {
    return 'क्या $name के लिए अग्रिम में कटौती करें ($date)?';
  }

  @override
  String payrollProcessed(String name) {
    return '$name का वेतन संसाधित किया गया';
  }

  @override
  String get advanceDeduction => 'अग्रिम कटौती';

  @override
  String get netPayable => 'देय राशि';

  @override
  String get markAdvancesDeducted => 'कटौती के रूप में चिह्नित करें';

  @override
  String otMultiplierInfo(String rate) {
    return 'OT गुणक: ${rate}x | 8 घंटे से अधिक';
  }

  @override
  String get utensilsTracking => 'बर्तन ट्रैकिंग';

  @override
  String get noUtensilsAdded => 'कोई बर्तन नहीं';

  @override
  String get addFirstUtensil => 'पहला बर्तन जोड़ें';

  @override
  String get addUtensil => 'बर्तन जोड़ें';

  @override
  String get utensilName => 'बर्तन का नाम';

  @override
  String get utensilNameHint => 'उदा. प्लेट, कप';

  @override
  String get totalStock => 'कुल स्टॉक';

  @override
  String get enterQuantity => 'मात्रा दर्ज करें';

  @override
  String get availableStock => 'उपलब्ध स्टॉक';

  @override
  String get enterUtensilName => 'नाम दर्ज करें';

  @override
  String get utensilAdded => '✅ जोड़ा गया';

  @override
  String get utensilUpdated => '✅ अपडेट किया गया';

  @override
  String get utensilDeleted => 'हटा दिया गया';

  @override
  String editUtensil(String name) {
    return 'संपादित करें: $name';
  }

  @override
  String get deleteUtensil => 'हटाएं?';

  @override
  String deleteUtensilConfirm(String name) {
    return '\"$name\" को हटाएं?';
  }

  @override
  String get save => 'सहेजें';

  @override
  String get add => 'जोड़ें';

  @override
  String availableCount(int available, int total) {
    return 'उपलब्ध: $available / $total';
  }

  @override
  String issuedCount(int issued, String percent) {
    return 'जारी: $issued ($percent%)';
  }

  @override
  String get inventoryHub => 'इन्वेंट्री हब';

  @override
  String get ingredients => 'सामग्री';

  @override
  String get masterList => 'मास्टर सूची';

  @override
  String get bom => 'बीओएम';

  @override
  String get recipeMapping => 'रेसिपी मैप';

  @override
  String get mrpRun => 'एमआरपी रन';

  @override
  String get calculate => 'गणना करें';

  @override
  String get purchaseOrders => 'खरीद आदेश';

  @override
  String get purchaseOrderShort => 'पीओ';

  @override
  String get trackOrders => 'ऑर्डर ट्रैक करें';

  @override
  String get suppliers => 'आपूर्तिकर्ता';

  @override
  String get vendors => 'विक्रेता';

  @override
  String get subcontractors => 'उपठेकेदार';

  @override
  String get kitchens => 'रसोई';

  @override
  String get ingredientsMaster => 'सामग्री मास्टर';

  @override
  String get ingredientName => 'सामग्री का नाम';

  @override
  String get skuBrandOptional => 'SKU / ब्रांड (वैकल्पिक)';

  @override
  String get costPerUnit => 'प्रति यूनिट लागत (₹)';

  @override
  String get category => 'श्रेणी';

  @override
  String get unit => 'इकाई';

  @override
  String get unitKg => 'किलोग्राम (kg)';

  @override
  String get unitG => 'ग्राम (g)';

  @override
  String get unitL => 'लीटर';

  @override
  String get unitMl => 'मिलीलीटर (ml)';

  @override
  String get unitNos => 'संख्या (nos)';

  @override
  String get unitBunch => 'गुच्छा';

  @override
  String get unitPcs => 'टुकड़े (pcs)';

  @override
  String get enterIngredientName => 'नाम दर्ज करें';

  @override
  String get ingredientAdded => '✅ जोड़ा गया';

  @override
  String get editIngredient => 'संपादित करें';

  @override
  String get ingredientUpdated => '✅ अपडेट किया गया';

  @override
  String get searchPlaceholder => 'खोजें...';

  @override
  String get noResultsFound => 'कोई परिणाम नहीं मिला';

  @override
  String ingredientsCount(int count) {
    return '$count सामग्री';
  }

  @override
  String categoriesCount(int count) {
    return '$count श्रेणियां';
  }

  @override
  String get catAll => 'सभी';

  @override
  String get catVegetable => 'सब्जी';

  @override
  String get catMeat => 'मांस';

  @override
  String get catSeafood => 'सीफूड';

  @override
  String get catSpice => 'मसाला';

  @override
  String get catDairy => 'डेयरी';

  @override
  String get catGrain => 'अनाज';

  @override
  String get catOil => 'तेल';

  @override
  String get catBeverage => 'पेय';

  @override
  String get catOther => 'अन्य';

  @override
  String get bomManagement => 'बीओएम प्रबंधन';

  @override
  String get bomInfo => '100 लोगों के लिए आवश्यक सामग्री';

  @override
  String get searchDishes => 'व्यंजन खोजें...';

  @override
  String get addDishesHint => 'पहले मेनू में व्यंजन जोड़ें';

  @override
  String itemsCount(int count) {
    return '$count आइटम';
  }

  @override
  String get quantity100Pax => '100 लोगों के लिए मात्रा';

  @override
  String get selectIngredient => 'सामग्री चुनें';

  @override
  String get selectIngredientHint => 'चुनें और मात्रा दर्ज करें';

  @override
  String get allIngredientsAdded => 'सभी जोड़े गए';

  @override
  String get quantityUpdated => '✅ मात्रा अपडेट की गई';

  @override
  String get ingredientRemoved => 'हटा दिया गया';

  @override
  String get pax100 => '100 लोग';

  @override
  String get noIngredientsAdded => 'कोई सामग्री नहीं';

  @override
  String get mrpRunScreenTitle => 'एमआरपी रन';

  @override
  String get changeDate => 'तारीख बदलें';

  @override
  String get totalOrders => 'कुल ऑर्डर';

  @override
  String get liveKitchen => 'लाइव किचन';

  @override
  String get subcontracted => 'सबकांट्रेक्टेड';

  @override
  String get noOrdersForDate => 'कोई ऑर्डर नहीं';

  @override
  String get selectDifferentDate => 'दूसरी तारीख चुनें';

  @override
  String get runMrp => 'एमआरपी चलाएं';

  @override
  String get calculating => 'गणना हो रही है...';

  @override
  String get noOrdersToProcess => 'कोई ऑर्डर नहीं';

  @override
  String get venueNotSpecified => 'स्थान निर्दिष्ट नहीं है';

  @override
  String get selectSubcontractor => 'उपठेकेदार चुनें';

  @override
  String get liveKitchenChip => 'लाइव';

  @override
  String get subcontractChip => 'ठेका';

  @override
  String get orderLockedCannotModify =>
      'ऑर्डर अंतिम/लॉक है। संशोधित नहीं कर सकते।';

  @override
  String get mrpOutputTitle => 'एमआरपी आउटपुट';

  @override
  String get noIngredientsCalculated => 'गणना नहीं की गई';

  @override
  String get checkBomDefined => 'बीओएम की जांच करें';

  @override
  String get total => 'कुल';

  @override
  String get proceedToAllotment => 'आवंटन के लिए आगे बढ़ें';

  @override
  String get allotmentTitle => 'आवंटन';

  @override
  String get supplierAllotment => 'आपूर्तिकर्ता आवंटन';

  @override
  String get summary => 'सारांश';

  @override
  String get assignIngredientHint => 'आपूर्तिकर्ताओं को असाइन करें';

  @override
  String assignedStatus(int assigned, int total) {
    return '$assigned/$total असाइन किया गया';
  }

  @override
  String get supplier => 'आपूर्तिकर्ता';

  @override
  String get generateAndSendPos => 'पीओ जनरेट करें और भेजें';

  @override
  String posWillBeGenerated(int count) {
    return '$count पीओ जनरेट होंगे';
  }

  @override
  String get noAllocationsMade => 'कोई आवंटन नहीं';

  @override
  String get allocateIngredientsFirst => 'पहले आवंटन करें';

  @override
  String posGeneratedSuccess(int count) {
    return '✅ $count पीओ जनरेट किए गए';
  }

  @override
  String get catGrocery => 'किराना';

  @override
  String get supplierMaster => 'आपूर्तिकर्ता';

  @override
  String get addSupplier => 'आपूर्तिकर्ता जोड़ें';

  @override
  String get editSupplier => 'संपादित करें';

  @override
  String get nameRequired => 'नाम *';

  @override
  String get mobile => 'मोबाइल';

  @override
  String get gstNumber => 'जीएसटी नंबर';

  @override
  String get bankDetails => 'बैंक विवरण';

  @override
  String get enterSupplierName => 'नाम दर्ज करें';

  @override
  String get supplierUpdated => '✅ अपडेट किया गया';

  @override
  String get supplierAdded => '✅ जोड़ा गया';

  @override
  String get noSuppliersAdded => 'कोई आपूर्तिकर्ता नहीं';

  @override
  String get noPhone => 'फोन नहीं';

  @override
  String get subcontractorMaster => 'उपठेकेदार';

  @override
  String get editSubcontractor => 'संपादित करें';

  @override
  String get addSubcontractor => 'जोड़ें';

  @override
  String get kitchenBusinessName => 'नाम *';

  @override
  String get mobileRequired => 'मोबाइल *';

  @override
  String get specialization => 'विशेषज्ञता';

  @override
  String get specializationHint => 'उदा. बिरयानी';

  @override
  String get ratePerPax => 'दर (प्रति व्यक्ति - ₹)';

  @override
  String get enterNameMobile => 'नाम और नंबर';

  @override
  String get subcontractorUpdated => '✅ अपडेट किया गया';

  @override
  String get subcontractorAdded => '✅ जोड़ा गया';

  @override
  String get noSubcontractorsAdded => 'कोई नहीं';

  @override
  String get perPax => 'प्रति व्यक्ति';

  @override
  String get purchaseOrdersTitle => 'खरीद आदेश';

  @override
  String get statusSent => 'भेजा गया';

  @override
  String get statusViewed => 'देखा गया';

  @override
  String get statusAccepted => 'स्वीकार किया गया';

  @override
  String purchaseOrdersCount(int count) {
    return '$count खरीद आदेश';
  }

  @override
  String get noPurchaseOrders => 'कोई नहीं';

  @override
  String get runMrpHint => 'पीओ पाने के लिए एमआरपी चलाएं';

  @override
  String get dispatchTitle => 'डिस्पैच';

  @override
  String get tabList => 'सूची';

  @override
  String get tabActive => 'सक्रिय';

  @override
  String get tabReturns => 'वापसी';

  @override
  String get tabUnload => 'उतारना';

  @override
  String noPendingOrdersDate(String date) {
    return 'कोई लंबित ऑर्डर नहीं';
  }

  @override
  String get noActiveDispatches => 'सक्रिय नहीं';

  @override
  String get noReturnTracking => 'नहीं';

  @override
  String get noUnloadItems => 'उतारने के लिए कुछ नहीं';

  @override
  String get upgradeToEnterprise => 'Upgrade to Enterprise for this feature';

  @override
  String get startDispatch => 'शुरू करें';

  @override
  String get waitingForKitchen => 'रसोई का इंतजार';

  @override
  String get track => 'ट्रैक';

  @override
  String get verify => 'सत्यापित करें';

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
  String get qtyLabel => 'मात्रा';

  @override
  String get reportsTitle => 'रिपोर्ट';

  @override
  String get periodLabel => 'अवधि: ';

  @override
  String get day => 'दिन';

  @override
  String get week => 'सप्ताह';

  @override
  String get month => 'महीना';

  @override
  String get year => 'वर्ष';

  @override
  String get orders => 'ऑर्डर';

  @override
  String get kitchen => 'रसोई';

  @override
  String get dispatch => 'डिस्पैच';

  @override
  String get hr => 'मानव संसाधन';

  @override
  String get noDataSelectedPeriod => 'चयनित अवधि के लिए कोई डेटा नहीं';

  @override
  String get revenue => 'राजस्व';

  @override
  String get confirmed => 'पुष्टि की गई';

  @override
  String get completed => 'पूरा हुआ';

  @override
  String get cancelled => 'रद्द किया गया';

  @override
  String get inProgress => 'प्रगति में';

  @override
  String get delivered => 'वितरित';

  @override
  String get inTransit => 'रास्ते में';

  @override
  String get totalDispatches => 'कुल डिस्पैच';

  @override
  String get hours => 'घंटे';

  @override
  String get overtime => 'ओवरटाइम';

  @override
  String get staffWithOt => 'ओवरटाइम वाले स्टाफ';

  @override
  String get totalOt => 'कुल ओवरटाइम';

  @override
  String get noOvertime => 'कोई ओवरटाइम नहीं';

  @override
  String get financeTitle => 'वित्त';

  @override
  String get income => 'आय';

  @override
  String get expense => 'व्यय';

  @override
  String get netBalance => 'शुद्ध शेष';

  @override
  String get transactions => 'लेन-देन';

  @override
  String get ledgers => 'खाता बही';

  @override
  String get export => 'निर्यात';

  @override
  String get recentTransactions => 'हाल के लेन-देन';

  @override
  String get noTransactionsFound => 'कोई लेन-देन नहीं मिला';

  @override
  String get exportingReport => 'रिपोर्ट निर्यात की जा रही है...';

  @override
  String get filterAll => 'सभी';

  @override
  String get deleteTransactionTitle => 'हटाएं?';

  @override
  String get deleteTransactionContent => 'इसे पूर्ववत नहीं किया जा सकता।';

  @override
  String get customers => 'ग्राहक';

  @override
  String get comingSoon => 'जल्द आ रहा है';

  @override
  String get addIncome => 'आय जोड़ें';

  @override
  String get addExpense => 'व्यय जोड़ें';

  @override
  String get amountLabel => 'राशि';

  @override
  String get categoryLabel => 'श्रेणी';

  @override
  String get paymentModeLabel => 'भुगतान मोड';

  @override
  String get descriptionLabel => 'विवरण / नोट्स';

  @override
  String get saveTransaction => 'सहेजें';

  @override
  String get enterAmount => 'राशि दर्ज करें';

  @override
  String get invalidAmount => 'अमान्य राशि';

  @override
  String get transactionSaved => 'लेन-देन सहेजा गया';

  @override
  String get collectPayment => 'भुगतान प्राप्त करें';

  @override
  String get selectPaymentMethod => 'विधि चुनें';

  @override
  String get upiRazorpay => 'यूपीआई (Razorpay)';

  @override
  String get cardRazorpay => 'कार्ड (Razorpay)';

  @override
  String get cash => 'Cash';

  @override
  String get paymentSuccessful => 'भुगतान सफल!';

  @override
  String paymentReceivedMsg(String amount, int orderId) {
    return '₹$amount प्राप्त हुए (ऑर्डर #$orderId)';
  }

  @override
  String paymentFailed(Object error) {
    return 'विफल: $error';
  }

  @override
  String get chooseSubscription => 'सदस्यता योजना चुनें';

  @override
  String get selectStartPlan => 'योजना चुनें';

  @override
  String payBtn(String amount) {
    return 'भुगतान करें ₹$amount';
  }

  @override
  String get subscriptionActivated => 'सदस्यता सक्रिय!';

  @override
  String planActiveUntil(String date) {
    return '$date तक सक्रिय।';
  }

  @override
  String get continueBtn => 'जारी रखें';

  @override
  String get auditReportTitle => 'ऑडिट रिपोर्ट';

  @override
  String get noLogsExport => 'निर्यात के लिए कोई लॉग नहीं';

  @override
  String exportFailed(Object error) {
    return 'विफल: $error';
  }

  @override
  String get startDate => 'प्रारंभ तिथि';

  @override
  String get endDate => 'अंतिम तिथि';

  @override
  String get userIdLabel => 'उपयोगकर्ता आईडी';

  @override
  String get tableLabel => 'तालिका';

  @override
  String get noAuditLogs => 'कोई लॉग नहीं';

  @override
  String changedFields(String fields) {
    return 'परिवर्तन: $fields';
  }

  @override
  String beforeVal(String val) {
    return 'पहले: $val';
  }

  @override
  String afterVal(String val) {
    return 'बाद में: $val';
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
