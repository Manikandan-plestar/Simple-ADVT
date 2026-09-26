import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationDetails {
  final String area;
  final String city;
  final String district;
  final String state;
  final String country;
  final String postalCode;
  final String fullAddress;
  final double latitude;
  final double longitude;

  LocationDetails({
    required this.area,
    required this.city,
    required this.district,
    required this.state,
    required this.country,
    this.postalCode = '',
    this.fullAddress = '',
    required this.latitude,
    required this.longitude,
  });

  String get formattedAddress {
    if (fullAddress.isNotEmpty) return fullAddress;
    final parts = [area, city, state].where((p) => p.trim().isNotEmpty).toList();
    return parts.join(', ');
  }
}

class LocationService extends ChangeNotifier {
  LocationDetails _currentLocation = LocationDetails(
    area: "",
    city: "",
    district: "",
    state: "",
    country: "",
    latitude: 0.0,
    longitude: 0.0,
  );

  bool _hasPermission = false;
  bool _isFetching = false;

  LocationDetails get currentLocation => _currentLocation;
  bool get hasPermission => _hasPermission;
  bool get isFetching => _isFetching;

  /// Purpose: Request location permission from the user.
  Future<bool> requestPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _hasPermission = false;
        notifyListeners();
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _hasPermission = false;
          notifyListeners();
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _hasPermission = false;
        notifyListeners();
        return false;
      }

      _hasPermission = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Error requesting location permission: $e");
      return false;
    }
  }

  /// Purpose: Get current user GPS location and reverse geocode into address details.
  Future<LocationDetails> getCurrentLocation() async {
    _isFetching = true;
    notifyListeners();

    try {
      // 1. Get real GPS coordinates from device
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // 2. Reverse geocode coordinates to readable placemarks
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;

        String street = place.street ?? '';
        String subLocality = place.subLocality ?? '';
        String locality = place.locality ?? '';
        String subAdmin = place.subAdministrativeArea ?? '';
        String admin = place.administrativeArea ?? '';
        String postal = place.postalCode ?? '';
        String country = place.country ?? '';

        String area = subLocality.isNotEmpty
            ? subLocality
            : (street.isNotEmpty ? street : (locality.isNotEmpty ? locality : "Local Area"));
        String city = locality.isNotEmpty
            ? locality
            : (subAdmin.isNotEmpty ? subAdmin : (admin.isNotEmpty ? admin : "City"));
        String district = subAdmin.isNotEmpty ? subAdmin : city;
        String state = admin.isNotEmpty ? admin : (district.isNotEmpty ? district : "State");
        if (country.trim().isEmpty) country = "India";

        // Construct readable full address
        List<String> addressParts = [];
        if (street.isNotEmpty) addressParts.add(street);
        if (subLocality.isNotEmpty && subLocality != street) addressParts.add(subLocality);
        if (locality.isNotEmpty && locality != subLocality) addressParts.add(locality);
        if (admin.isNotEmpty) {
          if (postal.isNotEmpty) {
            addressParts.add("$admin - $postal");
          } else {
            addressParts.add(admin);
          }
        }
        if (country.isNotEmpty && !addressParts.contains(country)) {
          addressParts.add(country);
        }

        String full = addressParts.isNotEmpty
            ? addressParts.join(', ')
            : "$area, $city, $state, $country";

        _currentLocation = LocationDetails(
          area: area,
          city: city,
          district: district,
          state: state,
          country: country,
          postalCode: postal,
          fullAddress: full,
          latitude: position.latitude,
          longitude: position.longitude,
        );
      }
    } catch (e) {
      debugPrint("Error fetching GPS location / geocoding: $e");
      rethrow;
    } finally {
      _isFetching = false;
      notifyListeners();
    }

    return _currentLocation;
  }

  /// Purpose: Update selected location manually.
  void setLocation(LocationDetails newLoc) {
    _currentLocation = newLoc;
    notifyListeners();
  }
}
