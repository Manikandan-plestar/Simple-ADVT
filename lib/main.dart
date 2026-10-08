import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'services/auth_service.dart';
import 'services/location_service.dart';
import 'services/business_service.dart';
import 'services/post_service.dart';
import 'services/search_service.dart';
import 'services/notification_service.dart';
import 'services/in_app_purchase_service.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/register_screen.dart';
import 'screens/location_screen.dart';
import 'screens/home_screen.dart';
import 'screens/business_details_screen.dart';
import 'screens/business_profiles_list_screen.dart';
import 'screens/create_business_screen.dart';
import 'screens/edit_business_screen.dart';
import 'screens/biz_manage_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/my_profile_screen.dart';
import 'screens/followed_screen.dart';
import 'screens/saved_items_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/post_details_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize In-App Purchase Service
  await InAppPurchaseService().initialize();

  runApp(const AdvtApp());
}

class AdvtApp extends StatelessWidget {
  const AdvtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 1. AuthService: Manages email OTP auth, user registration (Name & Address), and persisted session
        ChangeNotifierProvider(create: (_) => AuthService()),
        // 2. LocationService: Manages GPS coordinates, reverse geocoding, and address components
        ChangeNotifierProvider(create: (_) => LocationService()),
        // 3. BusinessService: Holds user's multiple business profiles (BP001, BP002...), follow states
        ChangeNotifierProvider(create: (_) => BusinessService()),
        // 4. PostService: Stores location-targeted generic business posts, publishing, and saved bookmarks
        ChangeNotifierProvider(create: (_) => PostService()),
        // 5. SearchService: Real-time search filtering across posts and businesses
        ChangeNotifierProvider(create: (_) => SearchService()),
        // 6. NotificationService: Handles alerts and notifications
        ChangeNotifierProvider(create: (_) => NotificationService()),
      ],
      child: MaterialApp(
        title: 'ADVT App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF8FAFC),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
          ),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4F46E5), // Indigo
            primary: const Color(0xFF4F46E5),
            secondary: const Color(0xFFF59E0B), // Amber
            surface: Colors.white,
          ),
          fontFamily: 'Roboto',
        ),
        initialRoute: '/',
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/':
              return MaterialPageRoute(builder: (_) => const SplashScreen());
            case '/login':
              return MaterialPageRoute(builder: (_) => const LoginScreen());
            case '/otp':
              return MaterialPageRoute(builder: (_) => const OtpScreen());
            case '/register':
              return MaterialPageRoute(builder: (_) => const RegisterScreen());
            case '/location':
              return MaterialPageRoute(builder: (_) => const LocationScreen());
            case '/home':
              return MaterialPageRoute(builder: (_) => const HomeScreen());
            case '/business-details':
              final bizId = settings.arguments as String? ?? 'BP001';
              return MaterialPageRoute(builder: (_) => BusinessDetailsScreen(businessProfileId: bizId));
            case '/business-profiles-list':
              return MaterialPageRoute(builder: (_) => const BusinessProfilesListScreen());
            case '/create-biz':
              return MaterialPageRoute(builder: (_) => const CreateBusinessScreen());
            case '/edit-biz':
              final bizId = settings.arguments as String? ?? 'BP001';
              return MaterialPageRoute(builder: (_) => EditBusinessScreen(businessProfileId: bizId));
            case '/biz-manage':
              return MaterialPageRoute(builder: (_) => const BizManageScreen());
            case '/notifications':
              return MaterialPageRoute(builder: (_) => const NotificationsScreen());
            case '/my-profile':
              return MaterialPageRoute(builder: (_) => const MyProfileScreen());
            case '/followed':
              return MaterialPageRoute(builder: (_) => const FollowedScreen());
            case '/saved-items':
              return MaterialPageRoute(builder: (_) => const SavedItemsScreen());
            case '/post-details':
              final postId = settings.arguments as String? ?? 'P001';
              return MaterialPageRoute(builder: (_) => PostDetailsScreen(postId: postId));
            case '/settings':
              return MaterialPageRoute(builder: (_) => const SettingsScreen());
            default:
              return MaterialPageRoute(builder: (_) => const HomeScreen());
          }
        },
      ),
    );
  }
}
