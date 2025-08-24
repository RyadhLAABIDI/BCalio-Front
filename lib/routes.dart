import 'package:bcalio/screens/authentication/forgot_password_screen.dart';
import 'package:bcalio/screens/authentication/new_password_screen.dart';
import 'package:bcalio/screens/navigation/navigation_screen.dart';
import 'package:bcalio/screens/qr/qr_web_scan_screen.dart';
import 'package:get/get.dart';
import 'screens/authentication/create_profile.dart';
import 'screens/authentication/login_screen.dart';
import 'screens/authentication/phone_login_screen.dart';
import 'screens/authentication/otp_verification_screen.dart';
import 'screens/authentication/welcome_screen.dart';
import 'screens/chat/chat_list_screen.dart';
import 'screens/chat/group_chat/create_group_chat_screen.dart';
import 'screens/contacts/Add_Contact_screen.dart';
import 'screens/contacts/all_contacts_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/settings/update_profile_screen.dart';
import 'screens/qr/my_qr_screen.dart';
import 'screens/qr/scan_qr_add_screen.dart';

class Routes {
  // Route Names
  static const String start = '/';
  static const String phonelogin = '/PhoneLogin';
  static const String otpVerification = '/otpVerification';
  static const String createProfile = '/createProfile';
  static const String login = '/login';
  static const String home = '/home';
  static const String chat = "/chat";
  static const String createGroup = '/createGroup';
  static const String allContactsScreen = '/allContactsScreen';
  static const String addContactScreen = '/addContactScreen';
  static const String updateProfile = '/updateProfile';
  static const String forgotPassword = '/forgotPasswordPage';
  static const String newPassword = '/newPasswordPage';
  static const String navigationScreen = '/navigationScreen';

  // Pages
  static final routes = [
    GetPage(name: start, page: () => WelcomePage()),
    GetPage(name: phonelogin, page: () => PhoneLoginPage()),
    GetPage(name: otpVerification, page: () => OTPVerificationPage()),
    GetPage(name: createProfile, page: () => CreateProfilePage()),
    GetPage(name: home, page: () => HomePage()),
    GetPage(name: chat, page: () => ChatList()),
    GetPage(name: createGroup, page: () => CreateGroupChatScreen()),
    GetPage(name: allContactsScreen, page: () => AllContactsScreen()),
    GetPage(name: addContactScreen, page: () => AddContactScreen()),
    GetPage(name: login, page: () => LoginPage()),
    GetPage(name: updateProfile, page: () => UpdateProfileScreen()),
    GetPage(name: forgotPassword, page: () => ForgotPasswordPage()),
    GetPage(name: newPassword, page: () => NewPasswordPage()),
    GetPage(name: navigationScreen, page: () => NavigationScreen()),
    GetPage(name: '/qr/my',   page: () => const MyQrScreen()),
    GetPage(name: '/qr/scan', page: () => const ScanQrAddScreen()),
    GetPage(name: '/qr/web-scan', page: () => const QrWebScanScreen()),

  ];
}
