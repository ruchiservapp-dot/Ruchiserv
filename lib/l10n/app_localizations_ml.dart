// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Malayalam (`ml`).
class AppLocalizationsMl extends AppLocalizations {
  AppLocalizationsMl([String locale = 'ml']) : super(locale);

  @override
  String get appTitle => 'RuchiServ';

  @override
  String get signInContinue => 'തുടരാൻ ലോഗിൻ ചെയ്യുക';

  @override
  String get firmId => 'ഫേം ഐഡി';

  @override
  String get enterFirmId => 'ഫേം ഐഡി നൽകുക';

  @override
  String get mobileNumber => 'മൊബൈൽ നമ്പർ';

  @override
  String get enterMobile => 'മൊബൈൽ നമ്പർ നൽകുക';

  @override
  String get password => 'പാസ്‌വേഡ്';

  @override
  String get enterPassword => 'പാസ്‌വേഡ് നൽകുക';

  @override
  String get loginButton => 'ലോഗിൻ';

  @override
  String get enableBiometricLogin => 'ബയോമെട്രിക് ലോഗിൻ പ്രവർത്തനക്ഷമമാക്കുക';

  @override
  String get enableBiometricPrompt =>
      'അടുത്ത തവണ വേഗത്തിൽ ലോഗിൻ ചെയ്യുന്നതിന് ബയോമെട്രിക് ഓതന്റിക്കേഷൻ ഉപയോഗിക്കണോ?';

  @override
  String get notNow => 'ഇപ്പോൾ വേണ്ട';

  @override
  String get enable => 'എനേബിൾ ചെയ്യുക';

  @override
  String get biometricEnabled => 'ബയോമെട്രിക് ലോഗിൻ പ്രവർത്തനക്ഷമമാക്കി!';

  @override
  String failedEnableBiometric(String error) {
    return 'ബയോമെട്രിക്സ് പ്രവർത്തനക്ഷമമാക്കുന്നതിൽ പരാജയപ്പെട്ടു: $error';
  }

  @override
  String get biometricNotAllowed =>
      'ബയോമെട്രിക് ലോഗിൻ അനുവദനീയമല്ല. ദയവായി ഓൺലൈനായി ലോഗിൻ ചെയ്യുക.';

  @override
  String biometricFailed(String error) {
    return 'ബയോമെട്രിക് പരാജയപ്പെട്ടു: $error';
  }

  @override
  String get subscription => 'സബ്സ്ക്രിപ്ഷൻ';

  @override
  String get subscriptionExpired =>
      'നിങ്ങളുടെ സബ്സ്ക്രിപ്ഷൻ കാലാവധി കഴിഞ്ഞു. തുടരാൻ പുതുക്കുക.';

  @override
  String subscriptionExpiresIn(int days) {
    return 'നിങ്ങളുടെ സബ്സ്ക്രിപ്ഷൻ $days ദിവസത്തിനുള്ളിൽ അവസാനിക്കും. ദയവായി പുതുക്കുക.';
  }

  @override
  String get ok => 'ശരി';

  @override
  String loginError(String error) {
    return 'ലോഗിൻ പിശക്: $error';
  }

  @override
  String get register => 'രജിസ്റ്റർ';

  @override
  String get forgotPassword => 'പാസ്‌വേഡ് മറന്നോ?';

  @override
  String get invalidCredentials => 'തെറ്റായ വിവരങ്ങൾ.';

  @override
  String get offlineLoginNotAllowed =>
      'ഓഫ്‌ലൈൻ ലോഗിൻ അനുവദനീയമല്ല. ദയവായി ഇൻ്റർനെറ്റുമായി ബന്ധിപ്പിക്കുക.';

  @override
  String get mainMenuTitle => 'മെനു';

  @override
  String get moduleOrders => 'ഓർഡറുകൾ';

  @override
  String get moduleOperations => 'ഓപ്പറേഷൻസ്';

  @override
  String get moduleInventory => 'ഇൻവെന്ററി';

  @override
  String get moduleFinance => 'സാമ്പത്തികം';

  @override
  String get moduleReports => 'റിപ്പോർട്ടുകൾ';

  @override
  String get moduleSettings => 'ക്രമീകരണങ്ങൾ';

  @override
  String get moduleAttendance => 'ഹാജർ';

  @override
  String get noModulesAvailable => 'മൊഡ്യൂളുകളൊന്നും ലഭ്യമല്ല';

  @override
  String get contactAdministrator => 'അഡ്മിനിസ്ട്രേറ്ററെ ബന്ധപ്പെടുക';

  @override
  String get firmProfile => 'ഫേം പ്രൊഫൈൽ';

  @override
  String get viewUpdateFirm => 'വിശദാംശങ്ങൾ കാണുക/പുതുക്കുക';

  @override
  String get userProfile => 'ഉപഭോക്തൃ പ്രൊഫൈൽ';

  @override
  String get manageLoginPrefs => 'ക്രമീകരണങ്ങൾ നിയന്ത്രിക്കുക';

  @override
  String get manageUsers => 'ഉപയോക്താക്കൾ';

  @override
  String get manageUsersSubtitle => 'ഉപയോക്താക്കളെ ചേർക്കുക/നിയന്ത്രിക്കുക';

  @override
  String get authMobiles => 'അംഗീകൃത മൊബൈലുകൾ';

  @override
  String get authMobilesSubtitle => 'മൊബൈൽ നമ്പറുകൾ നിയന്ത്രിക്കുക';

  @override
  String get paymentSettings => 'പേയ്മെന്റ് ക്രമീകരണങ്ങൾ';

  @override
  String get paymentSettingsSubtitle => 'ഗേറ്റ്‌വേകൾ കോൺഫിഗർ ചെയ്യുക';

  @override
  String get generalSettings => 'പൊതുവായ ക്രമീകരണങ്ങൾ';

  @override
  String get generalSettingsSubtitle => 'തീം, അറിയിപ്പുകൾ, സുരക്ഷ';

  @override
  String get vehicleMaster => 'വാഹനങ്ങൾ';

  @override
  String get vehicleMasterSubtitle => 'വാഹനങ്ങൾ നിയന്ത്രിക്കുക';

  @override
  String get utensilMaster => 'പാത്രങ്ങൾ';

  @override
  String get utensilMasterSubtitle => 'പാത്രങ്ങൾ നിയന്ത്രിക്കുക';

  @override
  String get backupAWS => 'AWS ബാക്കപ്പ്';

  @override
  String get backupSubtitle => 'ക്ലൗഡിലേക്ക് അപ്‌ലോഡ് ചെയ്യുക';

  @override
  String get auditLogs => 'ഓഡിറ്റ് ലോഗുകൾ';

  @override
  String get auditLogsSubtitle => 'ലോഗുകൾ പരിശോധിക്കുക';

  @override
  String get aboutApp => 'ആപ്പിനെക്കുറിച്ച്';

  @override
  String get logout => 'ലോഗൗട്ട്';

  @override
  String get selectLanguage => 'ഭാഷ തിരഞ്ഞെടുക്കുക';

  @override
  String get attendanceTitle => 'എന്റെ ഹാജർ';

  @override
  String get noStaffRecord => 'സ്റ്റാഫ് റെക്കോർഡ് ലഭ്യമല്ല';

  @override
  String get mobileNotLinked =>
      'നിങ്ങളുടെ മൊബൈൽ നമ്പർ ഒരു സ്റ്റാഫ് റെക്കോർഡുമായും ലിങ്ക് ചെയ്തിട്ടില്ല.\nദയവായി അഡ്മിനിസ്ട്രേറ്ററെ ബന്ധപ്പെടുക.';

  @override
  String get checkingLocation => 'ലൊക്കേഷൻ പരിശോധിക്കുന്നു...';

  @override
  String get punchIn => 'പഞ്ച് ഇൻ';

  @override
  String get punchOut => 'പഞ്ച് ഔട്ട്';

  @override
  String get punching => 'പഞ്ചിംഗ്...';

  @override
  String get readyToPunchIn => 'പഞ്ച് ഇൻ ചെയ്യാൻ തയ്യാറാണ്';

  @override
  String workingSince(String time) {
    return '$time മുതൽ ജോലി ചെയ്യുന്നു';
  }

  @override
  String get todayShiftCompleted => 'ഇന്നത്തെ ഷിഫ്റ്റ് പൂർത്തിയായി';

  @override
  String elapsedTime(int hours, int minutes) {
    return '$hours മണിക്കൂർ $minutes മിനിറ്റ് കഴിഞ്ഞു';
  }

  @override
  String get todayDetails => 'ഇന്നത്തെ വിവരങ്ങൾ';

  @override
  String get punchedIn => 'പഞ്ച് ഇൻ ചെയ്തു';

  @override
  String get punchedOut => 'പഞ്ച് ഔട്ട് ചെയ്തു';

  @override
  String get location => 'സ്ഥലം';

  @override
  String get withinKitchen => 'അടുക്കളയ്ക്കുള്ളിൽ';

  @override
  String get outsideKitchen => 'അടുക്കളയ്ക്ക് പുറത്ത്';

  @override
  String get punchSuccess => '✅ വിജയകരമായി പഞ്ച് ഇൻ ചെയ്തു!';

  @override
  String get punchWarning => '⚠️ പഞ്ച് ഇൻ ചെയ്തു (അടുക്കളയ്ക്ക് പുറത്ത്)';

  @override
  String punchOutSuccess(String hours) {
    return '✅ പഞ്ച് ഔട്ട് ചെയ്തു - $hours മണിക്കൂർ';
  }

  @override
  String get refresh => 'പുതുക്കുക';

  @override
  String get loading => 'ലോഡ് ചെയ്യുന്നു...';

  @override
  String get ordersCalendarTitle => 'ഓർഡർ കലണ്ടർ';

  @override
  String get openSystemCalendar => 'സിസ്റ്റം കലണ്ടർ തുറക്കുക';

  @override
  String get utilizationLow => 'കുറവ് (<50%)';

  @override
  String get utilizationMed => 'ഇടത്തരം (50-90%)';

  @override
  String get utilizationHigh => 'കൂടുതൽ (>90%)';

  @override
  String get editOrder => 'ഓർഡർ എഡിറ്റ് ചെയ്യുക';

  @override
  String get addOrder => 'ഓർഡർ ചേർക്കുക';

  @override
  String dateLabel(String date) {
    return 'തീയതി';
  }

  @override
  String totalPax(int pax) {
    return 'ആകെ പാക്സ്: $pax';
  }

  @override
  String get deliveryTime => 'വിതരണ സമയം';

  @override
  String get tapToSelectTime => 'സമയം തിരഞ്ഞെടുക്കാൻ ടാപ്പ് ചെയ്യുക';

  @override
  String get customerName => 'ഉപഭോക്താവിന്റെ പേര്';

  @override
  String get digitsOnly => 'അക്കങ്ങൾ മാത്രം';

  @override
  String get mobileLengthError => 'കൃത്യം 10 അക്കങ്ങൾ വേണം';

  @override
  String get mealType => 'ഭക്ഷണ തരം';

  @override
  String get foodType => 'ഭക്ഷണം';

  @override
  String get menuItems => 'മെനു ഇനങ്ങൾ';

  @override
  String get addItem => 'ഇനം ചേർക്കുക';

  @override
  String get subtotal => 'ആകെ തുക (₹)';

  @override
  String get discPercent => 'കിഴിവ് %';

  @override
  String get dishTotal => 'ഭക്ഷണ ആകെ തുക:';

  @override
  String get serviceAndCounterSetup => 'സർവീസ് & കൗണ്ടർ സെറ്റപ്പ്';

  @override
  String get serviceRequiredQuestion => 'സർവീസ് ആവശ്യമുണ്ടോ?';

  @override
  String get serviceType => 'സർവീസ് തരം: ';

  @override
  String get countersCount => 'കൗണ്ടറുകളുടെ എണ്ണം';

  @override
  String get ratePerStaff => 'നിരക്ക്/സ്റ്റാഫ് (₹)';

  @override
  String get staffRequired => 'ആവശ്യമായ സ്റ്റാഫ്';

  @override
  String costWithRupee(String cost) {
    return 'ചെലവ്: ₹$cost';
  }

  @override
  String get counterSetupNeeded => 'കൗണ്ടർ സെറ്റപ്പ് ആവശ്യമുണ്ടോ?';

  @override
  String get ratePerCounter => 'നിരക്ക്/കൗണ്ടർ (₹)';

  @override
  String counterCostWithRupee(String cost) {
    return 'കൗണ്ടർ ചെലവ്: ₹$cost';
  }

  @override
  String discountWithPercent(String percent) {
    return 'കിഴിവ് ($percent%):';
  }

  @override
  String get serviceCost => 'സർവീസ് ചെലവ്:';

  @override
  String get counterSetup => 'കൗണ്ടർ സെറ്റപ്പ്:';

  @override
  String get grandTotal => 'ആകെ തുക:';

  @override
  String get notes => 'കുറിപ്പുകൾ';

  @override
  String get saveOrder => 'ഓർഡർ സേവ് ചെയ്യുക';

  @override
  String get orderSaved => '✅ ഓർഡർ സേവ് ചെയ്തു';

  @override
  String saveOrderError(String error) {
    return 'ഓർഡർ സേവ് ചെയ്യുന്നതിൽ പിശക്: $error';
  }

  @override
  String get typeDishName => 'വിഭവത്തിന്റെ പേര് ടൈപ്പ് ചെയ്യുക';

  @override
  String get rate => 'നിരക്ക്';

  @override
  String get qty => 'എണ്ണം';

  @override
  String get cost => 'ചെലവ്';

  @override
  String get required => 'നിർബന്ധം';

  @override
  String get resetCalculation => 'കണക്കുകൂട്ടൽ റീസെറ്റ് ചെയ്യുക';

  @override
  String get breakfast => 'പ്രഭാതഭക്ഷണം';

  @override
  String get lunch => 'ഉച്ചഭക്ഷണം';

  @override
  String get dinner => 'അത്താഴം';

  @override
  String get snacksOthers => 'ലഘുഭക്ഷണം/മറ്റുള്ളവ';

  @override
  String get veg => 'വെജ്';

  @override
  String get nonVeg => 'നോൺ-വെജ്';

  @override
  String failedLoadOrders(String error) {
    return 'ഓർഡറുകൾ ലോഡ് ചെയ്യുന്നതിൽ പരാജയപ്പെട്ടു: $error';
  }

  @override
  String errorLoadingOrders(String error) {
    return 'ഓർഡറുകൾ ലോഡ് ചെയ്യുന്നതിൽ പിശക്: $error';
  }

  @override
  String get cannotEditPastOrders => 'കഴിഞ്ഞ ഓർഡറുകൾ എഡിറ്റ് ചെയ്യാൻ കഴിയില്ല.';

  @override
  String get cannotDeletePastOrders =>
      'കഴിഞ്ഞ ഓർഡറുകൾ ഡിലീറ്റ് ചെയ്യാൻ കഴിയില്ല.';

  @override
  String get deleteOrderTitle => 'ഓർഡർ ഡിലീറ്റ് ചെയ്യണോ?';

  @override
  String get deleteOrderConfirm =>
      'ഇത് ലോക്കൽ ആയി നീക്കം ചെയ്യും. (ഓൺലൈൻ ആകുമ്പോൾ സിങ്ക് ആകും)';

  @override
  String get cancel => 'റദ്ദാക്കുക';

  @override
  String get delete => 'ഡിലീറ്റ്';

  @override
  String get confirm => 'സ്ഥിരീകരിക്കുക';

  @override
  String get requiredField => 'നിർബന്ധം';

  @override
  String error(String error) {
    return 'പിശക്: $error';
  }

  @override
  String get orderDeleted => 'ഓർഡർ ഡിലീറ്റ് ചെയ്തു';

  @override
  String errorDeletingOrder(String error) {
    return 'ഓർഡർ ഡിലീറ്റ് ചെയ്യുന്നതിൽ പിശക്: $error';
  }

  @override
  String ordersCount(int count) {
    return '$count ഓർഡറുകൾ';
  }

  @override
  String get noLocation => 'ലൊക്കേഷൻ ഇല്ല';

  @override
  String get unnamed => 'പേരില്ലാത്ത';

  @override
  String ordersDateTitle(String date) {
    return 'ഓർഡറുകൾ - $date';
  }

  @override
  String get dishSummary => 'വിഭവങ്ങളുടെ സംഗ്രഹം';

  @override
  String get retry => 'വീണ്ടും ശ്രമിക്കുക';

  @override
  String get noOrdersFound => 'ഈ തീയതിയിൽ ഓർഡറുകളില്ല';

  @override
  String vegCount(int count) {
    return 'വെജ്: $count';
  }

  @override
  String nonVegCount(int count) {
    return 'നോൺ-വെജ്: $count';
  }

  @override
  String totalCount(int count) {
    return 'ആകെ: $count';
  }

  @override
  String failedLoadSummary(String error) {
    return 'സംഗ്രഹം ലോഡ് ചെയ്യുന്നതിൽ പരാജയപ്പെട്ടു: $error';
  }

  @override
  String errorLoadingSummary(String error) {
    return 'സംഗ്രഹം ലോഡ് ചെയ്യുന്നതിൽ പിശക്: $error';
  }

  @override
  String summaryDateTitle(String date) {
    return 'സംഗ്രഹം - $date';
  }

  @override
  String get noDishesFound => 'ഈ തീയതിയിൽ വിഭവങ്ങളൊന്നും കണ്ടെത്തിയില്ല';

  @override
  String get unnamedDish => 'പേരില്ലാത്ത വിഭവം';

  @override
  String qtyWithCount(int count) {
    return 'എണ്ണം: $count';
  }

  @override
  String get kitchenView => 'അടുക്കള';

  @override
  String get dispatchView => 'ഡിസ്പാച്ച്';

  @override
  String get punchInOut => 'പഞ്ച് ഇൻ/ഔട്ട്';

  @override
  String get staffManagement => 'ജീവനക്കാരുടെ മാനേജ്മെന്റ്';

  @override
  String get adminOnly => 'അഡ്മിൻ മാത്രം';

  @override
  String get restrictedToAdmins => '⛔ ഇത് അഡ്മിനുകൾക്ക് മാത്രം';

  @override
  String get utensils => 'പാത്രങ്ങൾ';

  @override
  String get kitchenOperations => 'അടുക്കള പ്രവർത്തനങ്ങൾ';

  @override
  String get ordersView => 'ഓർഡറുകൾ';

  @override
  String get productionQueue => 'പ്രൊഡക്ഷൻ ക്യൂ';

  @override
  String get ready => 'തയ്യാറാണ്';

  @override
  String get other => 'മറ്റുള്ളവ';

  @override
  String get internalKitchen => 'ഇന്റേണൽ കിച്ചൺ';

  @override
  String get subcontract => 'സബ് കോൺട്രാക്ട്';

  @override
  String get liveCounter => 'ലൈവ് കൗണ്ടർ';

  @override
  String get prepIngredients => '🔥 ചേരുവകൾ തയ്യാറാക്കുക';

  @override
  String get live => 'ലൈവ്';

  @override
  String get prep => 'തയ്യാറെടുപ്പ്';

  @override
  String get start => 'തുടങ്ങുക';

  @override
  String get prepping => 'തയ്യാറാക്കുന്നു';

  @override
  String get inQueue => 'ക്യൂവിൽ';

  @override
  String get assignEdit => 'ഏൽപ്പിക്കുക / എഡിറ്റ്';

  @override
  String get productionSettings => 'പ്രൊഡക്ഷൻ ക്രമീകരണങ്ങൾ';

  @override
  String get noItemsInQueue => 'ക്യൂവിൽ ഇനങ്ങൾ ഇല്ല';

  @override
  String get done => 'പൂർത്തിയായി';

  @override
  String get noRecipeDefined => 'റെസിപ്പി ലഭ്യമല്ല';

  @override
  String get ingredientsRequired => '📋 ആവശ്യമായ ചേരുവകൾ:';

  @override
  String get noReadyItems => 'തയ്യാറായ ഇനങ്ങൾ ഇല്ല';

  @override
  String get returnItem => 'തിരികെ';

  @override
  String paxLabel(int count) {
    return 'പാക്സ്: $count';
  }

  @override
  String locLabel(String location) {
    return 'സ്ഥലം: $location';
  }

  @override
  String get na => 'N/A';

  @override
  String get noOrdersForDispatch => 'ഡിസ്പാച്ചിനായി ഓർഡറുകളില്ല';

  @override
  String get createDispatch => 'ഡിസ്പാച്ച് സൃഷ്ടിക്കുക';

  @override
  String get dispatchDetails => 'ഡിസ്പാച്ച് വിവരങ്ങൾ';

  @override
  String get driverName => 'ഡ്രൈവറുടെ പേര്';

  @override
  String get vehicleNumber => 'വാഹന നമ്പർ';

  @override
  String get noPendingDispatches => 'Pending ഡിസ്പാച്ചുകൾ ഇല്ല!';

  @override
  String get tapToAddDispatch => '+ ബട്ടൺ ടാപ്പ് ചെയ്ത് ഡിസ്പാച്ച് ചേർക്കുക.';

  @override
  String orderFor(String name) {
    return 'ഓർഡർ: $name';
  }

  @override
  String driverWithVehicle(String driver, String vehicle) {
    return 'ഡ്രൈവർ: $driver ($vehicle)';
  }

  @override
  String get statusPending => 'Pending';

  @override
  String get statusDispatched => 'അയച്ചു (Dispatched)';

  @override
  String get statusDelivered => 'ലഭിച്ചു (Delivered)';

  @override
  String failedUpdateStatus(String error) {
    return 'സ്റ്റാറ്റസ് മാറ്റുന്നതിൽ പരാജയപ്പെട്ടു: $error';
  }

  @override
  String get payroll => 'ശമ്പളം';

  @override
  String get staff => 'ജീവനക്കാർ';

  @override
  String get today => 'ഇന്ന്';

  @override
  String get noStaffMembers => 'ജീവനക്കാർ ഇല്ല';

  @override
  String get tapToAddStaff => '+ ടാപ്പ് ചെയ്ത് ജീവനക്കാരെ ചേർക്കുക';

  @override
  String get unknown => 'അജ്ഞാതം';

  @override
  String get noMobile => 'മൊബൈൽ ഇല്ല';

  @override
  String get permanent => 'സ്ഥിരം';

  @override
  String get dailyWage => 'ദിവസ വേതനം';

  @override
  String get contractor => 'കരാർ';

  @override
  String get alreadyPunchedIn => 'ഇന്ന് നേരത്തെ പഞ്ച് ഇൻ ചെയ്തു!';

  @override
  String get couldNotGetLocation => 'ലൊക്കേഷൻ ലഭിക്കുന്നില്ല';

  @override
  String get punchedInGeo => '✓ പഞ്ച് ഇൻ ചെയ്തു (ലൊക്കേഷൻ പരിധിക്കുള്ളിൽ)';

  @override
  String get punchedInNoGeo =>
      '⚠️ പഞ്ച് ഇൻ ചെയ്തു (ലൊക്കേഷൻ പരിധിക്ക് പുറത്ത്)';

  @override
  String punchedOutMsg(String hours, String ot) {
    return 'പഞ്ച് ഔട്ട് - $hours മണിക്കൂർ $ot';
  }

  @override
  String get totalStaff => 'ആകെ ജീവനക്കാർ';

  @override
  String get present => 'ഹാജർ';

  @override
  String get absent => 'ഹാജരില്ല';

  @override
  String get noAttendanceToday => 'ഇന്ന് ഹാജർ രേഖപ്പെടുത്തിയിട്ടില്ല';

  @override
  String get workingStatus => 'ജോലി ചെയ്യുന്നു';

  @override
  String get otLabel => 'OT';

  @override
  String get addStaff => 'ജീവനക്കാരെ ചേർക്കുക';

  @override
  String get staffDetails => 'ജീവനക്കാരുടെ വിവരങ്ങൾ';

  @override
  String tapToPhoto(String action) {
    return 'ഫോട്ടോ $action ടാപ്പ് ചെയ്യുക';
  }

  @override
  String get basicInfo => 'അടിസ്ഥാന വിവരങ്ങൾ';

  @override
  String get fullName => 'പൂർണ്ണമായ പേര് *';

  @override
  String get roleDesignation => 'തസ്തിക';

  @override
  String get staffType => 'തരം';

  @override
  String get email => 'ഇമെയിൽ';

  @override
  String get salaryRates => 'ശമ്പള നിരക്കുകൾ';

  @override
  String get monthlySalary => 'മാസ ശമ്പളം (₹)';

  @override
  String get payoutFrequency => 'ശമ്പളം നൽകുന്ന രീതി';

  @override
  String get dailyWageLabel => 'ദിവസ വേതനം (₹)';

  @override
  String get hourlyRate => 'മണിക്കൂർ നിരക്ക് (₹)';

  @override
  String get bankIdDetails => 'ബാങ്ക് & ഐഡി വിവരങ്ങൾ';

  @override
  String get bankName => 'ബാങ്ക് പേര്';

  @override
  String get accountNumber => 'അക്കൗണ്ട് നമ്പർ';

  @override
  String get ifscCode => 'IFSC കോഡ്';

  @override
  String get aadharNumber => 'ആധാർ നമ്പർ';

  @override
  String get emergencyContact => 'അടിയന്തിര കോൺടാക്റ്റ്';

  @override
  String get contactName => 'പേര്';

  @override
  String get contactNumber => 'നമ്പർ';

  @override
  String get address => 'വിലാസം';

  @override
  String get addStaffBtn => 'ജീവനക്കാരെ ചേർക്കുക';

  @override
  String get saveChanges => 'മാറ്റങ്ങൾ സേവ് ചെയ്യുക';

  @override
  String get advances => 'അഡ്വാൻസ്';

  @override
  String get attendance => 'ഹാജർ';

  @override
  String get totalAdvances => 'ആകെ അഡ്വാൻസ്';

  @override
  String get pendingDeduction => 'തിരിച്ചടയ്ക്കാൻ ഉള്ളത്';

  @override
  String get addAdvance => 'അഡ്വാൻസ് നൽകുക';

  @override
  String get noAdvances => 'അഡ്വാൻസുകൾ ഇല്ല';

  @override
  String get deducted => 'തിരിച്ചുപിടിച്ചു';

  @override
  String get pending => 'തീർപ്പാക്കാത്തവ';

  @override
  String reason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get deleteStaff => 'ജീവനക്കാരെ നീക്കം ചെയ്യുക';

  @override
  String get deleteStaffConfirm =>
      'ഈ ജീവനക്കാരനെ നീക്കം ചെയ്യണോ? ഇത് തിരിച്ചെടുക്കാനാവില്ല.';

  @override
  String get staffDeleted => 'ജീവനക്കാരനെ നീക്കം ചെയ്തു';

  @override
  String get staffAdded => 'ജീവനക്കാരനെ ചേർത്തു!';

  @override
  String get staffUpdated => 'വിവരങ്ങൾ പുതുക്കി!';

  @override
  String get selectPhoto => 'ഫോട്ടോ തിരഞ്ഞെടുക്കുക';

  @override
  String get camera => 'ക്യാമറ';

  @override
  String get gallery => 'ഗാലറി';

  @override
  String get photoSelectedWeb => 'ഫോട്ടോ തിരഞ്ഞെടുത്തു';

  @override
  String get photoUpdated => 'ഫോട്ടോ പുതുക്കി';

  @override
  String get amountRupee => 'തുക (₹)';

  @override
  String get staffPayroll => 'ശമ്പളം';

  @override
  String get basePay => 'അടിസ്ഥാന ശമ്പളം';

  @override
  String get otPay => 'ഓവർടൈം വേതനം';

  @override
  String get netPay => 'ആകെ നൽകേണ്ട തുക';

  @override
  String get noStaffData => 'ജീവനക്കാരുടെ വിവരങ്ങളില്ല';

  @override
  String get processPayroll => 'ശമ്പളം കണക്കാക്കുക';

  @override
  String processPayrollConfirm(String name, String date) {
    return '$name-ന്റെ $date-ലെ എല്ലാ അഡ്വാൻസുകളും തിരിച്ചുപിടിച്ചതായി രേഖപ്പെടുത്തണോ?';
  }

  @override
  String payrollProcessed(String name) {
    return '$name-ന്റെ ശമ്പളം കണക്കാക്കി';
  }

  @override
  String get advanceDeduction => 'അഡ്വാൻസ് തിരിച്ചുപിടിക്കൽ';

  @override
  String get netPayable => 'നൽകേണ്ട തുക';

  @override
  String get markAdvancesDeducted => 'തിരിച്ചുപിടിച്ചതായി രേഖപ്പെടുത്തുക';

  @override
  String otMultiplierInfo(String rate) {
    return 'OT ഗുണനം: ${rate}x | 8 മണിക്കൂറിൽ കൂടുതൽ ജോലി ചെയ്താൽ';
  }

  @override
  String get utensilsTracking => 'പാത്രങ്ങളുടെ ട്രാക്കിംഗ്';

  @override
  String get noUtensilsAdded => 'പാത്രങ്ങൾ ചേർത്തിട്ടില്ല';

  @override
  String get addFirstUtensil => 'ആദ്യത്തെ പാത്രം ചേർക്കുക';

  @override
  String get addUtensil => 'പാത്രം ചേർക്കുക';

  @override
  String get utensilName => 'പാത്രത്തിന്റെ പേര്';

  @override
  String get utensilNameHint => 'ഉദാ: പ്ലേറ്റ്, ഗ്ലാസ്';

  @override
  String get totalStock => 'ആകെ സ്റ്റോക്ക്';

  @override
  String get enterQuantity => 'എണ്ണം നൽകുക';

  @override
  String get availableStock => 'ലഭ്യമായ സ്റ്റോക്ക്';

  @override
  String get enterUtensilName => 'പേര് നൽകുക';

  @override
  String get utensilAdded => '✅ പാത്രം ചേർത്തു';

  @override
  String get utensilUpdated => '✅ പാത്രം പുതുക്കി';

  @override
  String get utensilDeleted => 'പാത്രം നീക്കം ചെയ്തു';

  @override
  String editUtensil(String name) {
    return 'എഡിറ്റ്: $name';
  }

  @override
  String get deleteUtensil => 'നീക്കം ചെയ്യണോ?';

  @override
  String deleteUtensilConfirm(String name) {
    return '\"$name\" നീക്കം ചെയ്യണോ?';
  }

  @override
  String get save => 'സേവ്';

  @override
  String get add => 'ചേർക്കുക';

  @override
  String availableCount(int available, int total) {
    return 'ലഭ്യമായത്: $available / $total';
  }

  @override
  String issuedCount(int issued, String percent) {
    return 'നൽകിയത്: $issued ($percent%)';
  }

  @override
  String get inventoryHub => 'ഇൻവെന്ററി ഹബ്';

  @override
  String get ingredients => 'ചേരുവകൾ';

  @override
  String get masterList => 'മാസ്റ്റർ ലിസ്റ്റ്';

  @override
  String get bom => 'BOM';

  @override
  String get recipeMapping => 'റെസിപ്പി മാപ്പിംഗ്';

  @override
  String get mrpRun => 'MRP റൺ';

  @override
  String get calculate => 'കണക്കാക്കുക';

  @override
  String get purchaseOrders => 'പർച്ചേസ് ഓർഡറുകൾ';

  @override
  String get purchaseOrderShort => 'PO';

  @override
  String get trackOrders => 'ട്രാക്ക് ഓർഡറുകൾ';

  @override
  String get suppliers => 'വിതരണക്കാർ';

  @override
  String get vendors => 'കച്ചവടക്കാർ';

  @override
  String get subcontractors => 'സബ് കോൺട്രാക്ടർമാർ';

  @override
  String get kitchens => 'അടുക്കളകൾ';

  @override
  String get ingredientsMaster => 'ചേരുവകൾ മാസ്റ്റർ';

  @override
  String get ingredientName => 'ചേരുവയുടെ പേര്';

  @override
  String get skuBrandOptional => 'SKU / ബ്രാൻഡ് (ഓപ്ഷണൽ)';

  @override
  String get costPerUnit => 'വില (ഒന്നിന് - ₹)';

  @override
  String get category => 'വിഭാഗം';

  @override
  String get unit => 'യൂണിറ്റ്';

  @override
  String get unitKg => 'കിലോഗ്രാം (kg)';

  @override
  String get unitG => 'ഗ്രാം (g)';

  @override
  String get unitL => 'ലിറ്റർ';

  @override
  String get unitMl => 'മില്ലിലിറ്റർ (ml)';

  @override
  String get unitNos => 'എണ്ണം (nos)';

  @override
  String get unitBunch => 'കെട്ട്';

  @override
  String get unitPcs => 'കഷ്ണം (pcs)';

  @override
  String get enterIngredientName => 'ചേരുവയുടെ പേര് നൽകുക';

  @override
  String get ingredientAdded => '✅ ചേരുവ ചേർത്തു';

  @override
  String get editIngredient => 'ചേരുവ എഡിറ്റ് ചെയ്യുക';

  @override
  String get ingredientUpdated => '✅ ചേരുവ പുതുക്കി';

  @override
  String get searchPlaceholder => 'തിരയുക...';

  @override
  String ingredientsCount(int count) {
    return '$count ചേരുവകൾ';
  }

  @override
  String categoriesCount(int count) {
    return '$count വിഭാഗങ്ങൾ';
  }

  @override
  String get catAll => 'എല്ലാം';

  @override
  String get catVegetable => 'പച്ചക്കറി';

  @override
  String get catMeat => 'മാംസം';

  @override
  String get catSeafood => 'കടൽ വിഭവങ്ങൾ';

  @override
  String get catSpice => 'സുഗന്ധവ്യഞ്ജനങ്ങൾ';

  @override
  String get catDairy => 'പാൽ ഉൽപ്പന്നങ്ങൾ';

  @override
  String get catGrain => 'ധാന്യങ്ങൾ';

  @override
  String get catOil => 'എണ്ണ';

  @override
  String get catBeverage => 'പാനീയം';

  @override
  String get catOther => 'മറ്റുള്ളവ';

  @override
  String get bomManagement => 'BOM മാനേജ്മെന്റ്';

  @override
  String get bomInfo => 'ഓരോ വിഭവത്തിനും 100 പേർക്ക് വേണ്ട ചേരുവകൾ';

  @override
  String get searchDishes => 'വിഭവങ്ങൾ തിരയുക...';

  @override
  String get addDishesHint => 'ആദ്യം മെനു മാനേജ്മെന്റിൽ വിഭവങ്ങൾ ചേർക്കുക';

  @override
  String itemsCount(int count) {
    return '$count ഇനങ്ങൾ';
  }

  @override
  String get quantity100Pax => '100 പേർക്കുള്ള അളവ്';

  @override
  String get selectIngredient => 'ചേരുവ തിരഞ്ഞെടുക്കുക';

  @override
  String get selectIngredientHint => 'ചേരുവ തിരഞ്ഞെടുത്ത് അളവ് നൽകുക';

  @override
  String get allIngredientsAdded => 'എല്ലാ ചേരുവകളും ചേർത്തു';

  @override
  String get quantityUpdated => '✅ അളവ് പുതുക്കി';

  @override
  String get ingredientRemoved => 'ചേരുവ നീക്കം ചെയ്തു';

  @override
  String get pax100 => '100 പേർക്ക്';

  @override
  String get noIngredientsAdded => 'ചേരുവകൾ ചേർത്തിട്ടില്ല';

  @override
  String get mrpRunScreenTitle => 'MRP റൺ';

  @override
  String get changeDate => 'തീയതി മാറ്റുക';

  @override
  String get totalOrders => 'ആകെ ഓർഡറുകൾ';

  @override
  String get liveKitchen => 'ലൈവ് കിച്ചൺ';

  @override
  String get subcontracted => 'സബ് കോൺട്രാക്ട്';

  @override
  String get noOrdersForDate => 'തിരഞ്ഞെടുത്ത തീയതിയിൽ ഓർഡറുകളില്ല';

  @override
  String get selectDifferentDate => 'മറ്റൊരു തീയതി തിരഞ്ഞെടുക്കുക';

  @override
  String get runMrp => 'MRP റൺ ചെയ്യുക';

  @override
  String get calculating => 'കണക്കാക്കുന്നു...';

  @override
  String get noOrdersToProcess => 'ഓർഡറുകൾ ഇല്ല';

  @override
  String get venueNotSpecified => 'സ്ഥലം നൽകിയിട്ടില്ല';

  @override
  String get selectSubcontractor => 'സബ് കോൺട്രാക്ടറെ തിരഞ്ഞെടുക്കുക';

  @override
  String get liveKitchenChip => 'ലൈവ് കിച്ചൺ';

  @override
  String get subcontractChip => 'സബ് കോൺട്രാക്ട്';

  @override
  String get mrpOutputTitle => 'MRP ഔട്ട്പുട്ട്';

  @override
  String get noIngredientsCalculated => 'ചേരുവകൾ കണക്കാക്കിയില്ല';

  @override
  String get checkBomDefined => 'BOM ചേർത്തിട്ടുണ്ടോ എന്ന് പരിശോധിക്കുക';

  @override
  String get total => 'ആകെ';

  @override
  String get proceedToAllotment => 'അലോട്ട്മെന്റിലേക്ക് പോകുക';

  @override
  String get allotmentTitle => 'അലോട്ട്മെന്റ്';

  @override
  String get supplierAllotment => 'വിതരണക്കാരുടെ അലോട്ട്മെന്റ്';

  @override
  String get summary => 'സംഗ്രഹം';

  @override
  String get assignIngredientHint => 'ഓരോ ചേരുവയും വിതരണക്കാർക്ക് നൽകുക';

  @override
  String assignedStatus(int assigned, int total) {
    return '$assigned/$total നൽകി';
  }

  @override
  String get supplier => 'വിതരണക്കാരൻ';

  @override
  String get generateAndSendPos => 'PO ജനറേറ്റ് & സെൻഡ്';

  @override
  String posWillBeGenerated(int count) {
    return '$count PO-കൾ ജനറേറ്റ് ചെയ്യപ്പെടും';
  }

  @override
  String get noAllocationsMade => 'അലോക്കേഷനുകൾ നടത്തിയിട്ടില്ല';

  @override
  String get allocateIngredientsFirst => 'ആദ്യം ചേരുവകൾ വിതരണക്കാർക്ക് നൽകുക';

  @override
  String posGeneratedSuccess(int count) {
    return '✅ $count PO-കൾ ജനറേറ്റ് ചെയ്തു';
  }

  @override
  String get catGrocery => 'പലചരക്ക്';

  @override
  String get supplierMaster => 'വിതരണക്കാർ';

  @override
  String get addSupplier => 'വിതരണക്കാരനെ ചേർക്കുക';

  @override
  String get editSupplier => 'വിതരണക്കാരനെ എഡിറ്റ് ചെയ്യുക';

  @override
  String get nameRequired => 'പേര് *';

  @override
  String get mobile => 'മൊബൈൽ';

  @override
  String get gstNumber => 'GST നമ്പർ';

  @override
  String get bankDetails => 'ബാങ്ക് വിവരങ്ങൾ';

  @override
  String get enterSupplierName => 'വിതരണക്കാരന്റെ പേര് നൽകുക';

  @override
  String get supplierUpdated => '✅ വിവരങ്ങൾ പുതുക്കി';

  @override
  String get supplierAdded => '✅ വിതരണക്കാരനെ ചേർത്തു';

  @override
  String get noSuppliersAdded => 'വിതരണക്കാർ ഇല്ല';

  @override
  String get noPhone => 'ഫോൺ ഇല്ല';

  @override
  String get subcontractorMaster => 'സബ് കോൺട്രാക്ടർമാർ';

  @override
  String get editSubcontractor => 'എഡിറ്റ് സബ് കോൺട്രാക്ടർ';

  @override
  String get addSubcontractor => 'സബ് കോൺട്രാക്ടറെ ചേർക്കുക';

  @override
  String get kitchenBusinessName => 'ബിസിനസ് പേര് *';

  @override
  String get mobileRequired => 'മൊബൈൽ *';

  @override
  String get specialization => 'സ്പെഷ്യലൈസേഷൻ';

  @override
  String get specializationHint => 'ഉദാ: ബിരിയാണി, ചൈനീസ്';

  @override
  String get ratePerPax => 'നിരക്ക് (ഒരാൾക്ക് - ₹)';

  @override
  String get enterNameMobile => 'പേരും മൊബൈലും നൽകുക';

  @override
  String get subcontractorUpdated => '✅ വിവരങ്ങൾ പുതുക്കി';

  @override
  String get subcontractorAdded => '✅ സബ് കോൺട്രാക്ടറെ ചേർത്തു';

  @override
  String get noSubcontractorsAdded => 'സബ് കോൺട്രാക്ടർമാർ ഇല്ല';

  @override
  String get perPax => 'ഒരാൾക്ക്';

  @override
  String get purchaseOrdersTitle => 'പർച്ചേസ് ഓർഡറുകൾ';

  @override
  String get statusSent => 'അയച്ചു';

  @override
  String get statusViewed => 'കണ്ടു';

  @override
  String get statusAccepted => 'സ്വീകരിച്ചു';

  @override
  String purchaseOrdersCount(int count) {
    return '$count പർച്ചേസ് ഓർഡറുകൾ';
  }

  @override
  String get noPurchaseOrders => 'പർച്ചേസ് ഓർഡറുകൾ ഇല്ല';

  @override
  String get runMrpHint => 'PO ലഭിക്കാൻ MRP റൺ ചെയ്യുക';

  @override
  String get dispatchTitle => 'ഡിസ്പാച്ച്';

  @override
  String get tabList => 'ലിസ്റ്റ്';

  @override
  String get tabActive => 'ആക്റ്റീവ്';

  @override
  String get tabReturns => 'റിട്ടേൺസ്';

  @override
  String get tabUnload => 'അൺലോഡ്';

  @override
  String noPendingOrdersDate(String date) {
    return '$date-ൽ Pending ഓർഡറുകൾ ഇല്ല';
  }

  @override
  String get noActiveDispatches => 'ആക്റ്റീവ് ഡിസ്പാച്ചുകൾ ഇല്ല';

  @override
  String get noReturnTracking => 'റിട്ടേൺസ് ഇല്ല';

  @override
  String get noUnloadItems => 'അൺലോഡ് ചെയ്യാൻ ഇനങ്ങൾ ഇല്ല';

  @override
  String get startDispatch => 'ഡിസ്പാച്ച് തുടങ്ങുക';

  @override
  String get waitingForKitchen => 'അടുക്കളയിൽ നിന്ന് ലഭിക്കാൻ കാക്കുന്നു';

  @override
  String get track => 'ട്രാക്ക്';

  @override
  String get verify => 'പരിശോധിക്കുക';

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
  String get qtyLabel => 'എണ്ണം';

  @override
  String get reportsTitle => 'റിപ്പോർട്ടുകൾ';

  @override
  String get periodLabel => 'കാലയളവ്: ';

  @override
  String get day => 'ദിവസം';

  @override
  String get week => 'ആഴ്ച';

  @override
  String get month => 'മാസം';

  @override
  String get year => 'വർഷം';

  @override
  String get orders => 'ഓർഡറുകൾ';

  @override
  String get kitchen => 'അടുക്കള';

  @override
  String get dispatch => 'ഡിസ്പാച്ച്';

  @override
  String get hr => 'ഹ്യൂമൻ റിസോഴ്സ്';

  @override
  String get noDataSelectedPeriod => 'തിരഞ്ഞെടുത്ത കാലയളവിൽ വിവരങ്ങളില്ല';

  @override
  String get revenue => 'വരുമാനം';

  @override
  String get confirmed => 'സ്ഥിരീകരിച്ചവ';

  @override
  String get completed => 'പൂർത്തിയായവ';

  @override
  String get cancelled => 'റദ്ദാക്കിയവ';

  @override
  String get inProgress => 'പുരോഗതിയിൽ';

  @override
  String get delivered => 'വിതരണം ചെയ്തവ';

  @override
  String get inTransit => 'വഴിയിൽ';

  @override
  String get totalDispatches => 'ആകെ ഡിസ്പാച്ചുകൾ';

  @override
  String get hours => 'മണിക്കൂർ';

  @override
  String get overtime => 'ഓവർടൈം';

  @override
  String get staffWithOt => 'ഓവർടൈം ഉള്ള ജീവനക്കാർ';

  @override
  String get totalOt => 'ആകെ ഓവർടൈം';

  @override
  String get noOvertime => 'ഓവർടൈം രേഖപ്പെടുത്തിയിട്ടില്ല';

  @override
  String get financeTitle => 'സാമ്പത്തികം';

  @override
  String get income => 'വരുമാനം';

  @override
  String get expense => 'ചെലവ്';

  @override
  String get netBalance => 'നീക്കിയിരിപ്പ്';

  @override
  String get transactions => 'ഇടപാടുകൾ';

  @override
  String get ledgers => 'ലെഡ്ജറുകൾ';

  @override
  String get export => 'എക്സ്പോർട്ട്';

  @override
  String get recentTransactions => 'സമീപകാല ഇടപാടുകൾ';

  @override
  String get noTransactionsFound => 'ഇടപാടുകളൊന്നും കണ്ടെത്തിയില്ല';

  @override
  String get exportingReport => 'റിപ്പോർട്ട് എക്സ്പോർട്ട് ചെയ്യുന്നു...';

  @override
  String get filterAll => 'എല്ലാം';

  @override
  String get deleteTransactionTitle => 'ഇടപാട് ഡിലീറ്റ് ചെയ്യണോ?';

  @override
  String get deleteTransactionContent => 'ഇത് തിരുത്താനാവില്ല.';

  @override
  String get customers => 'ഉപഭോക്താക്കൾ';

  @override
  String get comingSoon => 'ഉടൻ വരുന്നു';

  @override
  String get addIncome => 'വരുമാനം ചേർക്കുക';

  @override
  String get addExpense => 'ചെലവ് ചേർക്കുക';

  @override
  String get amountLabel => 'തുക';

  @override
  String get categoryLabel => 'വിഭാഗം';

  @override
  String get paymentModeLabel => 'പേയ്മെന്റ് രീതി';

  @override
  String get descriptionLabel => 'വിവരണം / കുറിപ്പുകൾ';

  @override
  String get saveTransaction => 'ഇടപാട് സേവ് ചെയ്യുക';

  @override
  String get enterAmount => 'തുക നൽകുക';

  @override
  String get invalidAmount => 'തെറ്റായ തുക';

  @override
  String get transactionSaved => 'ഇടപാട് സേവ് ചെയ്തു';

  @override
  String get collectPayment => 'പേയ്മെന്റ് സ്വീകരിക്കുക';

  @override
  String get selectPaymentMethod => 'പേയ്മെന്റ് രീതി തിരഞ്ഞെടുക്കുക';

  @override
  String get upiRazorpay => 'UPI (Razorpay)';

  @override
  String get cardRazorpay => 'കാർഡ് (Razorpay)';

  @override
  String get cash => 'Cash';

  @override
  String get paymentSuccessful => 'പേയ്മെന്റ് വിജയകരം!';

  @override
  String paymentReceivedMsg(String amount, int orderId) {
    return '$amount രൂപ പേയ്മെന്റ് ലഭിച്ചു (ഓർഡർ #$orderId)';
  }

  @override
  String paymentFailed(Object error) {
    return 'പേയ്മെന്റ് പരാജയപ്പെട്ടു: $error';
  }

  @override
  String get chooseSubscription => 'സബ്സ്ക്രിപ്ഷൻ പ്ലാൻ തിരഞ്ഞെടുക്കുക';

  @override
  String get selectStartPlan => 'പ്ലാൻ തിരഞ്ഞെടുക്കുക';

  @override
  String payBtn(String amount) {
    return '$amount രൂപ അടയ്ക്കുക';
  }

  @override
  String get subscriptionActivated => 'സബ്സ്ക്രിപ്ഷൻ ആക്റ്റിവേറ്റ് ചെയ്തു!';

  @override
  String planActiveUntil(String date) {
    return 'നിങ്ങളുടെ പ്ലാൻ $date വരെ ആക്റ്റീവ് ആണ്.';
  }

  @override
  String get continueBtn => 'തുടരുക';

  @override
  String get auditReportTitle => 'ഓഡിറ്റ് റിപ്പോർട്ട്';

  @override
  String get noLogsExport => 'എക്സ്പോർട്ട് ചെയ്യാൻ ലോഗുകൾ ഇല്ല';

  @override
  String exportFailed(Object error) {
    return 'എക്സ്പോർട്ട് പരാജയപ്പെട്ടു: $error';
  }

  @override
  String get startDate => 'തുടങ്ങുന്ന തീയതി';

  @override
  String get endDate => 'അവസാനിക്കുന്ന തീയതി';

  @override
  String get userIdLabel => 'യൂസർ ഐഡി';

  @override
  String get tableLabel => 'ടേബിൾ';

  @override
  String get noAuditLogs => 'ഓഡിറ്റ് ലോഗുകൾ കണ്ടെത്തിയില്ല';

  @override
  String changedFields(String fields) {
    return 'മാറ്റം: $fields';
  }

  @override
  String beforeVal(String val) {
    return 'മുമ്പ്: $val';
  }

  @override
  String afterVal(String val) {
    return 'ശേഷം: $val';
  }

  @override
  String get addIngredient => 'Add Ingredient';

  @override
  String get noIngredientsFound => 'No ingredients found';
}
