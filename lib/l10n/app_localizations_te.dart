// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Telugu (`te`).
class AppLocalizationsTe extends AppLocalizations {
  AppLocalizationsTe([String locale = 'te']) : super(locale);

  @override
  String get appTitle => 'RuchiServ';

  @override
  String get signInContinue => 'కొనసాగడానికి సైన్ ఇన్ చేయండి';

  @override
  String get firmId => 'సంస్థ ID';

  @override
  String get enterFirmId => 'సంస్థ ID ని నమోదు చేయండి';

  @override
  String get mobileNumber => 'మొబైల్ నంబర్';

  @override
  String get enterMobile => 'మొబైల్ నంబర్ నమోదు చేయండి';

  @override
  String get password => 'పాస్‌వర్డ్';

  @override
  String get enterPassword => 'పాస్‌వర్డ్ నమోదు చేయండి';

  @override
  String get loginButton => 'లాగిన్';

  @override
  String get enableBiometricLogin => 'బయోమెట్రిక్ లాగిన్‌ని ప్రారంభించు';

  @override
  String get enableBiometricPrompt =>
      'తదుపరి సారి వేగంగా లాగిన్ కావడానికి బయోమెట్రిక్ ప్రమాణీకరణను ఉపయోగించాలనుకుంటున్నారా?';

  @override
  String get notNow => 'ఇప్పుడు వద్దు';

  @override
  String get enable => 'ప్రారంభించు';

  @override
  String get biometricEnabled => 'బయోమెట్రిక్ లాగిన్ ప్రారంభించబడింది!';

  @override
  String failedEnableBiometric(String error) {
    return 'బయోమెట్రిక్ ప్రారంభించడంలో విఫలమైంది: $error';
  }

  @override
  String get biometricNotAllowed =>
      'బయోమెట్రిక్ లాగిన్ అనుమతించబడదు. దయచేసి ఆన్‌లైన్‌లో లాగిన్ చేయండి.';

  @override
  String biometricFailed(String error) {
    return 'బయోమెట్రిక్ విఫలమైంది: $error';
  }

  @override
  String get subscription => 'సభ్యత్వం';

  @override
  String get subscriptionExpired =>
      'మీ సభ్యత్వం గడువు ముగిసింది. కొనసాగడానికి దయచేసి పునరుద్ధరించండి.';

  @override
  String subscriptionExpiresIn(int days) {
    return 'మీ సభ్యత్వం $days రోజుల్లో ముగుస్తుంది. దయచేసి పునరుద్ధరించండి.';
  }

  @override
  String get ok => 'సరే';

  @override
  String loginError(String error) {
    return 'లాగిన్ లోపం: $error';
  }

  @override
  String get register => 'రిజిస్టర్';

  @override
  String get forgotPassword => 'పాస్‌వర్డ్ మర్చిపోయారా?';

  @override
  String get invalidCredentials => 'తప్పు వివరాలు.';

  @override
  String get offlineLoginNotAllowed =>
      'ఆఫ్‌లైన్ లాగిన్ అనుమతించబడదు. దయచేసి ఇంటర్నెట్‌కు కనెక్ట్ చేయండి.';

  @override
  String get mainMenuTitle => 'మెనూ';

  @override
  String get moduleOrders => 'ఆర్డర్లు';

  @override
  String get moduleOperations => 'కార్యకలాపాలు';

  @override
  String get moduleInventory => 'ఇన్వెంటరీ';

  @override
  String get moduleFinance => 'ఆర్థిక';

  @override
  String get moduleReports => 'నివేదికలు';

  @override
  String get moduleSettings => 'సెట్టింగ్‌లు';

  @override
  String get moduleAttendance => 'నా హాజరు';

  @override
  String get noModulesAvailable => 'మాడ్యూల్స్ అందుబాటులో లేవు';

  @override
  String get contactAdministrator => 'అడ్మినిస్ట్రేటర్‌ను సంప్రదించండి';

  @override
  String get firmProfile => 'సంస్థ ప్రొఫైల్';

  @override
  String get viewUpdateFirm => 'వివరాలను వీక్షించండి/నవీకరించండి';

  @override
  String get userProfile => 'వినియోగదారు ప్రొఫైల్';

  @override
  String get manageLoginPrefs => 'లాగిన్ ప్రాధాన్యతలను నిర్వహించండి';

  @override
  String get manageUsers => 'వినియోగదారులను నిర్వహించండి';

  @override
  String get manageUsersSubtitle => 'వినియోగదారులను జోడించండి';

  @override
  String get authMobiles => 'అధీకృత మొబైల్స్';

  @override
  String get authMobilesSubtitle => 'మొబైల్ నంబర్లను నిర్వహించండి';

  @override
  String get paymentSettings => 'చెల్లింపు సెట్టింగ్‌లు';

  @override
  String get paymentSettingsSubtitle => 'గేట్‌వేలను కాన్ఫిగర్ చేయండి';

  @override
  String get generalSettings => 'సాధారణ సెట్టింగ్‌లు';

  @override
  String get generalSettingsSubtitle => 'థీమ్, భద్రత';

  @override
  String get vehicleMaster => 'వాహనాలు';

  @override
  String get vehicleMasterSubtitle => 'వాహనాలను నిర్వహించండి';

  @override
  String get utensilMaster => 'పాత్రలు';

  @override
  String get utensilMasterSubtitle => 'పాత్రలను నిర్వహించండి';

  @override
  String get backupAWS => 'AWS బ్యాకప్';

  @override
  String get backupSubtitle => 'క్లౌడ్‌కు అప్‌లోడ్ చేయండి';

  @override
  String get auditLogs => 'ఆడిట్ లాగ్స్';

  @override
  String get auditLogsSubtitle => 'లాగ్‌లను చూడండి';

  @override
  String get aboutApp => 'యాప్ గురించి';

  @override
  String get logout => 'లాగౌట్';

  @override
  String get selectLanguage => 'భాషను ఎంచుకోండి';

  @override
  String get attendanceTitle => 'నా హాజరు';

  @override
  String get noStaffRecord => 'స్టాఫ్ రికార్డ్ కనుగొనబడలేదు';

  @override
  String get mobileNotLinked =>
      'మీ మొబైల్ నంబర్ ఏ స్టాఫ్ రికార్డ్‌తో లింక్ చేయబడలేదు.\nదయచేసి అడ్మినిస్ట్రేటర్‌ను సంప్రదించండి.';

  @override
  String get checkingLocation => 'స్థానాన్ని తనిఖీ చేస్తోంది...';

  @override
  String get punchIn => 'పంచ్ ఇన్';

  @override
  String get punchOut => 'పంచ్ అవుట్';

  @override
  String get punching => 'నమోదు చేస్తోంది...';

  @override
  String get readyToPunchIn => 'పంచ్ ఇన్ చేయడానికి సిద్ధం';

  @override
  String workingSince(String time) {
    return '$time నుండి పని చేస్తున్నారు';
  }

  @override
  String get todayShiftCompleted => 'ఈ రోజు షిఫ్ట్ పూర్తయింది';

  @override
  String elapsedTime(int hours, int minutes) {
    return '$hours గంటలు $minutes నిమిషాలు గడిచాయి';
  }

  @override
  String get todayDetails => 'ఈ రోజు వివరాలు';

  @override
  String get punchedIn => 'పంచ్ ఇన్ చేశారు';

  @override
  String get punchedOut => 'పంచ్ అవుట్ చేశారు';

  @override
  String get location => 'స్థానం';

  @override
  String get withinKitchen => 'కిచెన్ పరిధిలో';

  @override
  String get outsideKitchen => 'కిచెన్ వెలుపల';

  @override
  String get punchSuccess => '✅ విజయవంతంగా పంచ్ ఇన్ చేశారు!';

  @override
  String get punchWarning => '⚠️ పంచ్ ఇన్ చేశారు (కిచెన్ వెలుపల)';

  @override
  String punchOutSuccess(String hours) {
    return '✅ పంచ్ అవుట్ చేశారు - $hours గంటలు';
  }

  @override
  String get refresh => 'రీఫ్రెష్';

  @override
  String get loading => 'లోడ్ అవుతోంది...';

  @override
  String get ordersCalendarTitle => 'ఆర్డర్ క్యాలెండర్';

  @override
  String get openSystemCalendar => 'సిస్టమ్ క్యాలెండర్ తెరవండి';

  @override
  String get utilizationLow => 'తక్కువ (<50%)';

  @override
  String get utilizationMed => 'మధ్యస్థం (50-90%)';

  @override
  String get utilizationHigh => 'అధికం (>90%)';

  @override
  String get editOrder => 'ఆర్డర్ సవరించండి';

  @override
  String get addOrder => 'ఆర్డర్ జోడించు';

  @override
  String dateLabel(String date) {
    return 'తేదీ';
  }

  @override
  String totalPax(int pax) {
    return 'మొత్తం వ్యక్తులు: $pax';
  }

  @override
  String get deliveryTime => 'డెలివరీ సమయం';

  @override
  String get tapToSelectTime => 'సమయం ఎంచుకోవడానికి నొక్కండి';

  @override
  String get customerName => 'కస్టమర్ పేరు';

  @override
  String get digitsOnly => 'అంకెలు మాత్రమే';

  @override
  String get mobileLengthError => 'ఖచ్చితంగా 10 అంకెలు ఉండాలి';

  @override
  String get mealType => 'భోజనం రకం';

  @override
  String get foodType => 'ఆహారం రకం';

  @override
  String get menuItems => 'మెనూ అంశాలు';

  @override
  String get addItem => 'అంశం జోడించు';

  @override
  String get subtotal => 'మొత్తం (₹)';

  @override
  String get discPercent => 'రిబేటు %';

  @override
  String get dishTotal => 'డిష్ మొత్తం:';

  @override
  String get serviceAndCounterSetup => 'సర్వీస్ & కౌంటర్ సెటప్';

  @override
  String get serviceRequiredQuestion => 'సర్వీస్ అవసరమా?';

  @override
  String get serviceType => 'సర్వీస్ రకం: ';

  @override
  String get countersCount => 'కౌంటర్ల సంఖ్య';

  @override
  String get ratePerStaff => 'ధర/స్టాఫ్ (₹)';

  @override
  String get staffRequired => 'అవసరమైన స్టాఫ్';

  @override
  String costWithRupee(String cost) {
    return 'ధర: ₹$cost';
  }

  @override
  String get counterSetupNeeded => 'కౌంటర్ సెటప్ అవసరమా?';

  @override
  String get ratePerCounter => 'ధర/కౌంటర్ (₹)';

  @override
  String counterCostWithRupee(String cost) {
    return 'కౌంటర్ ధర: ₹$cost';
  }

  @override
  String discountWithPercent(String percent) {
    return 'డిస్కౌంట్ ($percent%):';
  }

  @override
  String get serviceCost => 'సర్వీస్ ధర:';

  @override
  String get counterSetup => 'కౌంటర్ సెటప్:';

  @override
  String get grandTotal => 'మొత్తం:';

  @override
  String get notes => 'గమనికలు';

  @override
  String get saveOrder => 'ఆర్డర్ సేవ్ చేయి';

  @override
  String get orderSaved => '✅ ఆర్డర్ సేవ్ చేయబడింది';

  @override
  String saveOrderError(String error) {
    return 'ఆర్డర్ సేవ్ చేయడంలో లోపం: $error';
  }

  @override
  String get typeDishName => 'డిష్ పేరు టైప్ చేయండి';

  @override
  String get rate => 'ధర';

  @override
  String get qty => 'సంఖ్య';

  @override
  String get cost => 'మొత్తం';

  @override
  String get required => 'అవసరం';

  @override
  String get resetCalculation => 'లెక్కింపు రీసెట్ చేయి';

  @override
  String get breakfast => 'అల్పాహారం';

  @override
  String get lunch => 'మధ్యాహ్న భోజనం';

  @override
  String get dinner => 'రాత్రి భోజనం';

  @override
  String get snacksOthers => 'స్నాక్స్/ఇతర';

  @override
  String get veg => 'శాకాహారం';

  @override
  String get nonVeg => 'మాంసాహారం';

  @override
  String failedLoadOrders(String error) {
    return 'ఆర్డర్లు లోడ్ చేయడంలో విఫలమైంది: $error';
  }

  @override
  String errorLoadingOrders(String error) {
    return 'లోపం: $error';
  }

  @override
  String get cannotEditPastOrders => 'గత ఆర్డర్లను సవరించలేరు.';

  @override
  String get cannotDeletePastOrders => 'గత ఆర్డర్లను తొలగించలేరు.';

  @override
  String get deleteOrderTitle => 'ఆర్డర్ తొలగించాలా?';

  @override
  String get deleteOrderConfirm =>
      'ఇది స్థానిక కాపీని తొలగిస్తుంది. (ఆన్‌లైన్‌లో ఉన్నప్పుడు సింక్ అవుతుంది)';

  @override
  String get cancel => 'రద్దు చేయి';

  @override
  String get delete => 'తొలగించు';

  @override
  String get confirm => 'నిర్ధారించు';

  @override
  String get requiredField => 'అవసరం';

  @override
  String error(String error) {
    return 'లోపం: $error';
  }

  @override
  String get orderDeleted => 'ఆర్డర్ తొలగించబడింది';

  @override
  String errorDeletingOrder(String error) {
    return 'తొలగించడంలో లోపం: $error';
  }

  @override
  String ordersCount(int count) {
    return '$count ఆర్డర్లు';
  }

  @override
  String get noLocation => 'స్థానం లేదు';

  @override
  String get unnamed => 'పేరులేని';

  @override
  String ordersDateTitle(String date) {
    return 'ఆర్డర్లు - $date';
  }

  @override
  String get dishSummary => 'డిష్ సారాంశం';

  @override
  String get retry => 'మళ్ళీ ప్రయత్నించు';

  @override
  String get noOrdersFound => 'ఈ తేదీన ఆర్డర్లు లేవు';

  @override
  String vegCount(int count) {
    return 'శాకాహారం: $count';
  }

  @override
  String nonVegCount(int count) {
    return 'మాంసాహారం: $count';
  }

  @override
  String totalCount(int count) {
    return 'మొత్తం: $count';
  }

  @override
  String failedLoadSummary(String error) {
    return 'సారాంశం లోడ్ చేయడంలో విఫలమైంది: $error';
  }

  @override
  String errorLoadingSummary(String error) {
    return 'లోపం: $error';
  }

  @override
  String summaryDateTitle(String date) {
    return 'సారాంశం - $date';
  }

  @override
  String get noDishesFound => 'డిష్‌లు లేవు';

  @override
  String get unnamedDish => 'పేరులేని డిష్';

  @override
  String qtyWithCount(int count) {
    return 'సంఖ్య: $count';
  }

  @override
  String get kitchenView => 'కిచెన్';

  @override
  String get dispatchView => 'డిస్పాచ్';

  @override
  String get punchInOut => 'పంచ్ ఇన్/అవుట్';

  @override
  String get staffManagement => 'స్టాఫ్ నిర్వహణ';

  @override
  String get adminOnly => 'అడ్మిన్ మాత్రమే';

  @override
  String get restrictedToAdmins => '⛔ అడ్మిన్లకు మాత్రమే';

  @override
  String get utensils => 'పాత్రలు';

  @override
  String get kitchenOperations => 'కిచెన్ కార్యకలాపాలు';

  @override
  String get ordersView => 'ఆర్డర్లు';

  @override
  String get productionQueue => 'ఉత్పత్తి క్యూ';

  @override
  String get ready => 'సిద్ధం';

  @override
  String get other => 'ఇతర';

  @override
  String get internalKitchen => 'అంతర్గత కిచెన్';

  @override
  String get subcontract => 'సబ్‌కాంట్రాక్ట్';

  @override
  String get liveCounter => 'లైవ్ కౌంటర్';

  @override
  String get prepIngredients => '🔥 పదార్థాలు సిద్ధం చేయండి';

  @override
  String get live => 'లైవ్';

  @override
  String get prep => 'తయారీ';

  @override
  String get start => 'ప్రారంభించు';

  @override
  String get prepping => 'తయారవుతోంది';

  @override
  String get inQueue => 'క్యూలో ఉంది';

  @override
  String get assignEdit => 'కేటాయించు / సవరించు';

  @override
  String get productionSettings => 'ఉత్పత్తి సెట్టింగ్‌లు';

  @override
  String get noItemsInQueue => 'క్యూలో అంశాలు లేవు';

  @override
  String get done => 'పూర్తయింది';

  @override
  String get noRecipeDefined => 'రెసిపీ లేదు';

  @override
  String get ingredientsRequired => '📋 కావలసిన పదార్థాలు:';

  @override
  String get noReadyItems => 'సిద్ధమైన అంశాలు లేవు';

  @override
  String get returnItem => 'వాపసు';

  @override
  String paxLabel(int count) {
    return 'వ్యక్తులు: $count';
  }

  @override
  String locLabel(String location) {
    return 'స్థానం: $location';
  }

  @override
  String get na => 'వర్తించదు';

  @override
  String get noOrdersForDispatch => 'డిస్పాచ్ కోసం ఆర్డర్లు లేవు';

  @override
  String get createDispatch => 'డిస్పాచ్ సృష్టించు';

  @override
  String get dispatchDetails => 'వివరాలు';

  @override
  String get driverName => 'డ్రైవర్ పేరు';

  @override
  String get vehicleNumber => 'వాహనం నంబర్';

  @override
  String get noPendingDispatches => 'పెండింగ్ లేదు!';

  @override
  String get tapToAddDispatch => '+ నొక్కి జోడించండి.';

  @override
  String orderFor(String name) {
    return 'ఆర్డర్: $name';
  }

  @override
  String driverWithVehicle(String driver, String vehicle) {
    return 'డ్రైవర్: $driver ($vehicle)';
  }

  @override
  String get statusPending => 'పెండింగ్';

  @override
  String get statusDispatched => 'పంపబడింది';

  @override
  String get statusDelivered => 'డెలివరీ చేయబడింది';

  @override
  String failedUpdateStatus(String error) {
    return 'విఫలమైంది: $error';
  }

  @override
  String get payroll => 'జీతం';

  @override
  String get staff => 'స్టాఫ్';

  @override
  String get today => 'ఈ రోజు';

  @override
  String get noStaffMembers => 'స్టాఫ్ లేరు';

  @override
  String get tapToAddStaff => '+ నొక్కి స్టాఫ్ జోడించు';

  @override
  String get unknown => 'తెలియదు';

  @override
  String get noMobile => 'మొబైల్ లేదు';

  @override
  String get permanent => 'శాశ్వత';

  @override
  String get dailyWage => 'రోజువారీ కూలీ';

  @override
  String get contractor => 'కాంట్రాక్ట్';

  @override
  String get alreadyPunchedIn => 'ఈ రోజు ఇప్పటికే పంచ్ ఇన్ చేశారు!';

  @override
  String get couldNotGetLocation => 'స్థానం పొందలేకపోయాము';

  @override
  String get punchedInGeo => '✓ పంచ్ ఇన్ (పరిధిలో)';

  @override
  String get punchedInNoGeo => '⚠️ పంచ్ ఇన్ (పరిధి బయట)';

  @override
  String punchedOutMsg(String hours, String ot) {
    return 'పంచ్ అవుట్ - $hours గంటలు $ot';
  }

  @override
  String get totalStaff => 'మొత్తం స్టాఫ్';

  @override
  String get present => 'హాజరు';

  @override
  String get absent => 'గైర్హాజరు';

  @override
  String get noAttendanceToday => 'ఈ రోజు హాజరు లేదు';

  @override
  String get workingStatus => 'పని చేస్తున్నారు';

  @override
  String get otLabel => 'OT';

  @override
  String get addStaff => 'స్టాఫ్ జోడించు';

  @override
  String get staffDetails => 'స్టాఫ్ వివరాలు';

  @override
  String tapToPhoto(String action) {
    return 'ఫోటో $action నొక్కండి';
  }

  @override
  String get basicInfo => 'ప్రాథమిక సమాచారం';

  @override
  String get fullName => 'పూర్తి పేరు *';

  @override
  String get roleDesignation => 'హోదా';

  @override
  String get staffType => 'రకం';

  @override
  String get email => 'ఇమెయిల్';

  @override
  String get salaryRates => 'జీతం వివరాలు';

  @override
  String get monthlySalary => 'నెల జీతం (₹)';

  @override
  String get payoutFrequency => 'చెల్లింపు విధానం';

  @override
  String get dailyWageLabel => 'రోజువారీ కూలీ (₹)';

  @override
  String get hourlyRate => 'గంటకు (₹)';

  @override
  String get bankIdDetails => 'బ్యాంక్ & ID వివరాలు';

  @override
  String get bankName => 'బ్యాంక్ పేరు';

  @override
  String get accountNumber => 'ఖాతా నంబర్';

  @override
  String get ifscCode => 'IFSC కోడ్';

  @override
  String get aadharNumber => 'ఆధార్ నంబర్';

  @override
  String get emergencyContact => 'అత్యవసర పరిచయం';

  @override
  String get contactName => 'పేరు';

  @override
  String get contactNumber => 'నంబర్';

  @override
  String get address => 'చిరునామా';

  @override
  String get addStaffBtn => 'జోడించు';

  @override
  String get saveChanges => 'మార్పులు సేవ్ చేయి';

  @override
  String get advances => 'అడ్వాన్స్';

  @override
  String get attendance => 'హాజరు';

  @override
  String get totalAdvances => 'మొత్తం అడ్వాన్స్';

  @override
  String get pendingDeduction => 'పెండింగ్ మినహాయింపు';

  @override
  String get addAdvance => 'అడ్వాన్స్ జోడించు';

  @override
  String get noAdvances => 'అడ్వాన్స్ లేదు';

  @override
  String get deducted => 'మినహాయించబడింది';

  @override
  String get pending => 'పెండింగ్‌లో ఉంది';

  @override
  String reason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get deleteStaff => 'స్టాఫ్ తొలగించు';

  @override
  String get deleteStaffConfirm =>
      'ఖచ్చితంగా తొలగించాలా? దీన్ని వెనక్కి తీసుకోలేము.';

  @override
  String get staffDeleted => 'తొలగించబడింది';

  @override
  String get staffAdded => 'జోడించబడింది!';

  @override
  String get staffUpdated => 'నవీకరించబడింది!';

  @override
  String get selectPhoto => 'ఫోటో ఎంచుకోండి';

  @override
  String get camera => 'కెమెరా';

  @override
  String get gallery => 'గ్యాలరీ';

  @override
  String get photoSelectedWeb => 'ఫోటో ఎంచుకోబడింది';

  @override
  String get photoUpdated => 'నవీకరించబడింది';

  @override
  String get amountRupee => 'మొత్తం (₹)';

  @override
  String get staffPayroll => 'స్టాఫ్ పేరోల్';

  @override
  String get basePay => 'మూల వేతనం';

  @override
  String get otPay => 'OT చెల్లింపు';

  @override
  String get netPay => 'నికర వేతనం';

  @override
  String get noStaffData => 'డేటా లేదు';

  @override
  String get processPayroll => 'జీతం లెక్కించు';

  @override
  String processPayrollConfirm(String name, String date) {
    return '$name యొక్క అడ్వాన్స్ మినహాయించి జీతం వేయాలా ($date)?';
  }

  @override
  String payrollProcessed(String name) {
    return '$name కు జీతం లెక్కించబడింది';
  }

  @override
  String get advanceDeduction => 'అడ్వాన్స్ మినహాయింపు';

  @override
  String get netPayable => 'చెల్లించవలసినది';

  @override
  String get markAdvancesDeducted => 'మినహాయించినట్లు మార్క్ చేయి';

  @override
  String otMultiplierInfo(String rate) {
    return 'OT గుణకం: ${rate}x | 8 గంటల పైన';
  }

  @override
  String get utensilsTracking => 'పాత్రల ట్రాకింగ్';

  @override
  String get noUtensilsAdded => 'పాత్రలు లేవు';

  @override
  String get addFirstUtensil => 'మొదటి పాత్రను జోడించు';

  @override
  String get addUtensil => 'పాత్ర జోడించు';

  @override
  String get utensilName => 'పాత్ర పేరు';

  @override
  String get utensilNameHint => 'ఉదా. ప్లేటు, కప్పు';

  @override
  String get totalStock => 'మొత్తం స్టాక్';

  @override
  String get enterQuantity => 'సంఖ్య నమోదు చేయి';

  @override
  String get availableStock => 'అందుబాటులో ఉన్న స్టాక్';

  @override
  String get enterUtensilName => 'పేరు నమోదు చేయి';

  @override
  String get utensilAdded => '✅ జోడించబడింది';

  @override
  String get utensilUpdated => '✅ నవీకరించబడింది';

  @override
  String get utensilDeleted => 'తొలగించబడింది';

  @override
  String editUtensil(String name) {
    return 'సవరించు: $name';
  }

  @override
  String get deleteUtensil => 'తొలగించాలా?';

  @override
  String deleteUtensilConfirm(String name) {
    return '\"$name\" ను తొలగించాలా?';
  }

  @override
  String get save => 'సేవ్ చేయి';

  @override
  String get add => 'జోడించు';

  @override
  String availableCount(int available, int total) {
    return 'అందుబాటులో: $available / $total';
  }

  @override
  String issuedCount(int issued, String percent) {
    return 'ఇచ్చినవి: $issued ($percent%)';
  }

  @override
  String get inventoryHub => 'ఇన్వెంటరీ హబ్';

  @override
  String get ingredients => 'పదార్థాలు';

  @override
  String get masterList => 'మాస్టర్ లిస్ట్';

  @override
  String get bom => 'BOM';

  @override
  String get recipeMapping => 'రెసిపీ మ్యాపింగ్';

  @override
  String get mrpRun => 'MRP రన్';

  @override
  String get calculate => 'లెక్కించు';

  @override
  String get purchaseOrders => 'కొనుగోలు ఆర్డర్లు';

  @override
  String get purchaseOrderShort => 'PO';

  @override
  String get trackOrders => 'ట్రాక్ ఆర్డర్లు';

  @override
  String get suppliers => 'సరఫరాదారులు';

  @override
  String get vendors => 'విక్రేతలు';

  @override
  String get subcontractors => 'సబ్‌కాంట్రాక్టర్లు';

  @override
  String get kitchens => 'కిచెన్‌లు';

  @override
  String get ingredientsMaster => 'పదార్థాల మాస్టర్';

  @override
  String get ingredientName => 'పదార్థం పేరు';

  @override
  String get skuBrandOptional => 'SKU / బ్రాండ్ (ఐచ్ఛికం)';

  @override
  String get costPerUnit => 'యూనిట్ ధర (₹)';

  @override
  String get category => 'వర్గం';

  @override
  String get unit => 'యూనిట్';

  @override
  String get unitKg => 'కిలో (kg)';

  @override
  String get unitG => 'గ్రాము (g)';

  @override
  String get unitL => 'లీటర్';

  @override
  String get unitMl => 'మిల్లీ లీటర్ (ml)';

  @override
  String get unitNos => 'సంఖ్య (nos)';

  @override
  String get unitBunch => 'కట్ట';

  @override
  String get unitPcs => 'ముక్కలు (pcs)';

  @override
  String get enterIngredientName => 'పేరు నమోదు చేయి';

  @override
  String get ingredientAdded => '✅ జోడించబడింది';

  @override
  String get editIngredient => 'సవరించు';

  @override
  String get ingredientUpdated => '✅ నవీకరించబడింది';

  @override
  String get searchPlaceholder => 'వెతకండి...';

  @override
  String ingredientsCount(int count) {
    return '$count పదార్థాలు';
  }

  @override
  String categoriesCount(int count) {
    return '$count వర్గాలు';
  }

  @override
  String get catAll => 'అన్నీ';

  @override
  String get catVegetable => 'కూరగాయలు';

  @override
  String get catMeat => 'మాంసం';

  @override
  String get catSeafood => 'సీఫుడ్';

  @override
  String get catSpice => 'మసాలా';

  @override
  String get catDairy => 'పాల ఉత్పత్తులు';

  @override
  String get catGrain => 'ధాన్యం';

  @override
  String get catOil => 'నూనె';

  @override
  String get catBeverage => 'పానీయం';

  @override
  String get catOther => 'ఇతర';

  @override
  String get bomManagement => 'BOM నిర్వహణ';

  @override
  String get bomInfo => '100 మందికి కావలసిన పదార్థాలు';

  @override
  String get searchDishes => 'డిష్‌లు వెతకండి...';

  @override
  String get addDishesHint => 'ముందు మెనూలో డిష్‌లు జోడించండి';

  @override
  String itemsCount(int count) {
    return '$count అంశాలు';
  }

  @override
  String get quantity100Pax => '100 మందికి పరిమాణం';

  @override
  String get selectIngredient => 'పదార్థం ఎంచుకోండి';

  @override
  String get selectIngredientHint => 'ఎంచుకుని పరిమాణం ఇవ్వండి';

  @override
  String get allIngredientsAdded => 'అన్నీ జోడించబడ్డాయి';

  @override
  String get quantityUpdated => '✅ పరిమాణం నవీకరించబడింది';

  @override
  String get ingredientRemoved => 'తొలగించబడింది';

  @override
  String get pax100 => '100 మంది';

  @override
  String get noIngredientsAdded => 'పదార్థాలు లేవు';

  @override
  String get mrpRunScreenTitle => 'MRP రన్';

  @override
  String get changeDate => 'తేదీ మార్చు';

  @override
  String get totalOrders => 'మొత్తం ఆర్డర్లు';

  @override
  String get liveKitchen => 'లైవ్ కిచెన్';

  @override
  String get subcontracted => 'సబ్‌కాంట్రాక్ట్';

  @override
  String get noOrdersForDate => 'ఆర్డర్లు లేవు';

  @override
  String get selectDifferentDate => 'వేరే తేదీ ఎంచుకోండి';

  @override
  String get runMrp => 'MRP రన్ చేయి';

  @override
  String get calculating => 'లెక్కిస్తోంది...';

  @override
  String get noOrdersToProcess => 'ఆర్డర్లు లేవు';

  @override
  String get venueNotSpecified => 'స్థలం పేర్కొనలేదు';

  @override
  String get selectSubcontractor => 'సబ్‌కాంట్రాక్టర్ ఎంచుకోండి';

  @override
  String get liveKitchenChip => 'లైవ్';

  @override
  String get subcontractChip => 'కాంట్రాక్ట్';

  @override
  String get mrpOutputTitle => 'MRP అవుట్‌పుట్';

  @override
  String get noIngredientsCalculated => 'లెక్కించలేదు';

  @override
  String get checkBomDefined => 'BOM ఉందో చూడండి';

  @override
  String get total => 'మొత్తం';

  @override
  String get proceedToAllotment => 'కేటాయింపుకు వెళ్లు';

  @override
  String get allotmentTitle => 'కేటాయింపు';

  @override
  String get supplierAllotment => 'సరఫరాదారు కేటాయింపు';

  @override
  String get summary => 'సారాంశం';

  @override
  String get assignIngredientHint => 'సరఫరాదారులకు కేటాయించండి';

  @override
  String assignedStatus(int assigned, int total) {
    return '$assigned/$total కేటాయించబడింది';
  }

  @override
  String get supplier => 'సరఫరాదారు';

  @override
  String get generateAndSendPos => 'PO సృష్టించి పంపు';

  @override
  String posWillBeGenerated(int count) {
    return '$count PO సృష్టించబడతాయి';
  }

  @override
  String get noAllocationsMade => 'కేటాయింపులు లేవు';

  @override
  String get allocateIngredientsFirst => 'ముందు కేటాయించండి';

  @override
  String posGeneratedSuccess(int count) {
    return '✅ $count PO సృష్టించబడ్డాయి';
  }

  @override
  String get catGrocery => 'కిరాణా';

  @override
  String get supplierMaster => 'సరఫరాదారులు';

  @override
  String get addSupplier => 'సరఫరాదారు జోడించు';

  @override
  String get editSupplier => 'సవరించు';

  @override
  String get nameRequired => 'పేరు *';

  @override
  String get mobile => 'మొబైల్';

  @override
  String get gstNumber => 'GST నంబర్';

  @override
  String get bankDetails => 'బ్యాంక్ వివరాలు';

  @override
  String get enterSupplierName => 'పేరు నమోదు చేయి';

  @override
  String get supplierUpdated => '✅ నవీకరించబడింది';

  @override
  String get supplierAdded => '✅ జోడించబడింది';

  @override
  String get noSuppliersAdded => 'సరఫరాదారులు లేరు';

  @override
  String get noPhone => 'ఫోన్ లేదు';

  @override
  String get subcontractorMaster => 'సబ్‌కాంట్రాక్టర్లు';

  @override
  String get editSubcontractor => 'సవరించు';

  @override
  String get addSubcontractor => 'జోడించు';

  @override
  String get kitchenBusinessName => 'పేరు *';

  @override
  String get mobileRequired => 'మొబైల్ *';

  @override
  String get specialization => 'స్పెషలైజేషన్';

  @override
  String get specializationHint => 'ఉదా. బిర్యానీ';

  @override
  String get ratePerPax => 'ధర (ఒకరికి - ₹)';

  @override
  String get enterNameMobile => 'పేరు మరియు నంబర్';

  @override
  String get subcontractorUpdated => '✅ నవీకరించబడింది';

  @override
  String get subcontractorAdded => '✅ జోడించబడింది';

  @override
  String get noSubcontractorsAdded => 'ఎవరూ లేరు';

  @override
  String get perPax => 'ఒకరికి';

  @override
  String get purchaseOrdersTitle => 'కొనుగోలు ఆర్డర్లు';

  @override
  String get statusSent => 'పంపబడింది';

  @override
  String get statusViewed => 'చూశారు';

  @override
  String get statusAccepted => 'అంగీకరించబడింది';

  @override
  String purchaseOrdersCount(int count) {
    return '$count కొనుగోలు ఆర్డర్లు';
  }

  @override
  String get noPurchaseOrders => 'లేవు';

  @override
  String get runMrpHint => 'PO పొందడానికి MRP రన్ చేయి';

  @override
  String get dispatchTitle => 'డిస్పాచ్';

  @override
  String get tabList => 'జాబితా';

  @override
  String get tabActive => 'యాక్టివ్';

  @override
  String get tabReturns => 'రిటర్న్స్';

  @override
  String get tabUnload => 'అన్‌లోడ్';

  @override
  String noPendingOrdersDate(String date) {
    return 'పెండింగ్ ఆర్డర్లు లేవు';
  }

  @override
  String get noActiveDispatches => 'యాక్టివ్ లేదు';

  @override
  String get noReturnTracking => 'లేదు';

  @override
  String get noUnloadItems => 'అన్‌లోడ్ చేయడానికి ఏమీ లేదు';

  @override
  String get startDispatch => 'ప్రారంభించు';

  @override
  String get waitingForKitchen => 'కిచెన్ కోసం వేచి ఉంది';

  @override
  String get track => 'ట్రాక్';

  @override
  String get verify => 'ధృవీకరించు';

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
  String get qtyLabel => 'సంఖ్య';

  @override
  String get reportsTitle => 'నివేదికలు';

  @override
  String get periodLabel => 'కాలం: ';

  @override
  String get day => 'రోజు';

  @override
  String get week => 'వారం';

  @override
  String get month => 'నెల';

  @override
  String get year => 'సంవత్సరం';

  @override
  String get orders => 'ఆర్డర్లు';

  @override
  String get kitchen => 'కిచెన్';

  @override
  String get dispatch => 'డిస్పాచ్';

  @override
  String get hr => 'HR';

  @override
  String get noDataSelectedPeriod => 'ఎంచుకున్న కాలంలో డేటా లేదు';

  @override
  String get revenue => 'ఆదాయం';

  @override
  String get confirmed => 'ధృవీకరించబడింది';

  @override
  String get completed => 'పూర్తయింది';

  @override
  String get cancelled => 'రద్దు చేయబడింది';

  @override
  String get inProgress => 'పురోగతిలో ఉంది';

  @override
  String get delivered => 'డెలివరీ చేయబడింది';

  @override
  String get inTransit => 'దారిలో ఉంది';

  @override
  String get totalDispatches => 'మొత్తం డిస్పాచ్‌లు';

  @override
  String get hours => 'గంటలు';

  @override
  String get overtime => 'ఓవర్‌టైమ్';

  @override
  String get staffWithOt => 'OT చేసిన స్టాఫ్';

  @override
  String get totalOt => 'మొత్తం OT';

  @override
  String get noOvertime => 'OT లేదు';

  @override
  String get financeTitle => 'ఆర్థిక';

  @override
  String get income => 'ఆదాయం';

  @override
  String get expense => 'ఖర్చు';

  @override
  String get netBalance => 'నికర నిల్వ';

  @override
  String get transactions => ' లావాదేవీలు';

  @override
  String get ledgers => 'లెడ్జర్లు';

  @override
  String get export => 'ఎగుమతి';

  @override
  String get recentTransactions => 'ఇటీవలి లావాదేవీలు';

  @override
  String get noTransactionsFound => 'లావాదేవీలు లేవు';

  @override
  String get exportingReport => 'రిపోర్ట్ ఎగుమతి అవుతోంది...';

  @override
  String get filterAll => 'అన్నీ';

  @override
  String get deleteTransactionTitle => 'తొలగించాలా?';

  @override
  String get deleteTransactionContent => 'దీన్ని వెనక్కి తీసుకోలేము.';

  @override
  String get customers => 'కస్టమర్లు';

  @override
  String get comingSoon => 'త్వరలో వస్తుంది';

  @override
  String get addIncome => 'ఆదాయం జోడించు';

  @override
  String get addExpense => 'ఖర్చు జోడించు';

  @override
  String get amountLabel => 'మొత్తం';

  @override
  String get categoryLabel => 'వర్గం';

  @override
  String get paymentModeLabel => 'చెల్లింపు పద్ధతి';

  @override
  String get descriptionLabel => 'వివరణ / గమనికలు';

  @override
  String get saveTransaction => 'సేవ్ చేయి';

  @override
  String get enterAmount => 'మొత్తం నమోదు చేయి';

  @override
  String get invalidAmount => 'తప్పు మొత్తం';

  @override
  String get transactionSaved => 'లావాదేవీ సేవ్ చేయబడింది';

  @override
  String get collectPayment => 'చెల్లింపు తీసుకోండి';

  @override
  String get selectPaymentMethod => 'పద్ధతి ఎంచుకోండి';

  @override
  String get upiRazorpay => 'UPI (Razorpay)';

  @override
  String get cardRazorpay => 'Card (Razorpay)';

  @override
  String get cash => 'Cash';

  @override
  String get paymentSuccessful => 'చెల్లింపు విజయవంతం!';

  @override
  String paymentReceivedMsg(String amount, int orderId) {
    return '₹$amount స్వీకరించబడింది (ఆర్డర్ #$orderId)';
  }

  @override
  String paymentFailed(Object error) {
    return 'విఫలమైంది: $error';
  }

  @override
  String get chooseSubscription => 'సభ్యత్వ ప్లాన్ ఎంచుకోండి';

  @override
  String get selectStartPlan => 'ప్లాన్ ఎంచుకోండి';

  @override
  String payBtn(String amount) {
    return 'చెల్లించండి ₹$amount';
  }

  @override
  String get subscriptionActivated => 'సభ్యత్వం ప్రారంభించబడింది!';

  @override
  String planActiveUntil(String date) {
    return '$date వరకు యాక్టివ్‌గా ఉంటుంది.';
  }

  @override
  String get continueBtn => 'కొనసాగించు';

  @override
  String get auditReportTitle => 'ఆడిట్ నివేదిక';

  @override
  String get noLogsExport => 'ఎగుమతి చేయడానికి లాగ్‌లు లేవు';

  @override
  String exportFailed(Object error) {
    return 'విఫలమైంది: $error';
  }

  @override
  String get startDate => 'ప్రారంభ తేదీ';

  @override
  String get endDate => 'ముగింపు తేదీ';

  @override
  String get userIdLabel => 'యూజర్ ID';

  @override
  String get tableLabel => 'పట్టిక';

  @override
  String get noAuditLogs => 'లాగ్‌లు లేవు';

  @override
  String changedFields(String fields) {
    return 'మార్పులు: $fields';
  }

  @override
  String beforeVal(String val) {
    return 'ముందు: $val';
  }

  @override
  String afterVal(String val) {
    return 'తర్వాత: $val';
  }

  @override
  String get addIngredient => 'Add Ingredient';

  @override
  String get noIngredientsFound => 'No ingredients found';
}
