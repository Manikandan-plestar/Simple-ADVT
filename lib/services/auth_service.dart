import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../utils/text_utils.dart';

class UserProfile {
  String userId;
  String name;
  String phone;
  String countryCode;
  String email;
  String address;
  String locality;
  String city;
  String state;
  String country;
  double latitude;
  double longitude;
  String location;
  bool isLoggedIn;
  String? authToken;

  UserProfile({
    required this.userId,
    required this.name,
    this.phone = '',
    this.countryCode = '+91',
    required this.email,
    required this.address,
    this.locality = '',
    this.city = '',
    this.state = '',
    this.country = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
    required this.location,
    this.isLoggedIn = false,
    this.authToken,
  });

  String get displayName => TextUtils.capitalizeWords(name);
}

class AuthResponse {
  final bool success;
  final String message;
  final String? token;
  final int? expiresInSeconds;
  final bool isExistingUser;
  final Map<String, dynamic>? userData;

  AuthResponse({
    required this.success,
    required this.message,
    this.token,
    this.expiresInSeconds,
    this.isExistingUser = false,
    this.userData,
  });
}

class AuthService extends ChangeNotifier {
  UserProfile _user = UserProfile(
    userId: "",
    name: "",
    phone: "",
    countryCode: "+91",
    email: "",
    address: "",
    locality: "",
    city: "",
    state: "",
    country: "",
    latitude: 0.0,
    longitude: 0.0,
    location: "",
    isLoggedIn: false,
  );

  String? _pendingEmail;
  bool _isOtpSent = false;
  bool _isLoading = false;

  // Base URL configuration (delegated to unified ApiClient)
  String get _baseUrl => ApiClient().baseUrl;
  String get baseUrl => ApiClient().baseUrl;
  set baseUrl(String url) {
    ApiClient().setBaseUrl(url);
    notifyListeners();
  }

  UserProfile get currentUser => _user;
  bool get isLoggedIn => _user.isLoggedIn;
  bool get isOtpSent => _isOtpSent;
  bool get isLoading => _isLoading;
  String? get pendingEmail => _pendingEmail;

  AuthService() {
    initSession();
  }

  Future<File> _getSessionFile() async {
    try {
      final sysTemp = Directory.systemTemp;
      return File('${sysTemp.path}/simple_advt_session.json');
    } catch (_) {
      return File('simple_advt_session.json');
    }
  }

  /// Load session state upon initialization or app launch.
  Future<void> initSession() async {
    try {
      final file = await _getSessionFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final data = jsonDecode(content) as Map<String, dynamic>;
          final isLoggedIn = data['is_logged_in'] as bool? ?? false;
          if (isLoggedIn) {
            _user = UserProfile(
              userId: data['user_id'] as String? ?? "",
              name: data['user_name'] as String? ?? "",
              phone: data['user_phone'] as String? ?? "",
              countryCode: data['country_code'] as String? ?? "+91",
              email: data['user_email'] as String? ?? "",
              address: data['user_address'] as String? ?? "",
              locality: data['locality'] as String? ?? "",
              city: data['city'] as String? ?? "",
              state: data['state'] as String? ?? "",
              country: data['country'] as String? ?? "",
              latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
              longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
              location: data['user_location'] as String? ?? "",
              isLoggedIn: true,
              authToken: data['auth_token'] as String?,
            );
            ApiClient().setAuthToken(_user.authToken);
            ApiClient().setCurrentUser(userId: _user.userId, email: _user.email);
            notifyListeners();
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error loading auth session: $e");
      }
    }
  }

  /// Save session state persistently.
  Future<void> _saveSession() async {
    try {
      final file = await _getSessionFile();
      final data = {
        'is_logged_in': _user.isLoggedIn,
        'user_id': _user.userId,
        'user_name': _user.name,
        'user_phone': _user.phone,
        'country_code': _user.countryCode,
        'user_email': _user.email,
        'user_address': _user.address,
        'locality': _user.locality,
        'city': _user.city,
        'state': _user.state,
        'country': _user.country,
        'latitude': _user.latitude,
        'longitude': _user.longitude,
        'user_location': _user.location,
        'auth_token': _user.authToken,
      };
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      if (kDebugMode) {
        print("Error saving auth session: $e");
      }
    }
  }

  /// 1. Send OTP to email via Node.js Express Backend
  Future<AuthResponse> sendOtp(String email) async {
    _isLoading = true;
    notifyListeners();

    final cleanEmail = email.trim().toLowerCase();
    final url = Uri.parse('$_baseUrl/api/send-email-otp');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': cleanEmail}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final success = response.statusCode == 200 && (data['success'] == true);
      final message = data['message'] as String? ?? (success ? 'OTP sent successfully.' : 'Failed to send OTP.');

      if (success) {
        _pendingEmail = cleanEmail;
        _isOtpSent = true;
      } else {
        _isOtpSent = false;
      }

      _isLoading = false;
      notifyListeners();

      return AuthResponse(
        success: success,
        message: message,
        expiresInSeconds: data['expiresInSeconds'] as int? ?? 300,
      );
    } catch (e) {
      _isLoading = false;
      _isOtpSent = false;
      notifyListeners();

      return AuthResponse(
        success: false,
        message: 'Cannot connect to server. Please ensure backend is running.',
      );
    }
  }

  /// 2. Resend OTP to email
  Future<AuthResponse> resendOtp(String email) async {
    _isLoading = true;
    notifyListeners();

    final cleanEmail = email.trim().toLowerCase();
    final url = Uri.parse('$_baseUrl/api/resend-email-otp');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': cleanEmail}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final success = response.statusCode == 200 && (data['success'] == true);
      final message = data['message'] as String? ?? (success ? 'OTP resent successfully.' : 'Failed to resend OTP.');

      if (success) {
        _pendingEmail = cleanEmail;
      }

      _isLoading = false;
      notifyListeners();

      return AuthResponse(
        success: success,
        message: message,
        expiresInSeconds: data['expiresInSeconds'] as int? ?? 300,
      );
    } catch (e) {
      _isLoading = false;
      notifyListeners();

      return AuthResponse(
        success: false,
        message: 'Cannot connect to server. Please try again.',
      );
    }
  }

  /// 3. Verify OTP against MySQL backend & detect existing user
  Future<AuthResponse> verifyOtp(String otp) async {
    _isLoading = true;
    notifyListeners();

    final email = _pendingEmail ?? _user.email;
    final cleanOtp = otp.trim();
    final url = Uri.parse('$_baseUrl/api/verify-email-otp');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'otp': cleanOtp,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final success = response.statusCode == 200 && (data['success'] == true);
      final message = data['message'] as String? ?? (success ? 'Verified successfully.' : 'Wrong OTP');
      final token = data['token'] as String?;
      final isExistingUser = data['isExistingUser'] == true;
      final userData = data['user'] as Map<String, dynamic>?;

      if (success) {
        if (isExistingUser && userData != null) {
          // Populate existing user profile from database
          _user = UserProfile(
            userId: userData['userId'] as String? ?? "U${userData['id'] ?? '001'}",
            name: TextUtils.capitalizeWords(userData['full_name'] as String? ?? userData['name'] as String? ?? ""),
            phone: userData['mobile_number'] as String? ?? userData['phone'] as String? ?? "",
            countryCode: userData['country_code'] as String? ?? "+91",
            email: userData['email'] as String? ?? email,
            address: userData['full_address'] as String? ?? userData['address'] as String? ?? "",
            locality: userData['locality'] as String? ?? "",
            city: userData['city'] as String? ?? "",
            state: userData['state'] as String? ?? "",
            country: userData['country'] as String? ?? "",
            latitude: (userData['latitude'] as num?)?.toDouble() ?? 0.0,
            longitude: (userData['longitude'] as num?)?.toDouble() ?? 0.0,
            location: (userData['city'] != null && (userData['city'] as String).isNotEmpty)
                ? (userData['city'] as String)
                : (userData['locality'] as String? ?? "Tirunelveli"),
            isLoggedIn: true,
            authToken: token,
          );
          ApiClient().setAuthToken(token);
          ApiClient().setCurrentUser(userId: _user.userId, email: _user.email);
        } else {
          // Prepare new user state with verified email
          _user.email = email;
          _user.authToken = token;
          _user.isLoggedIn = false; // Registration required before logged in
          ApiClient().setAuthToken(token);
          ApiClient().setCurrentUser(email: email);
        }
        await _saveSession();
      }

      _isLoading = false;
      notifyListeners();

      return AuthResponse(
        success: success,
        message: message,
        token: token,
        isExistingUser: isExistingUser,
        userData: userData,
      );
    } catch (e) {
      _isLoading = false;
      notifyListeners();

      return AuthResponse(
        success: false,
        message: 'Cannot connect to server. Please try again.',
      );
    }
  }

  /// 4. Register a new user with Name and Address only
  Future<AuthResponse> registerUser({
    required String name,
    required String email,
    required String address,
    String locality = '',
    String city = '',
    String state = '',
    String country = '',
    double latitude = 0.0,
    double longitude = 0.0,
  }) async {
    _isLoading = true;
    notifyListeners();

    final cleanEmail = email.trim().toLowerCase();
    final cleanName = TextUtils.capitalizeWords(name.trim());
    final url = Uri.parse('$_baseUrl/api/register-user');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': cleanEmail,
              'full_name': cleanName,
              'name': cleanName,
              'full_address': address.trim(),
              'address': address.trim(),
              'locality': locality.trim(),
              'city': city.trim(),
              'state': state.trim(),
              'country': country.trim(),
              'latitude': latitude,
              'longitude': longitude,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final success = (response.statusCode == 200 || response.statusCode == 201) && (data['success'] == true);
      final message = data['message'] as String? ?? (success ? 'User registered successfully!' : 'Failed to register.');
      final token = data['token'] as String?;
      final userData = data['user'] as Map<String, dynamic>?;

      if (success) {
        final id = userData?['id'] ?? DateTime.now().millisecondsSinceEpoch;
        _user = UserProfile(
          userId: userData?['userId'] as String? ?? "U${id.toString().padLeft(3, '0')}",
          name: cleanName,
          email: cleanEmail,
          address: address.trim(),
          locality: locality.trim(),
          city: city.trim(),
          state: state.trim(),
          country: country.trim(),
          latitude: latitude,
          longitude: longitude,
          location: city.isNotEmpty ? city : (locality.isNotEmpty ? locality : "Tirunelveli"),
          isLoggedIn: true,
          authToken: token ?? _user.authToken,
        );

        ApiClient().setAuthToken(_user.authToken);
        ApiClient().setCurrentUser(userId: _user.userId, email: _user.email);

        await _saveSession();
      }

      _isLoading = false;
      notifyListeners();

      return AuthResponse(
        success: success,
        message: message,
        token: token,
        userData: userData,
      );
    } catch (e) {
      _isLoading = false;
      notifyListeners();

      return AuthResponse(
        success: false,
        message: 'Cannot connect to server to save registration. Please try again.',
      );
    }
  }

  /// 5. Fetch user profile from database
  Future<void> fetchUserProfile() async {
    if (_user.email.isEmpty) return;

    final url = Uri.parse('$_baseUrl/api/user-profile?email=${Uri.encodeComponent(_user.email)}');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final userData = data['user'] as Map<String, dynamic>?;
        if (userData != null) {
          _user.userId = userData['userId'] as String? ?? _user.userId;
          _user.name = TextUtils.capitalizeWords(userData['full_name'] as String? ?? userData['name'] as String? ?? _user.name);
          _user.email = userData['email'] as String? ?? _user.email;
          _user.address = userData['full_address'] as String? ?? userData['address'] as String? ?? _user.address;
          _user.locality = userData['locality'] as String? ?? _user.locality;
          _user.city = userData['city'] as String? ?? _user.city;
          _user.state = userData['state'] as String? ?? _user.state;
          _user.country = userData['country'] as String? ?? _user.country;
          _user.latitude = (userData['latitude'] as num?)?.toDouble() ?? _user.latitude;
          _user.longitude = (userData['longitude'] as num?)?.toDouble() ?? _user.longitude;
          _user.location = _user.city.isNotEmpty ? _user.city : _user.locality;
          await _saveSession();
          notifyListeners();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching profile: $e");
      }
    }
  }

  /// 6. Update current user profile details in MySQL
  Future<bool> updateProfile({
    required String name,
    required String address,
    String? email,
    String locality = '',
    String city = '',
    String state = '',
    String country = '',
    double? latitude,
    double? longitude,
  }) async {
    _isLoading = true;
    notifyListeners();

    final cleanEmail = (email != null && email.isNotEmpty) ? email.trim().toLowerCase() : _user.email;
    final cleanName = TextUtils.capitalizeWords(name.trim());
    final url = Uri.parse('$_baseUrl/api/update-profile');

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': cleanEmail,
          'full_name': cleanName,
          'name': cleanName,
          'full_address': address.trim(),
          'address': address.trim(),
          'locality': locality.trim(),
          'city': city.trim(),
          'state': state.trim(),
          'country': country.trim(),
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
        }),
      ).timeout(const Duration(seconds: 12));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final success = response.statusCode == 200 && data['success'] == true;

      if (success) {
        _user.name = cleanName;
        _user.email = cleanEmail;
        _user.address = address.trim();
        _user.locality = locality.trim();
        _user.city = city.trim();
        _user.state = state.trim();
        _user.country = country.trim();
        if (latitude != null) _user.latitude = latitude;
        if (longitude != null) _user.longitude = longitude;
        _user.location = _user.city.isNotEmpty ? _user.city : (_user.locality.isNotEmpty ? _user.locality : _user.location);
        await _saveSession();
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 7. Logout current user and clear session.
  Future<void> logout() async {
    _user = UserProfile(
      userId: "",
      name: "",
      phone: "",
      countryCode: "+91",
      email: "",
      address: "",
      locality: "",
      city: "",
      state: "",
      country: "",
      latitude: 0.0,
      longitude: 0.0,
      location: "",
      isLoggedIn: false,
    );
    _isOtpSent = false;
    _pendingEmail = null;
    ApiClient().clearSession();

    try {
      final file = await _getSessionFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error clearing session: $e");
      }
    }
    notifyListeners();
  }
}
