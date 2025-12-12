import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_kn.dart';
import 'app_localizations_ml.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ml'),
    Locale('ta'),
    Locale('kn'),
    Locale('hi'),
    Locale('te')
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'RuchiServ'**
  String get appTitle;

  /// No description provided for @signInContinue.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get signInContinue;

  /// No description provided for @firmId.
  ///
  /// In en, this message translates to:
  /// **'Firm ID'**
  String get firmId;

  /// No description provided for @enterFirmId.
  ///
  /// In en, this message translates to:
  /// **'Enter firm ID'**
  String get enterFirmId;

  /// No description provided for @mobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number'**
  String get mobileNumber;

  /// No description provided for @enterMobile.
  ///
  /// In en, this message translates to:
  /// **'Enter mobile'**
  String get enterMobile;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get enterPassword;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'LOGIN'**
  String get loginButton;

  /// No description provided for @enableBiometricLogin.
  ///
  /// In en, this message translates to:
  /// **'Enable Biometric Login'**
  String get enableBiometricLogin;

  /// No description provided for @enableBiometricPrompt.
  ///
  /// In en, this message translates to:
  /// **'Would you like to enable biometric authentication for faster login next time?'**
  String get enableBiometricPrompt;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not Now'**
  String get notNow;

  /// No description provided for @enable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enable;

  /// No description provided for @biometricEnabled.
  ///
  /// In en, this message translates to:
  /// **'Biometric login enabled!'**
  String get biometricEnabled;

  /// No description provided for @failedEnableBiometric.
  ///
  /// In en, this message translates to:
  /// **'Failed to enable biometrics: {error}'**
  String failedEnableBiometric(String error);

  /// No description provided for @biometricNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Biometric login not allowed. Please login online once.'**
  String get biometricNotAllowed;

  /// No description provided for @biometricFailed.
  ///
  /// In en, this message translates to:
  /// **'Biometric failed: {error}'**
  String biometricFailed(String error);

  /// No description provided for @subscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscription;

  /// No description provided for @subscriptionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your subscription has expired. Please renew to continue.'**
  String get subscriptionExpired;

  /// No description provided for @subscriptionExpiresIn.
  ///
  /// In en, this message translates to:
  /// **'Your subscription expires in {days} day(s). Please renew.'**
  String subscriptionExpiresIn(int days);

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @loginError.
  ///
  /// In en, this message translates to:
  /// **'Login error: {error}'**
  String loginError(String error);

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid credentials.'**
  String get invalidCredentials;

  /// No description provided for @offlineLoginNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Offline login not allowed. Please connect to the internet.'**
  String get offlineLoginNotAllowed;

  /// No description provided for @mainMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get mainMenuTitle;

  /// No description provided for @moduleOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get moduleOrders;

  /// No description provided for @moduleOperations.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get moduleOperations;

  /// No description provided for @moduleInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get moduleInventory;

  /// No description provided for @moduleFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get moduleFinance;

  /// No description provided for @moduleReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get moduleReports;

  /// No description provided for @moduleSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get moduleSettings;

  /// No description provided for @moduleAttendance.
  ///
  /// In en, this message translates to:
  /// **'My Attendance'**
  String get moduleAttendance;

  /// No description provided for @noModulesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No modules available'**
  String get noModulesAvailable;

  /// No description provided for @contactAdministrator.
  ///
  /// In en, this message translates to:
  /// **'Contact your administrator'**
  String get contactAdministrator;

  /// No description provided for @firmProfile.
  ///
  /// In en, this message translates to:
  /// **'Firm Profile'**
  String get firmProfile;

  /// No description provided for @viewUpdateFirm.
  ///
  /// In en, this message translates to:
  /// **'View or update your firm details'**
  String get viewUpdateFirm;

  /// No description provided for @userProfile.
  ///
  /// In en, this message translates to:
  /// **'User Profile'**
  String get userProfile;

  /// No description provided for @manageLoginPrefs.
  ///
  /// In en, this message translates to:
  /// **'Manage your login and preferences'**
  String get manageLoginPrefs;

  /// No description provided for @manageUsers.
  ///
  /// In en, this message translates to:
  /// **'Manage Users'**
  String get manageUsers;

  /// No description provided for @manageUsersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add users and set permissions'**
  String get manageUsersSubtitle;

  /// No description provided for @authMobiles.
  ///
  /// In en, this message translates to:
  /// **'Authorized Mobiles'**
  String get authMobiles;

  /// No description provided for @authMobilesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage pre-approved mobile numbers'**
  String get authMobilesSubtitle;

  /// No description provided for @paymentSettings.
  ///
  /// In en, this message translates to:
  /// **'Payment Settings'**
  String get paymentSettings;

  /// No description provided for @paymentSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure payment gateways'**
  String get paymentSettingsSubtitle;

  /// No description provided for @generalSettings.
  ///
  /// In en, this message translates to:
  /// **'General Settings'**
  String get generalSettings;

  /// No description provided for @generalSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme, Notifications, Security'**
  String get generalSettingsSubtitle;

  /// No description provided for @vehicleMaster.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Master'**
  String get vehicleMaster;

  /// No description provided for @vehicleMasterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage fleet vehicles'**
  String get vehicleMasterSubtitle;

  /// No description provided for @utensilMaster.
  ///
  /// In en, this message translates to:
  /// **'Utensil Master'**
  String get utensilMaster;

  /// No description provided for @utensilMasterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage utensils & consumables'**
  String get utensilMasterSubtitle;

  /// No description provided for @backupAWS.
  ///
  /// In en, this message translates to:
  /// **'Backup to AWS'**
  String get backupAWS;

  /// No description provided for @backupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload all data to cloud'**
  String get backupSubtitle;

  /// No description provided for @auditLogs.
  ///
  /// In en, this message translates to:
  /// **'Audit Logs'**
  String get auditLogs;

  /// No description provided for @auditLogsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View and export compliance logs'**
  String get auditLogsSubtitle;

  /// No description provided for @aboutApp.
  ///
  /// In en, this message translates to:
  /// **'About RuchiServ'**
  String get aboutApp;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @attendanceTitle.
  ///
  /// In en, this message translates to:
  /// **'My Attendance'**
  String get attendanceTitle;

  /// No description provided for @noStaffRecord.
  ///
  /// In en, this message translates to:
  /// **'No Staff Record Found'**
  String get noStaffRecord;

  /// No description provided for @mobileNotLinked.
  ///
  /// In en, this message translates to:
  /// **'Your mobile number is not linked to any staff record.\nPlease contact your administrator.'**
  String get mobileNotLinked;

  /// No description provided for @checkingLocation.
  ///
  /// In en, this message translates to:
  /// **'Checking location...'**
  String get checkingLocation;

  /// No description provided for @punchIn.
  ///
  /// In en, this message translates to:
  /// **'PUNCH IN'**
  String get punchIn;

  /// No description provided for @punchOut.
  ///
  /// In en, this message translates to:
  /// **'PUNCH OUT'**
  String get punchOut;

  /// No description provided for @punching.
  ///
  /// In en, this message translates to:
  /// **'Punching...'**
  String get punching;

  /// No description provided for @readyToPunchIn.
  ///
  /// In en, this message translates to:
  /// **'Ready to Punch In'**
  String get readyToPunchIn;

  /// No description provided for @workingSince.
  ///
  /// In en, this message translates to:
  /// **'Working since {time}'**
  String workingSince(String time);

  /// No description provided for @todayShiftCompleted.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Shift Completed'**
  String get todayShiftCompleted;

  /// No description provided for @elapsedTime.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m elapsed'**
  String elapsedTime(int hours, int minutes);

  /// No description provided for @todayDetails.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Details'**
  String get todayDetails;

  /// No description provided for @punchedIn.
  ///
  /// In en, this message translates to:
  /// **'Punched In'**
  String get punchedIn;

  /// No description provided for @punchedOut.
  ///
  /// In en, this message translates to:
  /// **'Punched Out'**
  String get punchedOut;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @withinKitchen.
  ///
  /// In en, this message translates to:
  /// **'Within Kitchen Area'**
  String get withinKitchen;

  /// No description provided for @outsideKitchen.
  ///
  /// In en, this message translates to:
  /// **'Outside Kitchen Area'**
  String get outsideKitchen;

  /// No description provided for @punchSuccess.
  ///
  /// In en, this message translates to:
  /// **'✅ Punched In Successfully!'**
  String get punchSuccess;

  /// No description provided for @punchWarning.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Punched In (Outside Kitchen Area)'**
  String get punchWarning;

  /// No description provided for @punchOutSuccess.
  ///
  /// In en, this message translates to:
  /// **'✅ Punched Out - {hours} hours'**
  String punchOutSuccess(String hours);

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @ordersCalendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Orders Calendar'**
  String get ordersCalendarTitle;

  /// No description provided for @openSystemCalendar.
  ///
  /// In en, this message translates to:
  /// **'Open System Calendar'**
  String get openSystemCalendar;

  /// No description provided for @utilizationLow.
  ///
  /// In en, this message translates to:
  /// **'Low (<50%)'**
  String get utilizationLow;

  /// No description provided for @utilizationMed.
  ///
  /// In en, this message translates to:
  /// **'Med (50-90%)'**
  String get utilizationMed;

  /// No description provided for @utilizationHigh.
  ///
  /// In en, this message translates to:
  /// **'High (>90%)'**
  String get utilizationHigh;

  /// No description provided for @editOrder.
  ///
  /// In en, this message translates to:
  /// **'Edit Order'**
  String get editOrder;

  /// No description provided for @addOrder.
  ///
  /// In en, this message translates to:
  /// **'Add Order'**
  String get addOrder;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String dateLabel(String date);

  /// No description provided for @totalPax.
  ///
  /// In en, this message translates to:
  /// **'Total Pax: {pax}'**
  String totalPax(int pax);

  /// No description provided for @deliveryTime.
  ///
  /// In en, this message translates to:
  /// **'Delivery Time'**
  String get deliveryTime;

  /// No description provided for @tapToSelectTime.
  ///
  /// In en, this message translates to:
  /// **'Tap to select time'**
  String get tapToSelectTime;

  /// No description provided for @customerName.
  ///
  /// In en, this message translates to:
  /// **'Customer Name'**
  String get customerName;

  /// No description provided for @digitsOnly.
  ///
  /// In en, this message translates to:
  /// **'Digits only'**
  String get digitsOnly;

  /// No description provided for @mobileLengthError.
  ///
  /// In en, this message translates to:
  /// **'Must be exactly 10 digits'**
  String get mobileLengthError;

  /// No description provided for @mealType.
  ///
  /// In en, this message translates to:
  /// **'Meal Type'**
  String get mealType;

  /// No description provided for @foodType.
  ///
  /// In en, this message translates to:
  /// **'Food Type'**
  String get foodType;

  /// No description provided for @menuItems.
  ///
  /// In en, this message translates to:
  /// **'Menu Items'**
  String get menuItems;

  /// No description provided for @addItem.
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get addItem;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal (₹)'**
  String get subtotal;

  /// No description provided for @discPercent.
  ///
  /// In en, this message translates to:
  /// **'Disc %'**
  String get discPercent;

  /// No description provided for @dishTotal.
  ///
  /// In en, this message translates to:
  /// **'Dish Total:'**
  String get dishTotal;

  /// No description provided for @serviceAndCounterSetup.
  ///
  /// In en, this message translates to:
  /// **'Service & Counter Setup'**
  String get serviceAndCounterSetup;

  /// No description provided for @serviceRequiredQuestion.
  ///
  /// In en, this message translates to:
  /// **'Service Required?'**
  String get serviceRequiredQuestion;

  /// No description provided for @serviceType.
  ///
  /// In en, this message translates to:
  /// **'Service Type: '**
  String get serviceType;

  /// No description provided for @countersCount.
  ///
  /// In en, this message translates to:
  /// **'No. of Counters'**
  String get countersCount;

  /// No description provided for @ratePerStaff.
  ///
  /// In en, this message translates to:
  /// **'Rate/Staff (₹)'**
  String get ratePerStaff;

  /// No description provided for @staffRequired.
  ///
  /// In en, this message translates to:
  /// **'Staff Required'**
  String get staffRequired;

  /// No description provided for @costWithRupee.
  ///
  /// In en, this message translates to:
  /// **'Cost: ₹{cost}'**
  String costWithRupee(String cost);

  /// No description provided for @counterSetupNeeded.
  ///
  /// In en, this message translates to:
  /// **'Counter Setup Needed?'**
  String get counterSetupNeeded;

  /// No description provided for @ratePerCounter.
  ///
  /// In en, this message translates to:
  /// **'Rate/Counter (₹)'**
  String get ratePerCounter;

  /// No description provided for @counterCostWithRupee.
  ///
  /// In en, this message translates to:
  /// **'Counter Cost: ₹{cost}'**
  String counterCostWithRupee(String cost);

  /// No description provided for @discountWithPercent.
  ///
  /// In en, this message translates to:
  /// **'Discount ({percent}%):'**
  String discountWithPercent(String percent);

  /// No description provided for @serviceCost.
  ///
  /// In en, this message translates to:
  /// **'Service Cost:'**
  String get serviceCost;

  /// No description provided for @counterSetup.
  ///
  /// In en, this message translates to:
  /// **'Counter Setup:'**
  String get counterSetup;

  /// No description provided for @grandTotal.
  ///
  /// In en, this message translates to:
  /// **'GRAND TOTAL:'**
  String get grandTotal;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @saveOrder.
  ///
  /// In en, this message translates to:
  /// **'SAVE ORDER'**
  String get saveOrder;

  /// No description provided for @orderSaved.
  ///
  /// In en, this message translates to:
  /// **'✅ Order saved'**
  String get orderSaved;

  /// No description provided for @saveOrderError.
  ///
  /// In en, this message translates to:
  /// **'Error saving order: {error}'**
  String saveOrderError(String error);

  /// No description provided for @typeDishName.
  ///
  /// In en, this message translates to:
  /// **'Type dish name'**
  String get typeDishName;

  /// No description provided for @rate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get rate;

  /// No description provided for @qty.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get qty;

  /// No description provided for @cost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get cost;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @resetCalculation.
  ///
  /// In en, this message translates to:
  /// **'Reset Calculation'**
  String get resetCalculation;

  /// No description provided for @breakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get breakfast;

  /// No description provided for @lunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get lunch;

  /// No description provided for @dinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get dinner;

  /// No description provided for @snacksOthers.
  ///
  /// In en, this message translates to:
  /// **'Snacks/Others'**
  String get snacksOthers;

  /// No description provided for @veg.
  ///
  /// In en, this message translates to:
  /// **'Veg'**
  String get veg;

  /// No description provided for @nonVeg.
  ///
  /// In en, this message translates to:
  /// **'Non-Veg'**
  String get nonVeg;

  /// No description provided for @failedLoadOrders.
  ///
  /// In en, this message translates to:
  /// **'Failed to load orders: {error}'**
  String failedLoadOrders(String error);

  /// No description provided for @errorLoadingOrders.
  ///
  /// In en, this message translates to:
  /// **'Error loading orders: {error}'**
  String errorLoadingOrders(String error);

  /// No description provided for @cannotEditPastOrders.
  ///
  /// In en, this message translates to:
  /// **'Cannot edit past orders.'**
  String get cannotEditPastOrders;

  /// No description provided for @cannotDeletePastOrders.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete past orders.'**
  String get cannotDeletePastOrders;

  /// No description provided for @deleteOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Order?'**
  String get deleteOrderTitle;

  /// No description provided for @deleteOrderConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will remove the order locally. (Will sync when online)'**
  String get deleteOrderConfirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredField;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String error(String error);

  /// No description provided for @orderDeleted.
  ///
  /// In en, this message translates to:
  /// **'Order deleted (will sync when online)'**
  String get orderDeleted;

  /// No description provided for @errorDeletingOrder.
  ///
  /// In en, this message translates to:
  /// **'Error deleting order: {error}'**
  String errorDeletingOrder(String error);

  /// No description provided for @ordersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} orders'**
  String ordersCount(int count);

  /// No description provided for @noLocation.
  ///
  /// In en, this message translates to:
  /// **'No location'**
  String get noLocation;

  /// No description provided for @unnamed.
  ///
  /// In en, this message translates to:
  /// **'Unnamed'**
  String get unnamed;

  /// No description provided for @ordersDateTitle.
  ///
  /// In en, this message translates to:
  /// **'Orders - {date}'**
  String ordersDateTitle(String date);

  /// No description provided for @dishSummary.
  ///
  /// In en, this message translates to:
  /// **'Dish Summary'**
  String get dishSummary;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @noOrdersFound.
  ///
  /// In en, this message translates to:
  /// **'No orders found for this date'**
  String get noOrdersFound;

  /// No description provided for @vegCount.
  ///
  /// In en, this message translates to:
  /// **'Veg: {count}'**
  String vegCount(int count);

  /// No description provided for @nonVegCount.
  ///
  /// In en, this message translates to:
  /// **'Non-Veg: {count}'**
  String nonVegCount(int count);

  /// No description provided for @totalCount.
  ///
  /// In en, this message translates to:
  /// **'Total: {count}'**
  String totalCount(int count);

  /// No description provided for @failedLoadSummary.
  ///
  /// In en, this message translates to:
  /// **'Failed to load summary: {error}'**
  String failedLoadSummary(String error);

  /// No description provided for @errorLoadingSummary.
  ///
  /// In en, this message translates to:
  /// **'Error loading summary: {error}'**
  String errorLoadingSummary(String error);

  /// No description provided for @summaryDateTitle.
  ///
  /// In en, this message translates to:
  /// **'Summary - {date}'**
  String summaryDateTitle(String date);

  /// No description provided for @noDishesFound.
  ///
  /// In en, this message translates to:
  /// **'No dishes found for this date'**
  String get noDishesFound;

  /// No description provided for @unnamedDish.
  ///
  /// In en, this message translates to:
  /// **'Unnamed dish'**
  String get unnamedDish;

  /// No description provided for @qtyWithCount.
  ///
  /// In en, this message translates to:
  /// **'Qty: {count}'**
  String qtyWithCount(int count);

  /// No description provided for @kitchenView.
  ///
  /// In en, this message translates to:
  /// **'Kitchen View'**
  String get kitchenView;

  /// No description provided for @dispatchView.
  ///
  /// In en, this message translates to:
  /// **'Dispatch View'**
  String get dispatchView;

  /// No description provided for @punchInOut.
  ///
  /// In en, this message translates to:
  /// **'Punch In/Out'**
  String get punchInOut;

  /// No description provided for @staffManagement.
  ///
  /// In en, this message translates to:
  /// **'Staff Management'**
  String get staffManagement;

  /// No description provided for @adminOnly.
  ///
  /// In en, this message translates to:
  /// **'Admin Only'**
  String get adminOnly;

  /// No description provided for @restrictedToAdmins.
  ///
  /// In en, this message translates to:
  /// **'⛔ Staff Management is restricted to Admins'**
  String get restrictedToAdmins;

  /// No description provided for @utensils.
  ///
  /// In en, this message translates to:
  /// **'Utensils'**
  String get utensils;

  /// No description provided for @kitchenOperations.
  ///
  /// In en, this message translates to:
  /// **'Kitchen Operations'**
  String get kitchenOperations;

  /// No description provided for @ordersView.
  ///
  /// In en, this message translates to:
  /// **'Orders View'**
  String get ordersView;

  /// No description provided for @productionQueue.
  ///
  /// In en, this message translates to:
  /// **'Production Queue'**
  String get productionQueue;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @internalKitchen.
  ///
  /// In en, this message translates to:
  /// **'Internal Kitchen'**
  String get internalKitchen;

  /// No description provided for @subcontract.
  ///
  /// In en, this message translates to:
  /// **'Subcontract'**
  String get subcontract;

  /// No description provided for @liveCounter.
  ///
  /// In en, this message translates to:
  /// **'Live Counter'**
  String get liveCounter;

  /// No description provided for @prepIngredients.
  ///
  /// In en, this message translates to:
  /// **'🔥 PREP INGREDIENTS'**
  String get prepIngredients;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get live;

  /// No description provided for @prep.
  ///
  /// In en, this message translates to:
  /// **'Prep'**
  String get prep;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @prepping.
  ///
  /// In en, this message translates to:
  /// **'Prepping'**
  String get prepping;

  /// No description provided for @inQueue.
  ///
  /// In en, this message translates to:
  /// **'In Queue'**
  String get inQueue;

  /// No description provided for @assignEdit.
  ///
  /// In en, this message translates to:
  /// **'Assign / Edit'**
  String get assignEdit;

  /// No description provided for @productionSettings.
  ///
  /// In en, this message translates to:
  /// **'Production Settings'**
  String get productionSettings;

  /// No description provided for @noItemsInQueue.
  ///
  /// In en, this message translates to:
  /// **'No items in production queue'**
  String get noItemsInQueue;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @noRecipeDefined.
  ///
  /// In en, this message translates to:
  /// **'No recipe defined for this dish'**
  String get noRecipeDefined;

  /// No description provided for @ingredientsRequired.
  ///
  /// In en, this message translates to:
  /// **'📋 Ingredients Required:'**
  String get ingredientsRequired;

  /// No description provided for @noReadyItems.
  ///
  /// In en, this message translates to:
  /// **'No ready items'**
  String get noReadyItems;

  /// No description provided for @returnItem.
  ///
  /// In en, this message translates to:
  /// **'Return'**
  String get returnItem;

  /// No description provided for @paxLabel.
  ///
  /// In en, this message translates to:
  /// **'Pax: {count}'**
  String paxLabel(int count);

  /// No description provided for @locLabel.
  ///
  /// In en, this message translates to:
  /// **'Loc: {location}'**
  String locLabel(String location);

  /// No description provided for @na.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get na;

  /// No description provided for @noOrdersForDispatch.
  ///
  /// In en, this message translates to:
  /// **'No orders available for dispatch today'**
  String get noOrdersForDispatch;

  /// No description provided for @createDispatch.
  ///
  /// In en, this message translates to:
  /// **'Create Dispatch'**
  String get createDispatch;

  /// No description provided for @dispatchDetails.
  ///
  /// In en, this message translates to:
  /// **'Dispatch Details'**
  String get dispatchDetails;

  /// No description provided for @driverName.
  ///
  /// In en, this message translates to:
  /// **'Driver Name'**
  String get driverName;

  /// No description provided for @vehicleNumber.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Number'**
  String get vehicleNumber;

  /// No description provided for @noPendingDispatches.
  ///
  /// In en, this message translates to:
  /// **'No pending dispatches yet!'**
  String get noPendingDispatches;

  /// No description provided for @tapToAddDispatch.
  ///
  /// In en, this message translates to:
  /// **'Tap the \'+\' button to create a new dispatch.'**
  String get tapToAddDispatch;

  /// No description provided for @orderFor.
  ///
  /// In en, this message translates to:
  /// **'Order for: {name}'**
  String orderFor(String name);

  /// No description provided for @driverWithVehicle.
  ///
  /// In en, this message translates to:
  /// **'Driver: {driver} ({vehicle})'**
  String driverWithVehicle(String driver, String vehicle);

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusDispatched.
  ///
  /// In en, this message translates to:
  /// **'DISPATCHED'**
  String get statusDispatched;

  /// No description provided for @statusDelivered.
  ///
  /// In en, this message translates to:
  /// **'DELIVERED'**
  String get statusDelivered;

  /// No description provided for @failedUpdateStatus.
  ///
  /// In en, this message translates to:
  /// **'Failed to update status: {error}'**
  String failedUpdateStatus(String error);

  /// No description provided for @payroll.
  ///
  /// In en, this message translates to:
  /// **'Payroll'**
  String get payroll;

  /// No description provided for @staff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get staff;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @noStaffMembers.
  ///
  /// In en, this message translates to:
  /// **'No staff members'**
  String get noStaffMembers;

  /// No description provided for @tapToAddStaff.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add staff'**
  String get tapToAddStaff;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @noMobile.
  ///
  /// In en, this message translates to:
  /// **'No mobile'**
  String get noMobile;

  /// No description provided for @permanent.
  ///
  /// In en, this message translates to:
  /// **'Permanent'**
  String get permanent;

  /// No description provided for @dailyWage.
  ///
  /// In en, this message translates to:
  /// **'Daily Wage'**
  String get dailyWage;

  /// No description provided for @contractor.
  ///
  /// In en, this message translates to:
  /// **'Contractor'**
  String get contractor;

  /// No description provided for @alreadyPunchedIn.
  ///
  /// In en, this message translates to:
  /// **'Already punched in today!'**
  String get alreadyPunchedIn;

  /// No description provided for @couldNotGetLocation.
  ///
  /// In en, this message translates to:
  /// **'Could not get location'**
  String get couldNotGetLocation;

  /// No description provided for @punchedInGeo.
  ///
  /// In en, this message translates to:
  /// **'✓ Punched In (Within Geo-fence)'**
  String get punchedInGeo;

  /// No description provided for @punchedInNoGeo.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Punched In (Outside Geo-fence)'**
  String get punchedInNoGeo;

  /// No description provided for @punchedOutMsg.
  ///
  /// In en, this message translates to:
  /// **'Punched Out - {hours} hrs{ot}'**
  String punchedOutMsg(String hours, String ot);

  /// No description provided for @totalStaff.
  ///
  /// In en, this message translates to:
  /// **'Total Staff'**
  String get totalStaff;

  /// No description provided for @present.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get present;

  /// No description provided for @absent.
  ///
  /// In en, this message translates to:
  /// **'Absent'**
  String get absent;

  /// No description provided for @noAttendanceToday.
  ///
  /// In en, this message translates to:
  /// **'No attendance records today'**
  String get noAttendanceToday;

  /// No description provided for @workingStatus.
  ///
  /// In en, this message translates to:
  /// **'working'**
  String get workingStatus;

  /// No description provided for @otLabel.
  ///
  /// In en, this message translates to:
  /// **'OT'**
  String get otLabel;

  /// No description provided for @addStaff.
  ///
  /// In en, this message translates to:
  /// **'Add Staff'**
  String get addStaff;

  /// No description provided for @staffDetails.
  ///
  /// In en, this message translates to:
  /// **'Staff Details'**
  String get staffDetails;

  /// No description provided for @tapToPhoto.
  ///
  /// In en, this message translates to:
  /// **'Tap to {action} photo'**
  String tapToPhoto(String action);

  /// No description provided for @basicInfo.
  ///
  /// In en, this message translates to:
  /// **'Basic Information'**
  String get basicInfo;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name *'**
  String get fullName;

  /// No description provided for @roleDesignation.
  ///
  /// In en, this message translates to:
  /// **'Role/Designation'**
  String get roleDesignation;

  /// No description provided for @staffType.
  ///
  /// In en, this message translates to:
  /// **'Staff Type'**
  String get staffType;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @salaryRates.
  ///
  /// In en, this message translates to:
  /// **'Salary & Rates'**
  String get salaryRates;

  /// No description provided for @monthlySalary.
  ///
  /// In en, this message translates to:
  /// **'Monthly Salary (₹)'**
  String get monthlySalary;

  /// No description provided for @payoutFrequency.
  ///
  /// In en, this message translates to:
  /// **'Payout Frequency'**
  String get payoutFrequency;

  /// No description provided for @dailyWageLabel.
  ///
  /// In en, this message translates to:
  /// **'Daily Wage (₹)'**
  String get dailyWageLabel;

  /// No description provided for @hourlyRate.
  ///
  /// In en, this message translates to:
  /// **'Hourly Rate (₹)'**
  String get hourlyRate;

  /// No description provided for @bankIdDetails.
  ///
  /// In en, this message translates to:
  /// **'Bank & ID Details'**
  String get bankIdDetails;

  /// No description provided for @bankName.
  ///
  /// In en, this message translates to:
  /// **'Bank Name'**
  String get bankName;

  /// No description provided for @accountNumber.
  ///
  /// In en, this message translates to:
  /// **'Account Number'**
  String get accountNumber;

  /// No description provided for @ifscCode.
  ///
  /// In en, this message translates to:
  /// **'IFSC Code'**
  String get ifscCode;

  /// No description provided for @aadharNumber.
  ///
  /// In en, this message translates to:
  /// **'Aadhar Number'**
  String get aadharNumber;

  /// No description provided for @emergencyContact.
  ///
  /// In en, this message translates to:
  /// **'Emergency Contact'**
  String get emergencyContact;

  /// No description provided for @contactName.
  ///
  /// In en, this message translates to:
  /// **'Contact Name'**
  String get contactName;

  /// No description provided for @contactNumber.
  ///
  /// In en, this message translates to:
  /// **'Contact Number'**
  String get contactNumber;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @addStaffBtn.
  ///
  /// In en, this message translates to:
  /// **'ADD STAFF'**
  String get addStaffBtn;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'SAVE CHANGES'**
  String get saveChanges;

  /// No description provided for @advances.
  ///
  /// In en, this message translates to:
  /// **'Advances'**
  String get advances;

  /// No description provided for @attendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get attendance;

  /// No description provided for @totalAdvances.
  ///
  /// In en, this message translates to:
  /// **'Total Advances'**
  String get totalAdvances;

  /// No description provided for @pendingDeduction.
  ///
  /// In en, this message translates to:
  /// **'Pending Deduction'**
  String get pendingDeduction;

  /// No description provided for @addAdvance.
  ///
  /// In en, this message translates to:
  /// **'Add Advance'**
  String get addAdvance;

  /// No description provided for @noAdvances.
  ///
  /// In en, this message translates to:
  /// **'No advances recorded'**
  String get noAdvances;

  /// No description provided for @deducted.
  ///
  /// In en, this message translates to:
  /// **'Deducted'**
  String get deducted;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @reason.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String reason(String reason);

  /// No description provided for @deleteStaff.
  ///
  /// In en, this message translates to:
  /// **'Delete Staff'**
  String get deleteStaff;

  /// No description provided for @deleteStaffConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this staff member? This cannot be undone.'**
  String get deleteStaffConfirm;

  /// No description provided for @staffDeleted.
  ///
  /// In en, this message translates to:
  /// **'Staff deleted'**
  String get staffDeleted;

  /// No description provided for @staffAdded.
  ///
  /// In en, this message translates to:
  /// **'Staff added!'**
  String get staffAdded;

  /// No description provided for @staffUpdated.
  ///
  /// In en, this message translates to:
  /// **'Staff updated!'**
  String get staffUpdated;

  /// No description provided for @selectPhoto.
  ///
  /// In en, this message translates to:
  /// **'Select Photo'**
  String get selectPhoto;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @photoSelectedWeb.
  ///
  /// In en, this message translates to:
  /// **'Photo selected (Web Mode)'**
  String get photoSelectedWeb;

  /// No description provided for @photoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Photo updated'**
  String get photoUpdated;

  /// No description provided for @amountRupee.
  ///
  /// In en, this message translates to:
  /// **'Amount (₹)'**
  String get amountRupee;

  /// No description provided for @staffPayroll.
  ///
  /// In en, this message translates to:
  /// **'Staff Payroll'**
  String get staffPayroll;

  /// No description provided for @basePay.
  ///
  /// In en, this message translates to:
  /// **'Base Pay'**
  String get basePay;

  /// No description provided for @otPay.
  ///
  /// In en, this message translates to:
  /// **'OT Pay'**
  String get otPay;

  /// No description provided for @netPay.
  ///
  /// In en, this message translates to:
  /// **'Net Pay'**
  String get netPay;

  /// No description provided for @noStaffData.
  ///
  /// In en, this message translates to:
  /// **'No staff data'**
  String get noStaffData;

  /// No description provided for @processPayroll.
  ///
  /// In en, this message translates to:
  /// **'Process Payroll'**
  String get processPayroll;

  /// No description provided for @processPayrollConfirm.
  ///
  /// In en, this message translates to:
  /// **'Mark all pending advances as deducted for {name} for {date}?'**
  String processPayrollConfirm(String name, String date);

  /// No description provided for @payrollProcessed.
  ///
  /// In en, this message translates to:
  /// **'Payroll processed for {name}'**
  String payrollProcessed(String name);

  /// No description provided for @advanceDeduction.
  ///
  /// In en, this message translates to:
  /// **'Advance Deduction'**
  String get advanceDeduction;

  /// No description provided for @netPayable.
  ///
  /// In en, this message translates to:
  /// **'Net Payable'**
  String get netPayable;

  /// No description provided for @markAdvancesDeducted.
  ///
  /// In en, this message translates to:
  /// **'Mark Advances Deducted'**
  String get markAdvancesDeducted;

  /// No description provided for @otMultiplierInfo.
  ///
  /// In en, this message translates to:
  /// **'OT Multiplier: {rate}x | OT = hours > 8 × hourly rate × {rate}'**
  String otMultiplierInfo(String rate);

  /// No description provided for @utensilsTracking.
  ///
  /// In en, this message translates to:
  /// **'Utensils Tracking'**
  String get utensilsTracking;

  /// No description provided for @noUtensilsAdded.
  ///
  /// In en, this message translates to:
  /// **'No utensils added yet'**
  String get noUtensilsAdded;

  /// No description provided for @addFirstUtensil.
  ///
  /// In en, this message translates to:
  /// **'Add First Utensil'**
  String get addFirstUtensil;

  /// No description provided for @addUtensil.
  ///
  /// In en, this message translates to:
  /// **'Add Utensil'**
  String get addUtensil;

  /// No description provided for @utensilName.
  ///
  /// In en, this message translates to:
  /// **'Utensil Name'**
  String get utensilName;

  /// No description provided for @utensilNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Plates, Spoons, Cups'**
  String get utensilNameHint;

  /// No description provided for @totalStock.
  ///
  /// In en, this message translates to:
  /// **'Total Stock'**
  String get totalStock;

  /// No description provided for @enterQuantity.
  ///
  /// In en, this message translates to:
  /// **'Enter quantity'**
  String get enterQuantity;

  /// No description provided for @availableStock.
  ///
  /// In en, this message translates to:
  /// **'Available Stock'**
  String get availableStock;

  /// No description provided for @enterUtensilName.
  ///
  /// In en, this message translates to:
  /// **'Please enter utensil name'**
  String get enterUtensilName;

  /// No description provided for @utensilAdded.
  ///
  /// In en, this message translates to:
  /// **'✅ Utensil added'**
  String get utensilAdded;

  /// No description provided for @utensilUpdated.
  ///
  /// In en, this message translates to:
  /// **'✅ Utensil updated'**
  String get utensilUpdated;

  /// No description provided for @utensilDeleted.
  ///
  /// In en, this message translates to:
  /// **'Utensil deleted'**
  String get utensilDeleted;

  /// No description provided for @editUtensil.
  ///
  /// In en, this message translates to:
  /// **'Edit: {name}'**
  String editUtensil(String name);

  /// No description provided for @deleteUtensil.
  ///
  /// In en, this message translates to:
  /// **'Delete Utensil?'**
  String get deleteUtensil;

  /// No description provided for @deleteUtensilConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String deleteUtensilConfirm(String name);

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @availableCount.
  ///
  /// In en, this message translates to:
  /// **'Available: {available} / {total}'**
  String availableCount(int available, int total);

  /// No description provided for @issuedCount.
  ///
  /// In en, this message translates to:
  /// **'Issued: {issued} ({percent}% utilized)'**
  String issuedCount(int issued, String percent);

  /// No description provided for @inventoryHub.
  ///
  /// In en, this message translates to:
  /// **'Inventory Hub'**
  String get inventoryHub;

  /// No description provided for @ingredients.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get ingredients;

  /// No description provided for @masterList.
  ///
  /// In en, this message translates to:
  /// **'Master List'**
  String get masterList;

  /// No description provided for @bom.
  ///
  /// In en, this message translates to:
  /// **'BOM'**
  String get bom;

  /// No description provided for @recipeMapping.
  ///
  /// In en, this message translates to:
  /// **'Recipe Mapping'**
  String get recipeMapping;

  /// No description provided for @mrpRun.
  ///
  /// In en, this message translates to:
  /// **'MRP Run'**
  String get mrpRun;

  /// No description provided for @calculate.
  ///
  /// In en, this message translates to:
  /// **'Calculate'**
  String get calculate;

  /// No description provided for @purchaseOrders.
  ///
  /// In en, this message translates to:
  /// **'Purchase Orders'**
  String get purchaseOrders;

  /// No description provided for @purchaseOrderShort.
  ///
  /// In en, this message translates to:
  /// **'PO'**
  String get purchaseOrderShort;

  /// No description provided for @trackOrders.
  ///
  /// In en, this message translates to:
  /// **'Track Orders'**
  String get trackOrders;

  /// No description provided for @suppliers.
  ///
  /// In en, this message translates to:
  /// **'Suppliers'**
  String get suppliers;

  /// No description provided for @vendors.
  ///
  /// In en, this message translates to:
  /// **'Vendors'**
  String get vendors;

  /// No description provided for @subcontractors.
  ///
  /// In en, this message translates to:
  /// **'Subcontractors'**
  String get subcontractors;

  /// No description provided for @kitchens.
  ///
  /// In en, this message translates to:
  /// **'Kitchens'**
  String get kitchens;

  /// No description provided for @ingredientsMaster.
  ///
  /// In en, this message translates to:
  /// **'Ingredients Master'**
  String get ingredientsMaster;

  /// No description provided for @ingredientName.
  ///
  /// In en, this message translates to:
  /// **'Ingredient Name'**
  String get ingredientName;

  /// No description provided for @skuBrandOptional.
  ///
  /// In en, this message translates to:
  /// **'SKU / Brand Name (Optional)'**
  String get skuBrandOptional;

  /// No description provided for @costPerUnit.
  ///
  /// In en, this message translates to:
  /// **'Cost per Unit (₹)'**
  String get costPerUnit;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unit;

  /// No description provided for @unitKg.
  ///
  /// In en, this message translates to:
  /// **'Kilogram (kg)'**
  String get unitKg;

  /// No description provided for @unitG.
  ///
  /// In en, this message translates to:
  /// **'Gram (g)'**
  String get unitG;

  /// No description provided for @unitL.
  ///
  /// In en, this message translates to:
  /// **'Liter'**
  String get unitL;

  /// No description provided for @unitMl.
  ///
  /// In en, this message translates to:
  /// **'Milliliter (ml)'**
  String get unitMl;

  /// No description provided for @unitNos.
  ///
  /// In en, this message translates to:
  /// **'Numbers (nos)'**
  String get unitNos;

  /// No description provided for @unitBunch.
  ///
  /// In en, this message translates to:
  /// **'Bunch'**
  String get unitBunch;

  /// No description provided for @unitPcs.
  ///
  /// In en, this message translates to:
  /// **'Pieces (pcs)'**
  String get unitPcs;

  /// No description provided for @enterIngredientName.
  ///
  /// In en, this message translates to:
  /// **'Enter ingredient name'**
  String get enterIngredientName;

  /// No description provided for @ingredientAdded.
  ///
  /// In en, this message translates to:
  /// **'✅ Ingredient added'**
  String get ingredientAdded;

  /// No description provided for @editIngredient.
  ///
  /// In en, this message translates to:
  /// **'Edit Ingredient'**
  String get editIngredient;

  /// No description provided for @ingredientUpdated.
  ///
  /// In en, this message translates to:
  /// **'✅ Ingredient updated'**
  String get ingredientUpdated;

  /// No description provided for @searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get searchPlaceholder;

  /// No description provided for @ingredientsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} ingredients'**
  String ingredientsCount(int count);

  /// No description provided for @categoriesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} categories'**
  String categoriesCount(int count);

  /// No description provided for @catAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get catAll;

  /// No description provided for @catVegetable.
  ///
  /// In en, this message translates to:
  /// **'Vegetable'**
  String get catVegetable;

  /// No description provided for @catMeat.
  ///
  /// In en, this message translates to:
  /// **'Meat'**
  String get catMeat;

  /// No description provided for @catSeafood.
  ///
  /// In en, this message translates to:
  /// **'Seafood'**
  String get catSeafood;

  /// No description provided for @catSpice.
  ///
  /// In en, this message translates to:
  /// **'Spice'**
  String get catSpice;

  /// No description provided for @catDairy.
  ///
  /// In en, this message translates to:
  /// **'Dairy'**
  String get catDairy;

  /// No description provided for @catGrain.
  ///
  /// In en, this message translates to:
  /// **'Grain'**
  String get catGrain;

  /// No description provided for @catOil.
  ///
  /// In en, this message translates to:
  /// **'Oil'**
  String get catOil;

  /// No description provided for @catBeverage.
  ///
  /// In en, this message translates to:
  /// **'Beverage'**
  String get catBeverage;

  /// No description provided for @catOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get catOther;

  /// No description provided for @bomManagement.
  ///
  /// In en, this message translates to:
  /// **'BOM Management'**
  String get bomManagement;

  /// No description provided for @bomInfo.
  ///
  /// In en, this message translates to:
  /// **'Define ingredients required for each dish at 100 pax standard'**
  String get bomInfo;

  /// No description provided for @searchDishes.
  ///
  /// In en, this message translates to:
  /// **'Search dishes...'**
  String get searchDishes;

  /// No description provided for @addDishesHint.
  ///
  /// In en, this message translates to:
  /// **'Add dishes in Menu Management first'**
  String get addDishesHint;

  /// No description provided for @itemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String itemsCount(int count);

  /// No description provided for @quantity100Pax.
  ///
  /// In en, this message translates to:
  /// **'Quantity for 100 pax'**
  String get quantity100Pax;

  /// No description provided for @selectIngredient.
  ///
  /// In en, this message translates to:
  /// **'Select Ingredient'**
  String get selectIngredient;

  /// No description provided for @selectIngredientHint.
  ///
  /// In en, this message translates to:
  /// **'Select ingredient and enter quantity'**
  String get selectIngredientHint;

  /// No description provided for @allIngredientsAdded.
  ///
  /// In en, this message translates to:
  /// **'All ingredients already added'**
  String get allIngredientsAdded;

  /// No description provided for @quantityUpdated.
  ///
  /// In en, this message translates to:
  /// **'✅ Quantity updated'**
  String get quantityUpdated;

  /// No description provided for @ingredientRemoved.
  ///
  /// In en, this message translates to:
  /// **'Ingredient removed'**
  String get ingredientRemoved;

  /// No description provided for @pax100.
  ///
  /// In en, this message translates to:
  /// **'100 PAX'**
  String get pax100;

  /// No description provided for @noIngredientsAdded.
  ///
  /// In en, this message translates to:
  /// **'No ingredients added'**
  String get noIngredientsAdded;

  /// No description provided for @mrpRunScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'MRP Run'**
  String get mrpRunScreenTitle;

  /// No description provided for @changeDate.
  ///
  /// In en, this message translates to:
  /// **'Change Date'**
  String get changeDate;

  /// No description provided for @totalOrders.
  ///
  /// In en, this message translates to:
  /// **'Total Orders'**
  String get totalOrders;

  /// No description provided for @liveKitchen.
  ///
  /// In en, this message translates to:
  /// **'Live Kitchen'**
  String get liveKitchen;

  /// No description provided for @subcontracted.
  ///
  /// In en, this message translates to:
  /// **'Subcontracted'**
  String get subcontracted;

  /// No description provided for @noOrdersForDate.
  ///
  /// In en, this message translates to:
  /// **'No orders for selected date'**
  String get noOrdersForDate;

  /// No description provided for @selectDifferentDate.
  ///
  /// In en, this message translates to:
  /// **'Select Different Date'**
  String get selectDifferentDate;

  /// No description provided for @runMrp.
  ///
  /// In en, this message translates to:
  /// **'RUN MRP'**
  String get runMrp;

  /// No description provided for @calculating.
  ///
  /// In en, this message translates to:
  /// **'Calculating...'**
  String get calculating;

  /// No description provided for @noOrdersToProcess.
  ///
  /// In en, this message translates to:
  /// **'No orders to process'**
  String get noOrdersToProcess;

  /// No description provided for @venueNotSpecified.
  ///
  /// In en, this message translates to:
  /// **'Venue not specified'**
  String get venueNotSpecified;

  /// No description provided for @selectSubcontractor.
  ///
  /// In en, this message translates to:
  /// **'Select Subcontractor'**
  String get selectSubcontractor;

  /// No description provided for @liveKitchenChip.
  ///
  /// In en, this message translates to:
  /// **'Live Kitchen'**
  String get liveKitchenChip;

  /// No description provided for @subcontractChip.
  ///
  /// In en, this message translates to:
  /// **'Subcontract'**
  String get subcontractChip;

  /// No description provided for @mrpOutputTitle.
  ///
  /// In en, this message translates to:
  /// **'MRP Output'**
  String get mrpOutputTitle;

  /// No description provided for @noIngredientsCalculated.
  ///
  /// In en, this message translates to:
  /// **'No ingredients calculated'**
  String get noIngredientsCalculated;

  /// No description provided for @checkBomDefined.
  ///
  /// In en, this message translates to:
  /// **'Check if dishes have BOM defined'**
  String get checkBomDefined;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'total'**
  String get total;

  /// No description provided for @proceedToAllotment.
  ///
  /// In en, this message translates to:
  /// **'PROCEED TO ALLOTMENT'**
  String get proceedToAllotment;

  /// No description provided for @allotmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Allotment'**
  String get allotmentTitle;

  /// No description provided for @supplierAllotment.
  ///
  /// In en, this message translates to:
  /// **'Supplier Allotment'**
  String get supplierAllotment;

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// No description provided for @assignIngredientHint.
  ///
  /// In en, this message translates to:
  /// **'Assign each ingredient to a supplier'**
  String get assignIngredientHint;

  /// No description provided for @assignedStatus.
  ///
  /// In en, this message translates to:
  /// **'{assigned}/{total} assigned'**
  String assignedStatus(int assigned, int total);

  /// No description provided for @supplier.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get supplier;

  /// No description provided for @generateAndSendPos.
  ///
  /// In en, this message translates to:
  /// **'GENERATE & SEND POs'**
  String get generateAndSendPos;

  /// No description provided for @posWillBeGenerated.
  ///
  /// In en, this message translates to:
  /// **'{count} POs will be generated'**
  String posWillBeGenerated(int count);

  /// No description provided for @noAllocationsMade.
  ///
  /// In en, this message translates to:
  /// **'No allocations made yet'**
  String get noAllocationsMade;

  /// No description provided for @allocateIngredientsFirst.
  ///
  /// In en, this message translates to:
  /// **'Allocate ingredients to suppliers first'**
  String get allocateIngredientsFirst;

  /// No description provided for @posGeneratedSuccess.
  ///
  /// In en, this message translates to:
  /// **'✅ {count} POs generated and sent'**
  String posGeneratedSuccess(int count);

  /// No description provided for @catGrocery.
  ///
  /// In en, this message translates to:
  /// **'Grocery'**
  String get catGrocery;

  /// No description provided for @supplierMaster.
  ///
  /// In en, this message translates to:
  /// **'Supplier Master'**
  String get supplierMaster;

  /// No description provided for @addSupplier.
  ///
  /// In en, this message translates to:
  /// **'Add Supplier'**
  String get addSupplier;

  /// No description provided for @editSupplier.
  ///
  /// In en, this message translates to:
  /// **'Edit Supplier'**
  String get editSupplier;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name *'**
  String get nameRequired;

  /// No description provided for @mobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get mobile;

  /// No description provided for @gstNumber.
  ///
  /// In en, this message translates to:
  /// **'GST Number'**
  String get gstNumber;

  /// No description provided for @bankDetails.
  ///
  /// In en, this message translates to:
  /// **'Bank Details'**
  String get bankDetails;

  /// No description provided for @enterSupplierName.
  ///
  /// In en, this message translates to:
  /// **'Enter supplier name'**
  String get enterSupplierName;

  /// No description provided for @supplierUpdated.
  ///
  /// In en, this message translates to:
  /// **'✅ Supplier updated'**
  String get supplierUpdated;

  /// No description provided for @supplierAdded.
  ///
  /// In en, this message translates to:
  /// **'✅ Supplier added'**
  String get supplierAdded;

  /// No description provided for @noSuppliersAdded.
  ///
  /// In en, this message translates to:
  /// **'No suppliers added'**
  String get noSuppliersAdded;

  /// No description provided for @noPhone.
  ///
  /// In en, this message translates to:
  /// **'No phone'**
  String get noPhone;

  /// No description provided for @subcontractorMaster.
  ///
  /// In en, this message translates to:
  /// **'Subcontractor Master'**
  String get subcontractorMaster;

  /// No description provided for @editSubcontractor.
  ///
  /// In en, this message translates to:
  /// **'Edit Subcontractor'**
  String get editSubcontractor;

  /// No description provided for @addSubcontractor.
  ///
  /// In en, this message translates to:
  /// **'Add Subcontractor'**
  String get addSubcontractor;

  /// No description provided for @kitchenBusinessName.
  ///
  /// In en, this message translates to:
  /// **'Kitchen/Business Name *'**
  String get kitchenBusinessName;

  /// No description provided for @mobileRequired.
  ///
  /// In en, this message translates to:
  /// **'Mobile *'**
  String get mobileRequired;

  /// No description provided for @specialization.
  ///
  /// In en, this message translates to:
  /// **'Specialization'**
  String get specialization;

  /// No description provided for @specializationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Biriyani, Chinese, Sweets'**
  String get specializationHint;

  /// No description provided for @ratePerPax.
  ///
  /// In en, this message translates to:
  /// **'Rate per Pax (₹)'**
  String get ratePerPax;

  /// No description provided for @enterNameMobile.
  ///
  /// In en, this message translates to:
  /// **'Enter name and mobile'**
  String get enterNameMobile;

  /// No description provided for @subcontractorUpdated.
  ///
  /// In en, this message translates to:
  /// **'✅ Subcontractor updated'**
  String get subcontractorUpdated;

  /// No description provided for @subcontractorAdded.
  ///
  /// In en, this message translates to:
  /// **'✅ Subcontractor added'**
  String get subcontractorAdded;

  /// No description provided for @noSubcontractorsAdded.
  ///
  /// In en, this message translates to:
  /// **'No subcontractors added'**
  String get noSubcontractorsAdded;

  /// No description provided for @perPax.
  ///
  /// In en, this message translates to:
  /// **'per pax'**
  String get perPax;

  /// No description provided for @purchaseOrdersTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase Orders'**
  String get purchaseOrdersTitle;

  /// No description provided for @statusSent.
  ///
  /// In en, this message translates to:
  /// **'SENT'**
  String get statusSent;

  /// No description provided for @statusViewed.
  ///
  /// In en, this message translates to:
  /// **'VIEWED'**
  String get statusViewed;

  /// No description provided for @statusAccepted.
  ///
  /// In en, this message translates to:
  /// **'ACCEPTED'**
  String get statusAccepted;

  /// No description provided for @purchaseOrdersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} purchase orders'**
  String purchaseOrdersCount(int count);

  /// No description provided for @noPurchaseOrders.
  ///
  /// In en, this message translates to:
  /// **'No purchase orders'**
  String get noPurchaseOrders;

  /// No description provided for @runMrpHint.
  ///
  /// In en, this message translates to:
  /// **'Run MRP to generate POs'**
  String get runMrpHint;

  /// No description provided for @dispatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Dispatch'**
  String get dispatchTitle;

  /// No description provided for @tabList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get tabList;

  /// No description provided for @tabActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get tabActive;

  /// No description provided for @tabReturns.
  ///
  /// In en, this message translates to:
  /// **'Returns'**
  String get tabReturns;

  /// No description provided for @tabUnload.
  ///
  /// In en, this message translates to:
  /// **'Unload'**
  String get tabUnload;

  /// No description provided for @noPendingOrdersDate.
  ///
  /// In en, this message translates to:
  /// **'No pending orders for {date}'**
  String noPendingOrdersDate(String date);

  /// No description provided for @noActiveDispatches.
  ///
  /// In en, this message translates to:
  /// **'No active dispatches'**
  String get noActiveDispatches;

  /// No description provided for @noReturnTracking.
  ///
  /// In en, this message translates to:
  /// **'No items for return tracking'**
  String get noReturnTracking;

  /// No description provided for @noUnloadItems.
  ///
  /// In en, this message translates to:
  /// **'No items ready for unload'**
  String get noUnloadItems;

  /// No description provided for @startDispatch.
  ///
  /// In en, this message translates to:
  /// **'Start Dispatch'**
  String get startDispatch;

  /// No description provided for @waitingForKitchen.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Kitchen'**
  String get waitingForKitchen;

  /// No description provided for @track.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get track;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @trackReturn.
  ///
  /// In en, this message translates to:
  /// **'Track Return'**
  String get trackReturn;

  /// No description provided for @locationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationLabel;

  /// No description provided for @locationValues.
  ///
  /// In en, this message translates to:
  /// **'Location: {lat}, {lng}'**
  String locationValues(double lat, double lng);

  /// No description provided for @tapToViewItems.
  ///
  /// In en, this message translates to:
  /// **'Tap to view loaded items →'**
  String get tapToViewItems;

  /// No description provided for @loadedItems.
  ///
  /// In en, this message translates to:
  /// **'Loaded Items'**
  String get loadedItems;

  /// No description provided for @noItemsRecorded.
  ///
  /// In en, this message translates to:
  /// **'No items recorded'**
  String get noItemsRecorded;

  /// No description provided for @kitchenItems.
  ///
  /// In en, this message translates to:
  /// **'🍳 Kitchen Items'**
  String get kitchenItems;

  /// No description provided for @kitchenItemsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Prepared in kitchen - tick when loaded'**
  String get kitchenItemsSubtitle;

  /// No description provided for @subcontractItems.
  ///
  /// In en, this message translates to:
  /// **'🏪 Subcontract Items'**
  String get subcontractItems;

  /// No description provided for @subcontractItemsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Optional - may come directly to venue'**
  String get subcontractItemsSubtitle;

  /// No description provided for @liveCookingItems.
  ///
  /// In en, this message translates to:
  /// **'🔥 Live Cooking Items'**
  String get liveCookingItems;

  /// No description provided for @liveCookingItemsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Load ingredients for on-site cooking'**
  String get liveCookingItemsSubtitle;

  /// No description provided for @selectVehicle.
  ///
  /// In en, this message translates to:
  /// **'Select Vehicle'**
  String get selectVehicle;

  /// No description provided for @dispatchedMsg.
  ///
  /// In en, this message translates to:
  /// **'Dispatched!'**
  String get dispatchedMsg;

  /// No description provided for @dispatchError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String dispatchError(Object error);

  /// No description provided for @dispatchListTitle.
  ///
  /// In en, this message translates to:
  /// **'Dispatch List'**
  String get dispatchListTitle;

  /// No description provided for @inHouseReady.
  ///
  /// In en, this message translates to:
  /// **'{ready}/{total} In-House Ready'**
  String inHouseReady(int ready, int total);

  /// No description provided for @noInHouseItems.
  ///
  /// In en, this message translates to:
  /// **'No in-house items'**
  String get noInHouseItems;

  /// No description provided for @statusInProduction.
  ///
  /// In en, this message translates to:
  /// **'In Production'**
  String get statusInProduction;

  /// No description provided for @statusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get statusReady;

  /// No description provided for @dispatchCustomerTitle.
  ///
  /// In en, this message translates to:
  /// **'Dispatch: {customer}'**
  String dispatchCustomerTitle(String customer);

  /// No description provided for @chooseVehicle.
  ///
  /// In en, this message translates to:
  /// **'Choose vehicle'**
  String get chooseVehicle;

  /// No description provided for @completeDispatchNotify.
  ///
  /// In en, this message translates to:
  /// **'Complete Dispatch & Notify Customer'**
  String get completeDispatchNotify;

  /// No description provided for @pleaseSelectVehicle.
  ///
  /// In en, this message translates to:
  /// **'Please select a vehicle'**
  String get pleaseSelectVehicle;

  /// No description provided for @savedMsg.
  ///
  /// In en, this message translates to:
  /// **'Saved!'**
  String get savedMsg;

  /// No description provided for @loadAllDishesFirst.
  ///
  /// In en, this message translates to:
  /// **'Please load all dishes first'**
  String get loadAllDishesFirst;

  /// No description provided for @dispatchedNotifiedMsg.
  ///
  /// In en, this message translates to:
  /// **'Dispatched! Customer notified.'**
  String get dispatchedNotifiedMsg;

  /// No description provided for @utensilsEquipment.
  ///
  /// In en, this message translates to:
  /// **'Utensils & Equipment'**
  String get utensilsEquipment;

  /// No description provided for @returnTitle.
  ///
  /// In en, this message translates to:
  /// **'Return: {customer}'**
  String returnTitle(String customer);

  /// No description provided for @returnVehicle.
  ///
  /// In en, this message translates to:
  /// **'Return Vehicle'**
  String get returnVehicle;

  /// No description provided for @items.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get items;

  /// No description provided for @noUtensilsReturn.
  ///
  /// In en, this message translates to:
  /// **'No Utensils to return.'**
  String get noUtensilsReturn;

  /// No description provided for @returnSaved.
  ///
  /// In en, this message translates to:
  /// **'Return saved successfully!'**
  String get returnSaved;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String saveFailed(Object error);

  /// No description provided for @completeReturn.
  ///
  /// In en, this message translates to:
  /// **'Complete Return'**
  String get completeReturn;

  /// No description provided for @unloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Unload: {customer}'**
  String unloadTitle(String customer);

  /// No description provided for @verifyItems.
  ///
  /// In en, this message translates to:
  /// **'Verify Items'**
  String get verifyItems;

  /// No description provided for @noUtensilsUnload.
  ///
  /// In en, this message translates to:
  /// **'No Utensils to Unload.'**
  String get noUtensilsUnload;

  /// No description provided for @closeOrder.
  ///
  /// In en, this message translates to:
  /// **'Close Order'**
  String get closeOrder;

  /// No description provided for @missingItems.
  ///
  /// In en, this message translates to:
  /// **'Missing Items'**
  String get missingItems;

  /// No description provided for @acknowledgeClose.
  ///
  /// In en, this message translates to:
  /// **'Acknowledge & Close'**
  String get acknowledgeClose;

  /// No description provided for @reasonMismatch.
  ///
  /// In en, this message translates to:
  /// **'Reason for mismatch'**
  String get reasonMismatch;

  /// No description provided for @loadedQty.
  ///
  /// In en, this message translates to:
  /// **'Loaded: {qty}'**
  String loadedQty(int qty);

  /// No description provided for @qtyLabel.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get qtyLabel;

  /// No description provided for @reportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsTitle;

  /// No description provided for @periodLabel.
  ///
  /// In en, this message translates to:
  /// **'Period: '**
  String get periodLabel;

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get day;

  /// No description provided for @week.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get week;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// No description provided for @orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// No description provided for @kitchen.
  ///
  /// In en, this message translates to:
  /// **'Kitchen'**
  String get kitchen;

  /// No description provided for @dispatch.
  ///
  /// In en, this message translates to:
  /// **'Dispatch'**
  String get dispatch;

  /// No description provided for @hr.
  ///
  /// In en, this message translates to:
  /// **'HR'**
  String get hr;

  /// No description provided for @noDataSelectedPeriod.
  ///
  /// In en, this message translates to:
  /// **'No data for selected period'**
  String get noDataSelectedPeriod;

  /// No description provided for @revenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get revenue;

  /// No description provided for @confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get confirmed;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @inProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get inProgress;

  /// No description provided for @delivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get delivered;

  /// No description provided for @inTransit.
  ///
  /// In en, this message translates to:
  /// **'In Transit'**
  String get inTransit;

  /// No description provided for @totalDispatches.
  ///
  /// In en, this message translates to:
  /// **'Dispatches'**
  String get totalDispatches;

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get hours;

  /// No description provided for @overtime.
  ///
  /// In en, this message translates to:
  /// **'OT'**
  String get overtime;

  /// No description provided for @staffWithOt.
  ///
  /// In en, this message translates to:
  /// **'Staff with OT'**
  String get staffWithOt;

  /// No description provided for @totalOt.
  ///
  /// In en, this message translates to:
  /// **'Total OT'**
  String get totalOt;

  /// No description provided for @noOvertime.
  ///
  /// In en, this message translates to:
  /// **'No overtime recorded'**
  String get noOvertime;

  /// No description provided for @financeTitle.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get financeTitle;

  /// No description provided for @income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get income;

  /// No description provided for @expense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expense;

  /// No description provided for @netBalance.
  ///
  /// In en, this message translates to:
  /// **'Net Balance'**
  String get netBalance;

  /// No description provided for @transactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions;

  /// No description provided for @ledgers.
  ///
  /// In en, this message translates to:
  /// **'Ledgers'**
  String get ledgers;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @recentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get recentTransactions;

  /// No description provided for @noTransactionsFound.
  ///
  /// In en, this message translates to:
  /// **'No transactions found'**
  String get noTransactionsFound;

  /// No description provided for @exportingReport.
  ///
  /// In en, this message translates to:
  /// **'Exporting Finance Report... (Mock)'**
  String get exportingReport;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @deleteTransactionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Transaction?'**
  String get deleteTransactionTitle;

  /// No description provided for @deleteTransactionContent.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get deleteTransactionContent;

  /// No description provided for @customers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customers;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get comingSoon;

  /// No description provided for @addIncome.
  ///
  /// In en, this message translates to:
  /// **'Add Income'**
  String get addIncome;

  /// No description provided for @addExpense.
  ///
  /// In en, this message translates to:
  /// **'Add Expense'**
  String get addExpense;

  /// No description provided for @amountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amountLabel;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// No description provided for @paymentModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment Mode'**
  String get paymentModeLabel;

  /// No description provided for @descriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description / Notes'**
  String get descriptionLabel;

  /// No description provided for @saveTransaction.
  ///
  /// In en, this message translates to:
  /// **'Save Transaction'**
  String get saveTransaction;

  /// No description provided for @enterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get enterAmount;

  /// No description provided for @invalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Invalid amount'**
  String get invalidAmount;

  /// No description provided for @transactionSaved.
  ///
  /// In en, this message translates to:
  /// **'Transaction Saved'**
  String get transactionSaved;

  /// No description provided for @collectPayment.
  ///
  /// In en, this message translates to:
  /// **'Collect Payment'**
  String get collectPayment;

  /// No description provided for @selectPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Select Payment Method'**
  String get selectPaymentMethod;

  /// No description provided for @upiRazorpay.
  ///
  /// In en, this message translates to:
  /// **'UPI (Razorpay)'**
  String get upiRazorpay;

  /// No description provided for @cardRazorpay.
  ///
  /// In en, this message translates to:
  /// **'Credit/Debit Card (Razorpay)'**
  String get cardRazorpay;

  /// No description provided for @cash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cash;

  /// No description provided for @paymentSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Payment Successful!'**
  String get paymentSuccessful;

  /// No description provided for @paymentReceivedMsg.
  ///
  /// In en, this message translates to:
  /// **'Payment of {amount} received for Order #{orderId}'**
  String paymentReceivedMsg(String amount, int orderId);

  /// No description provided for @paymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment Failed: {error}'**
  String paymentFailed(Object error);

  /// No description provided for @chooseSubscription.
  ///
  /// In en, this message translates to:
  /// **'Choose Subscription Plan'**
  String get chooseSubscription;

  /// No description provided for @selectStartPlan.
  ///
  /// In en, this message translates to:
  /// **'Select Your Plan'**
  String get selectStartPlan;

  /// No description provided for @payBtn.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount}'**
  String payBtn(String amount);

  /// No description provided for @subscriptionActivated.
  ///
  /// In en, this message translates to:
  /// **'Subscription Activated!'**
  String get subscriptionActivated;

  /// No description provided for @planActiveUntil.
  ///
  /// In en, this message translates to:
  /// **'Your plan is now active until {date}.'**
  String planActiveUntil(String date);

  /// No description provided for @continueBtn.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueBtn;

  /// No description provided for @auditReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Audit Report'**
  String get auditReportTitle;

  /// No description provided for @noLogsExport.
  ///
  /// In en, this message translates to:
  /// **'No logs to export'**
  String get noLogsExport;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(Object error);

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get startDate;

  /// No description provided for @endDate.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get endDate;

  /// No description provided for @userIdLabel.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get userIdLabel;

  /// No description provided for @tableLabel.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get tableLabel;

  /// No description provided for @noAuditLogs.
  ///
  /// In en, this message translates to:
  /// **'No audit logs found'**
  String get noAuditLogs;

  /// No description provided for @changedFields.
  ///
  /// In en, this message translates to:
  /// **'Changed: {fields}'**
  String changedFields(String fields);

  /// No description provided for @beforeVal.
  ///
  /// In en, this message translates to:
  /// **'Before: {val}'**
  String beforeVal(String val);

  /// No description provided for @afterVal.
  ///
  /// In en, this message translates to:
  /// **'After: {val}'**
  String afterVal(String val);

  /// No description provided for @addIngredient.
  ///
  /// In en, this message translates to:
  /// **'Add Ingredient'**
  String get addIngredient;

  /// No description provided for @noIngredientsFound.
  ///
  /// In en, this message translates to:
  /// **'No ingredients found'**
  String get noIngredientsFound;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'en',
        'hi',
        'kn',
        'ml',
        'ta',
        'te'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'kn':
      return AppLocalizationsKn();
    case 'ml':
      return AppLocalizationsMl();
    case 'ta':
      return AppLocalizationsTa();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
