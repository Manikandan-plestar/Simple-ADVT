class TargetLocationModel {
  final String placeId;
  final String name;
  final String type; // 'country', 'state', 'city', 'locality'
  final String country;
  final String countryCode;
  final String? state;
  final String? city;
  final double latitude;
  final double longitude;
  final String? formattedAddress;
  final double? distanceInKm;

  const TargetLocationModel({
    required this.placeId,
    required this.name,
    required this.type,
    String? country,
    String? countryName,
    this.countryCode = '',
    String? state,
    String? stateName,
    String? city,
    String? cityName,
    required this.latitude,
    required this.longitude,
    this.formattedAddress,
    this.distanceInKm,
  })  : country = country ?? countryName ?? '',
        state = state ?? stateName,
        city = city ?? cityName;

  /// Convenience getters for consistency across services and UI
  String get countryName => country;
  String? get stateName => state;
  String? get cityName => city;

  /// Formatted distance string (e.g. "3.2 km")
  String? get formattedDistance {
    if (distanceInKm == null) return null;
    if (distanceInKm! < 1.0) {
      return '${(distanceInKm! * 1000).round()} m';
    }
    return '${distanceInKm!.toStringAsFixed(1)} km';
  }

  /// Readable hierarchy breadcrumb (e.g. "Palayamkottai, Tirunelveli, Tamil Nadu, India")
  String get displayHierarchy {
    if (formattedAddress != null && formattedAddress!.isNotEmpty) {
      return formattedAddress!;
    }
    final parts = <String>[];
    parts.add(name);
    if (city != null && city!.isNotEmpty && city != name) parts.add(city!);
    if (state != null && state!.isNotEmpty && state != name) parts.add(state!);
    if (country.isNotEmpty && country != name) parts.add(country);
    return parts.join(', ');
  }

  /// Type label display
  String get typeLabel {
    switch (type.toLowerCase()) {
      case 'country':
        return 'Country';
      case 'state':
        return 'State';
      case 'city':
      case 'district':
        return 'City / District';
      case 'locality':
      case 'sublocality':
      case 'area':
        return 'Locality';
      default:
        return 'Area';
    }
  }

  TargetLocationModel copyWith({
    String? placeId,
    String? name,
    String? type,
    String? country,
    String? countryCode,
    String? state,
    String? city,
    double? latitude,
    double? longitude,
    String? formattedAddress,
    double? distanceInKm,
  }) {
    return TargetLocationModel(
      placeId: placeId ?? this.placeId,
      name: name ?? this.name,
      type: type ?? this.type,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      state: state ?? this.state,
      city: city ?? this.city,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      distanceInKm: distanceInKm ?? this.distanceInKm,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'placeId': placeId,
      'name': name,
      'type': type,
      'country': country,
      'countryCode': countryCode,
      'state': state,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      'formattedAddress': formattedAddress,
      'distanceInKm': distanceInKm,
    };
  }

  factory TargetLocationModel.fromMap(Map<String, dynamic> map) {
    return TargetLocationModel(
      placeId: map['placeId'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? 'locality',
      country: map['country'] ?? map['countryName'] ?? '',
      countryCode: map['countryCode'] ?? '',
      state: map['state'] ?? map['stateName'],
      city: map['city'] ?? map['cityName'],
      latitude: (map['latitude'] is num) ? (map['latitude'] as num).toDouble() : 0.0,
      longitude: (map['longitude'] is num) ? (map['longitude'] as num).toDouble() : 0.0,
      formattedAddress: map['formattedAddress'],
      distanceInKm: (map['distanceInKm'] is num) ? (map['distanceInKm'] as num).toDouble() : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TargetLocationModel &&
          runtimeType == other.runtimeType &&
          placeId == other.placeId;

  @override
  int get hashCode => placeId.hashCode;
}

