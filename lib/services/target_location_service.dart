import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import '../models/target_location_model.dart';

class TargetLocationFilterResult {
  final List<TargetLocationModel> updatedLocations;
  final List<TargetLocationModel> removedChildLocations;
  final bool wasAlreadyCovered;
  final TargetLocationModel? coveringParent;

  TargetLocationFilterResult({
    required this.updatedLocations,
    required this.removedChildLocations,
    this.wasAlreadyCovered = false,
    this.coveringParent,
  });
}

class TargetLocationService {
  static final TargetLocationService _instance = TargetLocationService._internal();
  factory TargetLocationService() => _instance;
  TargetLocationService._internal();

  /// In-memory session cache to avoid redundant API / Geocoding lookups
  final Map<String, List<TargetLocationModel>> _cache = {};

  // ==========================================
  // DYNAMIC TAB VISIBILITY RESOLUTION RULE
  // ==========================================

  /// Reusable rule for determining which category tabs are visible
  /// - Initial / No context -> ['all']
  /// - Country selected -> ['all', 'state']
  /// - State selected -> ['all', 'state', 'city']
  /// - City selected after State -> ['all', 'state', 'city', 'locality']
  /// - Direct City selected -> ['all', 'city', 'locality'] (no state forced)
  /// - Direct Locality selected -> ['all', 'locality']
  List<String> getAvailableTabsForSelections(
    List<TargetLocationModel> selectedLocations, {
    TargetLocationModel? activeSearchContext,
  }) {
    if (selectedLocations.isEmpty && activeSearchContext == null) {
      return const ['all'];
    }

    final effectiveLocations = List<TargetLocationModel>.from(selectedLocations);
    if (activeSearchContext != null &&
        !effectiveLocations.any((e) => isSameLocation(e, activeSearchContext))) {
      effectiveLocations.add(activeSearchContext);
    }

    final hasCountry = effectiveLocations.any((e) => e.type == 'country');
    final hasState = effectiveLocations.any((e) =>
        e.type == 'state' || e.type == 'province' || e.type == 'region' || e.type == 'administrative_area_level_1');
    final hasCity = effectiveLocations.any((e) =>
        e.type == 'city' || e.type == 'district' || e.type == 'administrative_area_level_2');
    final hasLocality = effectiveLocations.any((e) =>
        e.type == 'locality' || e.type == 'sublocality' || e.type == 'neighborhood' || e.type == 'sublocality_level_1');

    final tabs = <String>['all'];

    if (hasCountry && !hasState && !hasCity && !hasLocality) {
      // 1. Only Country selected -> All Areas | State
      tabs.add('state');
    } else if (hasState && !hasCity && !hasLocality) {
      // 2. State selected -> All Areas | State | City/District
      tabs.add('state');
      tabs.add('city');
    } else if (hasCity && !hasLocality) {
      // 3. City selected
      if (hasState) tabs.add('state');
      tabs.add('city');
      tabs.add('locality');
    } else if (hasLocality) {
      // 4. Locality selected directly or with parent
      if (hasState) tabs.add('state');
      if (hasCity) tabs.add('city');
      tabs.add('locality');
    } else {
      // Fallback
      if (hasCountry || hasState) tabs.add('state');
      if (hasState || hasCity) tabs.add('city');
      if (hasCity || hasLocality) tabs.add('locality');
    }

    return tabs;
  }

  // ==========================================
  // HIERARCHY & CONTAINMENT FILTERING LOGIC
  // ==========================================

  /// Normalize string helper
  String _clean(String? val) => (val ?? '').trim().toLowerCase();

  /// Hierarchy rank (lower number = broader geographic scope)
  int getHierarchyRank(String type) {
    switch (type.toLowerCase()) {
      case 'country':
        return 1;
      case 'state':
      case 'province':
      case 'region':
      case 'administrative_area_level_1':
        return 2;
      case 'city':
      case 'district':
      case 'administrative_area_level_2':
        return 3;
      case 'locality':
      case 'sublocality':
      case 'neighborhood':
      case 'sublocality_level_1':
      case 'area':
        return 4;
      default:
        return 5;
    }
  }

  /// Check if two location objects represent the exact same geographic unit
  bool isSameLocation(TargetLocationModel a, TargetLocationModel b) {
    if (a.placeId.isNotEmpty && b.placeId.isNotEmpty && a.placeId == b.placeId) {
      return true;
    }
    if (_clean(a.name) == _clean(b.name) &&
        getHierarchyRank(a.type) == getHierarchyRank(b.type) &&
        _clean(a.cityName) == _clean(b.cityName) &&
        _clean(a.stateName) == _clean(b.stateName) &&
        (_clean(a.countryName) == _clean(b.countryName) ||
            (a.countryCode.isNotEmpty && a.countryCode.toLowerCase() == b.countryCode.toLowerCase()))) {
      return true;
    }
    return false;
  }

  /// Check if location [parent] geographically contains location [child]
  bool isParent(TargetLocationModel parent, TargetLocationModel child) {
    if (isSameLocation(parent, child)) return false;

    final parentRank = getHierarchyRank(parent.type);
    final childRank = getHierarchyRank(child.type);

    // Parent must be strictly broader in scope
    if (parentRank >= childRank) return false;

    final pCountry = _clean(parent.countryName.isNotEmpty ? parent.countryName : parent.name);
    final cCountry = _clean(child.countryName.isNotEmpty ? child.countryName : child.name);
    final pCountryCode = _clean(parent.countryCode);
    final cCountryCode = _clean(child.countryCode);

    final sameCountry = pCountry.isEmpty ||
        cCountry.isEmpty ||
        pCountry == cCountry ||
        (pCountryCode.isNotEmpty && cCountryCode.isNotEmpty && pCountryCode == cCountryCode);

    // 1. Parent is Country (rank 1)
    if (parentRank == 1) {
      if (sameCountry) return true;
      if (_clean(child.countryName) == pCountry || _clean(child.name) == pCountry) return true;
      if (pCountryCode.isNotEmpty && cCountryCode == pCountryCode) return true;
      return false;
    }

    // State, City, Locality must share country
    if (!sameCountry) return false;

    final pState = _clean(parent.stateName?.isNotEmpty == true ? parent.stateName : parent.name);
    final cState = _clean(child.stateName?.isNotEmpty == true ? child.stateName : child.name);

    // 2. Parent is State (rank 2)
    if (parentRank == 2) {
      if (cState.isNotEmpty && (cState == pState || _clean(child.name) == pState)) {
        return true;
      }
      if (cState.isEmpty && pState.isNotEmpty) {
        // Fallback: check proximity if coordinates exist
        final dist = calculateDistanceKm(parent.latitude, parent.longitude, child.latitude, child.longitude);
        return dist < 350.0;
      }
      return false;
    }

    final pCity = _clean(parent.cityName?.isNotEmpty == true ? parent.cityName : parent.name);
    final cCity = _clean(child.cityName?.isNotEmpty == true ? child.cityName : child.name);

    // 3. Parent is City / District (rank 3)
    if (parentRank == 3) {
      if (childRank >= 4) {
        if (cCity.isNotEmpty && (cCity == pCity || _clean(child.name) == pCity)) {
          return true;
        }
        // Distance check fallback: locality within 45km of city center
        final dist = calculateDistanceKm(parent.latitude, parent.longitude, child.latitude, child.longitude);
        return dist < 45.0;
      }
    }

    return false;
  }

  /// Check if location [child] is geographically contained within [parent]
  bool isChild(TargetLocationModel child, TargetLocationModel parent) {
    return isParent(parent, child);
  }

  /// Check if [candidate] is already covered (either exact match or child) by [existing]
  bool isCoveredBy(TargetLocationModel candidate, TargetLocationModel existing) {
    return isSameLocation(candidate, existing) || isParent(existing, candidate);
  }

  /// Given a list of target locations, removes all locations that are already covered
  /// by a broader parent location present in the same list.
  List<TargetLocationModel> removeCoveredLocations(List<TargetLocationModel> locations) {
    if (locations.length <= 1) return List.from(locations);

    final uniqueList = <TargetLocationModel>[];
    for (final loc in locations) {
      if (!uniqueList.any((e) => isSameLocation(e, loc))) {
        uniqueList.add(loc);
      }
    }

    final result = <TargetLocationModel>[];
    for (final candidate in uniqueList) {
      bool coveredByOther = false;
      for (final other in uniqueList) {
        if (!identical(candidate, other) && isParent(other, candidate)) {
          coveredByOther = true;
          break;
        }
      }
      if (!coveredByOther) {
        result.add(candidate);
      }
    }

    return result;
  }

  /// Handles adding a new location to an existing selection list, applying all
  /// forward and reverse containment rules.
  TargetLocationFilterResult addAndFilterLocation({
    required List<TargetLocationModel> currentLocations,
    required TargetLocationModel newLocation,
  }) {
    // 1. Check if the new location is already covered by any currently selected parent
    for (final existing in currentLocations) {
      if (isCoveredBy(newLocation, existing)) {
        return TargetLocationFilterResult(
          updatedLocations: List.from(currentLocations),
          removedChildLocations: [],
          wasAlreadyCovered: true,
          coveringParent: existing,
        );
      }
    }

    // 2. Add the new location
    final combined = List<TargetLocationModel>.from(currentLocations)..add(newLocation);

    // 3. Find which current child locations will be covered & removed by this new broader parent
    final removedChildren = <TargetLocationModel>[];
    for (final existing in currentLocations) {
      if (isParent(newLocation, existing)) {
        removedChildren.add(existing);
      }
    }

    // 4. Run hierarchy cleanup
    final filtered = removeCoveredLocations(combined);

    return TargetLocationFilterResult(
      updatedLocations: filtered,
      removedChildLocations: removedChildren,
      wasAlreadyCovered: false,
    );
  }

  // ==========================================
  // DISTANCE CALCULATION & PROXIMITY SORTING
  // ==========================================

  /// Calculate distance between two GPS coordinates in kilometers (Haversine Formula)
  double calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    if (lat1 == 0.0 && lon1 == 0.0) return 99999.0;
    if (lat2 == 0.0 && lon2 == 0.0) return 99999.0;

    const double earthRadiusKm = 6371.0;
    final double dLat = _degToRad(lat2 - lat1);
    final double dLon = _degToRad(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) * math.cos(_degToRad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);

  /// Annotate items with distance from user and sort nearest first
  List<TargetLocationModel> sortByProximity(
    List<TargetLocationModel> items, {
    double? userLat,
    double? userLng,
  }) {
    if (userLat == null || userLng == null || (userLat == 0.0 && userLng == 0.0)) {
      return items;
    }

    final List<TargetLocationModel> annotated = items.map<TargetLocationModel>((item) {
      final distance = calculateDistanceKm(userLat, userLng, item.latitude, item.longitude);
      return item.copyWith(distanceInKm: distance);
    }).toList();

    annotated.sort((a, b) {
      final distA = a.distanceInKm ?? 999999.0;
      final distB = b.distanceInKm ?? 999999.0;
      return distA.compareTo(distB);
    });

    return annotated;
  }

  /// Geographically finds nearby independent locations relative to a reference target location
  /// using latitude and longitude proximity.
  /// Automatically excludes any locations contained within (child/covered) or covering (parent) the reference location!
  Future<List<TargetLocationModel>> getNearbyLocationsForReference({
    required TargetLocationModel referenceLocation,
    int limit = 20,
    List<TargetLocationModel>? excludeLocations,
  }) async {
    final allKnown = <TargetLocationModel>[
      ...defaultLocations,
      ..._indianStates,
      ..._usStates,
      ..._uaeEmirates,
      ..._ukRegions,
      ..._singaporeRegions,
      ..._australiaStates,
      ..._canadaProvinces,
      ..._worldwideCountries,
    ];

    final candidates = <TargetLocationModel>[];
    for (final loc in allKnown) {
      if (isSameLocation(loc, referenceLocation)) continue;
      if (loc.placeId == referenceLocation.placeId) continue;

      // Do NOT include locations contained within the selected location (e.g. child localities when selecting city)
      if (isParent(referenceLocation, loc) || isCoveredBy(loc, referenceLocation)) {
        continue;
      }

      // Do NOT include locations that contain the selected location (e.g. country/state when selecting city)
      if (isParent(loc, referenceLocation) || isCoveredBy(referenceLocation, loc)) {
        continue;
      }

      // Exclude already selected locations if provided
      if (excludeLocations != null &&
          excludeLocations.any((e) => isSameLocation(e, loc) || e.placeId == loc.placeId)) {
        continue;
      }

      final dist = calculateDistanceKm(
        referenceLocation.latitude,
        referenceLocation.longitude,
        loc.latitude,
        loc.longitude,
      );

      // Max radius threshold: 180 km for localities/cities, 1200 km for states/countries
      final maxRadius = (referenceLocation.type == 'country' || referenceLocation.type == 'state') ? 1200.0 : 180.0;

      // Exclude localities that belong to the reference city
      if (referenceLocation.type == 'city' &&
          loc.type == 'locality' &&
          _clean(loc.cityName) == _clean(referenceLocation.cityName)) {
        continue;
      }

      if (dist <= maxRadius) {
        if (!candidates.any((c) => isSameLocation(c, loc))) {
          candidates.add(loc.copyWith(distanceInKm: dist));
        }
      }
    }

    // Sort strictly by proximity to the reference location (nearest first)
    candidates.sort((a, b) {
      final distA = a.distanceInKm ?? 999999.0;
      final distB = b.distanceInKm ?? 999999.0;
      return distA.compareTo(distB);
    });

    if (candidates.length > limit) {
      return candidates.sublist(0, limit);
    }
    return candidates;
  }

  /// Geographically finds all covered / contained child locations for a reference target location
  /// based on administrative hierarchy and structured containment rules.
  /// (e.g. For Tirunelveli -> returns Palayamkottai, Samathanapuram, KTC Nagar, Melapalayam, etc.)
  /// (e.g. For Tamil Nadu -> returns Tirunelveli, Madurai, Chennai, etc.)
  /// (e.g. For California -> returns Los Angeles, San Francisco, etc.)
  /// (e.g. For India / US -> returns states/provinces)
  Future<List<TargetLocationModel>> getCoveredLocationsForReference({
    required TargetLocationModel referenceLocation,
    int limit = 15,
  }) async {
    final allKnown = <TargetLocationModel>[
      ...defaultLocations,
      ..._indianStates,
      ..._usStates,
      ..._uaeEmirates,
      ..._ukRegions,
      ..._singaporeRegions,
      ..._australiaStates,
      ..._canadaProvinces,
      ..._germanyStates,
      ..._worldwideCountries,
    ];

    final covered = <TargetLocationModel>[];

    for (final loc in allKnown) {
      if (isSameLocation(loc, referenceLocation)) continue;
      if (loc.placeId == referenceLocation.placeId) continue;

      // Containment check: referenceLocation is parent of loc
      if (isParent(referenceLocation, loc) || isChild(loc, referenceLocation)) {
        if (!covered.any((c) => isSameLocation(c, loc))) {
          final dist = calculateDistanceKm(
            referenceLocation.latitude,
            referenceLocation.longitude,
            loc.latitude,
            loc.longitude,
          );
          covered.add(loc.copyWith(distanceInKm: dist));
        }
      }
    }

    // Dynamic country/state containment fallback
    if (referenceLocation.type == 'country' && covered.isEmpty) {
      final states = await getStatesForCountry(
        countryName: referenceLocation.name,
        countryCode: referenceLocation.countryCode,
      );
      for (final s in states) {
        if (!covered.any((c) => isSameLocation(c, s))) {
          covered.add(s);
        }
      }
    } else if (referenceLocation.type == 'state' && covered.isEmpty) {
      final cities = await getCitiesForContext(
        countryName: referenceLocation.countryName,
        stateName: referenceLocation.name,
      );
      for (final c in cities) {
        if (!covered.any((item) => isSameLocation(item, c))) {
          covered.add(c);
        }
      }
    }

    // Sort covered locations by distance
    covered.sort((a, b) {
      final distA = a.distanceInKm ?? 0.0;
      final distB = b.distanceInKm ?? 0.0;
      return distA.compareTo(distB);
    });

    if (covered.length > limit) {
      return covered.sublist(0, limit);
    }
    return covered;
  }

  // ==========================================
  // DYNAMIC LAZY LOADERS
  // ==========================================

  /// Fetch administrative Level 1 regions (States / Provinces) dynamically for any selected Country
  Future<List<TargetLocationModel>> getStatesForCountry({
    required String countryName,
    String? countryCode,
    double? userLat,
    double? userLng,
  }) async {
    final cacheKey = 'states_${_clean(countryName)}_${_clean(countryCode)}';
    if (_cache.containsKey(cacheKey)) {
      return sortByProximity(_cache[cacheKey]!, userLat: userLat, userLng: userLng);
    }

    final results = <TargetLocationModel>[];
    final cleanC = _clean(countryName);

    if (cleanC.contains('india') || countryCode?.toUpperCase() == 'IN') {
      results.addAll(_indianStates);
    } else if (cleanC.contains('united states') || cleanC.contains('usa') || countryCode?.toUpperCase() == 'US') {
      results.addAll(_usStates);
    } else if (cleanC.contains('emirates') || cleanC.contains('uae') || countryCode?.toUpperCase() == 'AE') {
      results.addAll(_uaeEmirates);
    } else if (cleanC.contains('kingdom') || cleanC.contains('uk') || countryCode?.toUpperCase() == 'GB') {
      results.addAll(_ukRegions);
    } else if (cleanC.contains('singapore') || countryCode?.toUpperCase() == 'SG') {
      results.addAll(_singaporeRegions);
    } else if (cleanC.contains('australia') || countryCode?.toUpperCase() == 'AU') {
      results.addAll(_australiaStates);
    } else if (cleanC.contains('canada') || countryCode?.toUpperCase() == 'CA') {
      results.addAll(_canadaProvinces);
    } else if (cleanC.contains('germany') || countryCode?.toUpperCase() == 'DE') {
      results.addAll(_germanyStates);
    } else {
      results.addAll(_getGenericCountryStates(countryName, countryCode ?? ''));
    }

    _cache[cacheKey] = results;
    return sortByProximity(results, userLat: userLat, userLng: userLng);
  }

  /// Fetch Cities / Districts dynamically for the selected Country & State context
  Future<List<TargetLocationModel>> getCitiesForContext({
    required String countryName,
    String? countryCode,
    String? stateName,
    double? userLat,
    double? userLng,
  }) async {
    final cacheKey = 'cities_${_clean(countryName)}_${_clean(stateName)}';
    if (_cache.containsKey(cacheKey)) {
      return sortByProximity(_cache[cacheKey]!, userLat: userLat, userLng: userLng);
    }

    final results = <TargetLocationModel>[];
    final cleanCountry = _clean(countryName);
    final cleanState = _clean(stateName);

    for (final loc in defaultLocations) {
      if (loc.type == 'city') {
        final matchCountry = _clean(loc.countryName) == cleanCountry ||
            _clean(loc.countryCode) == _clean(countryCode) ||
            cleanCountry.isEmpty;
        final matchState = cleanState.isEmpty || _clean(loc.stateName) == cleanState;
        if (matchCountry && matchState) {
          results.add(loc);
        }
      }
    }

    if (results.length < 4) {
      final dynamicCities = _getDynamicCitiesForRegion(countryName, stateName ?? '');
      for (final c in dynamicCities) {
        if (!results.any((r) => isSameLocation(r, c))) {
          results.add(c);
        }
      }
    }

    _cache[cacheKey] = results;
    return sortByProximity(results, userLat: userLat, userLng: userLng);
  }

  /// Fetch Localities / Areas dynamically for the selected Context (Country, State, City)
  Future<List<TargetLocationModel>> getLocalitiesForContext({
    required String countryName,
    String? countryCode,
    String? stateName,
    String? cityName,
    double? userLat,
    double? userLng,
  }) async {
    final cacheKey = 'localities_${_clean(countryName)}_${_clean(stateName)}_${_clean(cityName)}';
    if (_cache.containsKey(cacheKey)) {
      return sortByProximity(_cache[cacheKey]!, userLat: userLat, userLng: userLng);
    }

    final results = <TargetLocationModel>[];
    final cleanCountry = _clean(countryName);
    final cleanState = _clean(stateName);
    final cleanCity = _clean(cityName);

    for (final loc in defaultLocations) {
      if (loc.type == 'locality') {
        final matchCountry = _clean(loc.countryName) == cleanCountry ||
            _clean(loc.countryCode) == _clean(countryCode) ||
            cleanCountry.isEmpty;
        final matchState = cleanState.isEmpty || _clean(loc.stateName) == cleanState;
        final matchCity = cleanCity.isEmpty || _clean(loc.cityName) == cleanCity;

        if (matchCountry && matchState && matchCity) {
          results.add(loc);
        }
      }
    }

    if (results.length < 3 && cityName != null && cityName.isNotEmpty) {
      final dynamicLocs = _getDynamicLocalitiesForCity(countryName, stateName ?? '', cityName);
      for (final l in dynamicLocs) {
        if (!results.any((r) => isSameLocation(r, l))) {
          results.add(l);
        }
      }
    }

    _cache[cacheKey] = results;
    return sortByProximity(results, userLat: userLat, userLng: userLng);
  }

  /// Search locations across all levels (Country, State, City, Locality) worldwide
  Future<List<TargetLocationModel>> searchWorldwideLocations(
    String query, {
    String? filterType,
    String? countryContext,
    double? userLat,
    double? userLng,
  }) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return [];

    final cacheKey = 'search_${cleanQuery}_${_clean(filterType)}_${_clean(countryContext)}';
    if (_cache.containsKey(cacheKey)) {
      return sortByProximity(_cache[cacheKey]!, userLat: userLat, userLng: userLng);
    }

    final matches = <TargetLocationModel>[];

    final allKnown = <TargetLocationModel>[
      ..._worldwideCountries,
      ...defaultLocations,
      ..._usStates,
      ..._indianStates,
      ..._uaeEmirates,
      ..._ukRegions,
      ..._singaporeRegions,
      ..._australiaStates,
      ..._canadaProvinces,
    ];

    for (final loc in allKnown) {
      if (filterType != null && filterType != 'all') {
        if (_clean(loc.type) != _clean(filterType)) continue;
      }

      if (countryContext != null && countryContext.isNotEmpty && loc.type != 'country') {
        if (_clean(loc.countryName) != _clean(countryContext) &&
            _clean(loc.countryCode) != _clean(countryContext)) {
          continue;
        }
      }

      final nameMatch = _clean(loc.name).contains(cleanQuery);
      final cityMatch = _clean(loc.cityName).contains(cleanQuery);
      final stateMatch = _clean(loc.stateName).contains(cleanQuery);
      final countryMatch = _clean(loc.countryName).contains(cleanQuery);
      final addrMatch = _clean(loc.formattedAddress).contains(cleanQuery);

      if (nameMatch || cityMatch || stateMatch || countryMatch || addrMatch) {
        if (!matches.any((m) => isSameLocation(m, loc))) {
          matches.add(loc);
        }
      }
    }

    // Geocoding integration fallback for long/detailed searches
    if (cleanQuery.length >= 3 && matches.length < 5) {
      try {
        final geocoded = await _searchGeocoding(cleanQuery, countryFilter: countryContext);
        for (final item in geocoded) {
          if (!matches.any((m) => isSameLocation(m, item))) {
            matches.add(item);
          }
        }
      } catch (e) {
        debugPrint("Geocoding search fallback exception: $e");
      }
    }

    // Sort matches: Exact name matches first, then prefix matches, then substring matches
    matches.sort((a, b) {
      final cleanA = _clean(a.name);
      final cleanB = _clean(b.name);

      final rankA = (cleanA == cleanQuery)
          ? 0
          : (cleanA.startsWith(cleanQuery)
              ? 1
              : (cleanA.contains(cleanQuery) ? 2 : 3));
      final rankB = (cleanB == cleanQuery)
          ? 0
          : (cleanB.startsWith(cleanQuery)
              ? 1
              : (cleanB.contains(cleanQuery) ? 2 : 3));

      if (rankA != rankB) {
        return rankA.compareTo(rankB);
      }

      if (userLat != null && userLng != null) {
        final distA = calculateDistanceKm(userLat, userLng, a.latitude, a.longitude);
        final distB = calculateDistanceKm(userLat, userLng, b.latitude, b.longitude);
        return distA.compareTo(distB);
      }
      return 0;
    });

    _cache[cacheKey] = matches;
    return matches;
  }

  /// Backward-compatible search method
  Future<List<TargetLocationModel>> searchLocations(
    String query, {
    String? filterType,
    String? countryContext,
    double? userLat,
    double? userLng,
  }) async {
    return searchWorldwideLocations(
      query,
      filterType: filterType,
      countryContext: countryContext,
      userLat: userLat,
      userLng: userLng,
    );
  }

  /// Live Geocoding reverse lookup for custom places worldwide
  Future<List<TargetLocationModel>> _searchGeocoding(String query, {String? countryFilter}) async {
    final results = <TargetLocationModel>[];
    try {
      final lookupQuery = countryFilter != null && countryFilter.isNotEmpty
          ? '$query, $countryFilter'
          : query;
      final locations = await locationFromAddress(lookupQuery);

      for (final loc in locations.take(4)) {
        final placemarks = await placemarkFromCoordinates(loc.latitude, loc.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final street = p.street ?? '';
          final subLoc = p.subLocality ?? '';
          final locality = p.locality ?? '';
          final subAdmin = p.subAdministrativeArea ?? '';
          final admin = p.administrativeArea ?? '';
          final country = p.country ?? (countryFilter ?? 'India');
          final countryCode = p.isoCountryCode ?? '';

          String name = subLoc.isNotEmpty
              ? subLoc
              : (locality.isNotEmpty ? locality : (street.isNotEmpty ? street : (admin.isNotEmpty ? admin : country)));
          String type = subLoc.isNotEmpty
              ? 'locality'
              : (locality.isNotEmpty ? 'city' : (admin.isNotEmpty ? 'state' : 'country'));

          String city = locality.isNotEmpty ? locality : subAdmin;
          String state = admin;

          final model = TargetLocationModel(
            placeId: 'geo_${loc.latitude.toStringAsFixed(4)}_${loc.longitude.toStringAsFixed(4)}',
            name: name,
            type: type,
            countryCode: countryCode,
            countryName: country,
            stateName: state.isNotEmpty ? state : null,
            cityName: city.isNotEmpty ? city : null,
            latitude: loc.latitude,
            longitude: loc.longitude,
            formattedAddress: [name, city, state, country].where((s) => s.isNotEmpty).join(', '),
          );
          results.add(model);
        }
      }
    } catch (_) {}
    return results;
  }

  // ==========================================
  // STRUCTURED WORLDWIDE DATASETS
  // ==========================================

  List<TargetLocationModel> get worldwideCountries => _worldwideCountries;

  static const List<TargetLocationModel> _worldwideCountries = [
    TargetLocationModel(
      placeId: 'country_in',
      name: 'India',
      type: 'country',
      countryCode: 'IN',
      countryName: 'India',
      latitude: 20.5937,
      longitude: 78.9629,
      formattedAddress: 'India',
    ),
    TargetLocationModel(
      placeId: 'country_us',
      name: 'United States',
      type: 'country',
      countryCode: 'US',
      countryName: 'United States',
      latitude: 37.0902,
      longitude: -95.7129,
      formattedAddress: 'United States',
    ),
    TargetLocationModel(
      placeId: 'country_ae',
      name: 'United Arab Emirates',
      type: 'country',
      countryCode: 'AE',
      countryName: 'United Arab Emirates',
      latitude: 23.4241,
      longitude: 53.8478,
      formattedAddress: 'United Arab Emirates',
    ),
    TargetLocationModel(
      placeId: 'country_gb',
      name: 'United Kingdom',
      type: 'country',
      countryCode: 'GB',
      countryName: 'United Kingdom',
      latitude: 55.3781,
      longitude: -3.4360,
      formattedAddress: 'United Kingdom',
    ),
    TargetLocationModel(
      placeId: 'country_sg',
      name: 'Singapore',
      type: 'country',
      countryCode: 'SG',
      countryName: 'Singapore',
      latitude: 1.3521,
      longitude: 103.8198,
      formattedAddress: 'Singapore',
    ),
    TargetLocationModel(
      placeId: 'country_au',
      name: 'Australia',
      type: 'country',
      countryCode: 'AU',
      countryName: 'Australia',
      latitude: -25.2744,
      longitude: 133.7751,
      formattedAddress: 'Australia',
    ),
    TargetLocationModel(
      placeId: 'country_ca',
      name: 'Canada',
      type: 'country',
      countryCode: 'CA',
      countryName: 'Canada',
      latitude: 56.1304,
      longitude: -106.3468,
      formattedAddress: 'Canada',
    ),
    TargetLocationModel(
      placeId: 'country_de',
      name: 'Germany',
      type: 'country',
      countryCode: 'DE',
      countryName: 'Germany',
      latitude: 51.1657,
      longitude: 10.4515,
      formattedAddress: 'Germany',
    ),
  ];

  static const List<TargetLocationModel> _indianStates = [
    TargetLocationModel(
      placeId: 'state_in_tn',
      name: 'Tamil Nadu',
      type: 'state',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'Tamil Nadu',
      latitude: 11.1271,
      longitude: 78.6569,
      formattedAddress: 'Tamil Nadu, India',
    ),
    TargetLocationModel(
      placeId: 'state_in_kl',
      name: 'Kerala',
      type: 'state',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'Kerala',
      latitude: 10.8505,
      longitude: 76.2711,
      formattedAddress: 'Kerala, India',
    ),
    TargetLocationModel(
      placeId: 'state_in_ka',
      name: 'Karnataka',
      type: 'state',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'Karnataka',
      latitude: 15.3173,
      longitude: 75.7139,
      formattedAddress: 'Karnataka, India',
    ),
    TargetLocationModel(
      placeId: 'state_in_ap',
      name: 'Andhra Pradesh',
      type: 'state',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'Andhra Pradesh',
      latitude: 15.9129,
      longitude: 79.7400,
      formattedAddress: 'Andhra Pradesh, India',
    ),
    TargetLocationModel(
      placeId: 'state_in_ts',
      name: 'Telangana',
      type: 'state',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'Telangana',
      latitude: 18.1124,
      longitude: 79.0193,
      formattedAddress: 'Telangana, India',
    ),
    TargetLocationModel(
      placeId: 'state_in_mh',
      name: 'Maharashtra',
      type: 'state',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'Maharashtra',
      latitude: 19.7515,
      longitude: 75.7139,
      formattedAddress: 'Maharashtra, India',
    ),
    TargetLocationModel(
      placeId: 'state_in_dl',
      name: 'Delhi',
      type: 'state',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'Delhi',
      latitude: 28.7041,
      longitude: 77.1025,
      formattedAddress: 'Delhi, India',
    ),
    TargetLocationModel(
      placeId: 'state_in_gj',
      name: 'Gujarat',
      type: 'state',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'Gujarat',
      latitude: 22.2587,
      longitude: 71.1924,
      formattedAddress: 'Gujarat, India',
    ),
    TargetLocationModel(
      placeId: 'state_in_rj',
      name: 'Rajasthan',
      type: 'state',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'Rajasthan',
      latitude: 27.0238,
      longitude: 74.2179,
      formattedAddress: 'Rajasthan, India',
    ),
    TargetLocationModel(
      placeId: 'state_in_up',
      name: 'Uttar Pradesh',
      type: 'state',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'Uttar Pradesh',
      latitude: 26.8467,
      longitude: 80.9462,
      formattedAddress: 'Uttar Pradesh, India',
    ),
    TargetLocationModel(
      placeId: 'state_in_wb',
      name: 'West Bengal',
      type: 'state',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'West Bengal',
      latitude: 22.9868,
      longitude: 87.8550,
      formattedAddress: 'West Bengal, India',
    ),
  ];

  static const List<TargetLocationModel> _usStates = [
    TargetLocationModel(
      placeId: 'state_us_ca',
      name: 'California',
      type: 'state',
      countryCode: 'US',
      countryName: 'United States',
      stateName: 'California',
      latitude: 36.7783,
      longitude: -119.4179,
      formattedAddress: 'California, United States',
    ),
    TargetLocationModel(
      placeId: 'state_us_tx',
      name: 'Texas',
      type: 'state',
      countryCode: 'US',
      countryName: 'United States',
      stateName: 'Texas',
      latitude: 31.9686,
      longitude: -99.9018,
      formattedAddress: 'Texas, United States',
    ),
    TargetLocationModel(
      placeId: 'state_us_fl',
      name: 'Florida',
      type: 'state',
      countryCode: 'US',
      countryName: 'United States',
      stateName: 'Florida',
      latitude: 27.6648,
      longitude: -81.5158,
      formattedAddress: 'Florida, United States',
    ),
    TargetLocationModel(
      placeId: 'state_us_ny',
      name: 'New York',
      type: 'state',
      countryCode: 'US',
      countryName: 'United States',
      stateName: 'New York',
      latitude: 40.7128,
      longitude: -74.0060,
      formattedAddress: 'New York, United States',
    ),
    TargetLocationModel(
      placeId: 'state_us_wa',
      name: 'Washington',
      type: 'state',
      countryCode: 'US',
      countryName: 'United States',
      stateName: 'Washington',
      latitude: 47.7511,
      longitude: -120.7401,
      formattedAddress: 'Washington, United States',
    ),
  ];

  static const List<TargetLocationModel> _uaeEmirates = [
    TargetLocationModel(
      placeId: 'state_ae_dxb',
      name: 'Dubai',
      type: 'state',
      countryCode: 'AE',
      countryName: 'United Arab Emirates',
      stateName: 'Dubai',
      latitude: 25.2048,
      longitude: 55.2708,
      formattedAddress: 'Dubai, UAE',
    ),
    TargetLocationModel(
      placeId: 'state_ae_auh',
      name: 'Abu Dhabi',
      type: 'state',
      countryCode: 'AE',
      countryName: 'United Arab Emirates',
      stateName: 'Abu Dhabi',
      latitude: 24.4539,
      longitude: 54.3773,
      formattedAddress: 'Abu Dhabi, UAE',
    ),
    TargetLocationModel(
      placeId: 'state_ae_shj',
      name: 'Sharjah',
      type: 'state',
      countryCode: 'AE',
      countryName: 'United Arab Emirates',
      stateName: 'Sharjah',
      latitude: 25.3463,
      longitude: 55.4209,
      formattedAddress: 'Sharjah, UAE',
    ),
  ];

  static const List<TargetLocationModel> _ukRegions = [
    TargetLocationModel(
      placeId: 'state_gb_eng',
      name: 'England',
      type: 'state',
      countryCode: 'GB',
      countryName: 'United Kingdom',
      stateName: 'England',
      latitude: 52.3555,
      longitude: -1.1743,
      formattedAddress: 'England, United Kingdom',
    ),
    TargetLocationModel(
      placeId: 'state_gb_sct',
      name: 'Scotland',
      type: 'state',
      countryCode: 'GB',
      countryName: 'United Kingdom',
      stateName: 'Scotland',
      latitude: 56.4907,
      longitude: -4.2026,
      formattedAddress: 'Scotland, United Kingdom',
    ),
  ];

  static const List<TargetLocationModel> _singaporeRegions = [
    TargetLocationModel(
      placeId: 'state_sg_cen',
      name: 'Central Region',
      type: 'state',
      countryCode: 'SG',
      countryName: 'Singapore',
      stateName: 'Central Region',
      latitude: 1.2800,
      longitude: 103.8500,
      formattedAddress: 'Central Region, Singapore',
    ),
    TargetLocationModel(
      placeId: 'state_sg_east',
      name: 'East Region',
      type: 'state',
      countryCode: 'SG',
      countryName: 'Singapore',
      stateName: 'East Region',
      latitude: 1.3500,
      longitude: 103.9500,
      formattedAddress: 'East Region, Singapore',
    ),
  ];

  static const List<TargetLocationModel> _australiaStates = [
    TargetLocationModel(
      placeId: 'state_au_nsw',
      name: 'New South Wales',
      type: 'state',
      countryCode: 'AU',
      countryName: 'Australia',
      stateName: 'New South Wales',
      latitude: -31.8402,
      longitude: 145.6128,
      formattedAddress: 'New South Wales, Australia',
    ),
    TargetLocationModel(
      placeId: 'state_au_vic',
      name: 'Victoria',
      type: 'state',
      countryCode: 'AU',
      countryName: 'Australia',
      stateName: 'Victoria',
      latitude: -37.4713,
      longitude: 144.7852,
      formattedAddress: 'Victoria, Australia',
    ),
  ];

  static const List<TargetLocationModel> _canadaProvinces = [
    TargetLocationModel(
      placeId: 'state_ca_on',
      name: 'Ontario',
      type: 'state',
      countryCode: 'CA',
      countryName: 'Canada',
      stateName: 'Ontario',
      latitude: 51.2538,
      longitude: -85.3232,
      formattedAddress: 'Ontario, Canada',
    ),
    TargetLocationModel(
      placeId: 'state_ca_bc',
      name: 'British Columbia',
      type: 'state',
      countryCode: 'CA',
      countryName: 'Canada',
      stateName: 'British Columbia',
      latitude: 53.7267,
      longitude: -127.6476,
      formattedAddress: 'British Columbia, Canada',
    ),
  ];

  static const List<TargetLocationModel> _germanyStates = [
    TargetLocationModel(
      placeId: 'state_de_by',
      name: 'Bavaria',
      type: 'state',
      countryCode: 'DE',
      countryName: 'Germany',
      stateName: 'Bavaria',
      latitude: 48.7904,
      longitude: 11.4979,
      formattedAddress: 'Bavaria, Germany',
    ),
    TargetLocationModel(
      placeId: 'state_de_be',
      name: 'Berlin',
      type: 'state',
      countryCode: 'DE',
      countryName: 'Germany',
      stateName: 'Berlin',
      latitude: 52.5200,
      longitude: 13.4050,
      formattedAddress: 'Berlin, Germany',
    ),
  ];

  List<TargetLocationModel> _getGenericCountryStates(String countryName, String countryCode) {
    return [
      TargetLocationModel(
        placeId: 'state_${_clean(countryCode)}_reg1',
        name: 'Capital / Central Region',
        type: 'state',
        countryCode: countryCode,
        countryName: countryName,
        stateName: 'Capital / Central Region',
        latitude: 0.0,
        longitude: 0.0,
        formattedAddress: 'Capital / Central Region, $countryName',
      ),
      TargetLocationModel(
        placeId: 'state_${_clean(countryCode)}_reg2',
        name: 'Northern Region',
        type: 'state',
        countryCode: countryCode,
        countryName: countryName,
        stateName: 'Northern Region',
        latitude: 0.0,
        longitude: 0.0,
        formattedAddress: 'Northern Region, $countryName',
      ),
      TargetLocationModel(
        placeId: 'state_${_clean(countryCode)}_reg3',
        name: 'Southern Region',
        type: 'state',
        countryCode: countryCode,
        countryName: countryName,
        stateName: 'Southern Region',
        latitude: 0.0,
        longitude: 0.0,
        formattedAddress: 'Southern Region, $countryName',
      ),
    ];
  }

  List<TargetLocationModel> _getDynamicCitiesForRegion(String country, String state) {
    final cleanC = _clean(country);
    final cleanS = _clean(state);

    if (cleanC.contains('united states') || cleanC.contains('usa')) {
      if (cleanS.contains('california')) {
        return const [
          TargetLocationModel(
            placeId: 'city_us_la',
            name: 'Los Angeles',
            type: 'city',
            countryCode: 'US',
            countryName: 'United States',
            stateName: 'California',
            cityName: 'Los Angeles',
            latitude: 34.0522,
            longitude: -118.2437,
            formattedAddress: 'Los Angeles, California, US',
          ),
          TargetLocationModel(
            placeId: 'city_us_sf',
            name: 'San Francisco',
            type: 'city',
            countryCode: 'US',
            countryName: 'United States',
            stateName: 'California',
            cityName: 'San Francisco',
            latitude: 37.7749,
            longitude: -122.4194,
            formattedAddress: 'San Francisco, California, US',
          ),
        ];
      }
    }

    return [
      TargetLocationModel(
        placeId: 'city_${_clean(state)}_central',
        name: '$state Central District',
        type: 'city',
        countryName: country,
        stateName: state,
        cityName: '$state Central',
        latitude: 0.0,
        longitude: 0.0,
        formattedAddress: '$state Central, $country',
      ),
      TargetLocationModel(
        placeId: 'city_${_clean(state)}_metro',
        name: '$state Metro Area',
        type: 'city',
        countryName: country,
        stateName: state,
        cityName: '$state Metro Area',
        latitude: 0.0,
        longitude: 0.0,
        formattedAddress: '$state Metro Area, $country',
      ),
    ];
  }

  List<TargetLocationModel> _getDynamicLocalitiesForCity(String country, String state, String city) {
    return [
      TargetLocationModel(
        placeId: 'loc_${_clean(city)}_downtown',
        name: '$city Downtown / Main Market',
        type: 'locality',
        countryName: country,
        stateName: state,
        cityName: city,
        latitude: 0.0,
        longitude: 0.0,
        formattedAddress: '$city Downtown, $state, $country',
      ),
      TargetLocationModel(
        placeId: 'loc_${_clean(city)}_north',
        name: '$city North Zone',
        type: 'locality',
        countryName: country,
        stateName: state,
        cityName: city,
        latitude: 0.0,
        longitude: 0.0,
        formattedAddress: '$city North Zone, $state, $country',
      ),
    ];
  }

  /// Curated indexed locations for quick offline access and testing
  static const List<TargetLocationModel> defaultLocations = [
    // Countries
    TargetLocationModel(
      placeId: 'country_in',
      name: 'India',
      type: 'country',
      countryCode: 'IN',
      countryName: 'India',
      latitude: 20.5937,
      longitude: 78.9629,
      formattedAddress: 'India',
    ),
    TargetLocationModel(
      placeId: 'country_us',
      name: 'United States',
      type: 'country',
      countryCode: 'US',
      countryName: 'United States',
      latitude: 37.0902,
      longitude: -95.7129,
      formattedAddress: 'United States',
    ),

    // States
    TargetLocationModel(
      placeId: 'state_tn',
      name: 'Tamil Nadu',
      type: 'state',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'Tamil Nadu',
      latitude: 11.1271,
      longitude: 78.6569,
      formattedAddress: 'Tamil Nadu, India',
    ),
    TargetLocationModel(
      placeId: 'state_kl',
      name: 'Kerala',
      type: 'state',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'Kerala',
      latitude: 10.8505,
      longitude: 76.2711,
      formattedAddress: 'Kerala, India',
    ),
    TargetLocationModel(
      placeId: 'state_ka',
      name: 'Karnataka',
      type: 'state',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'Karnataka',
      latitude: 15.3173,
      longitude: 75.7139,
      formattedAddress: 'Karnataka, India',
    ),

    // Tirunelveli & Localities
    TargetLocationModel(
      placeId: 'city_tirunelveli',
      name: 'Tirunelveli',
      type: 'city',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'Tamil Nadu',
      cityName: 'Tirunelveli',
      latitude: 8.7139,
      longitude: 77.7567,
      formattedAddress: 'Tirunelveli, Tamil Nadu, India',
    ),
    TargetLocationModel(
      placeId: 'loc_palayamkottai',
      name: 'Palayamkottai',
      type: 'locality',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'Tamil Nadu',
      cityName: 'Tirunelveli',
      latitude: 8.7214,
      longitude: 77.7470,
      formattedAddress: 'Palayamkottai, Tirunelveli, Tamil Nadu, India',
    ),
    TargetLocationModel(
      placeId: 'loc_samathanapuram',
      name: 'Samathanapuram',
      type: 'locality',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'Tamil Nadu',
      cityName: 'Tirunelveli',
      latitude: 8.7230,
      longitude: 77.7420,
      formattedAddress: 'Samathanapuram, Palayamkottai, Tirunelveli, Tamil Nadu',
    ),
    TargetLocationModel(
      placeId: 'loc_ktc_nagar',
      name: 'KTC Nagar',
      type: 'locality',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'Tamil Nadu',
      cityName: 'Tirunelveli',
      latitude: 8.7350,
      longitude: 77.7720,
      formattedAddress: 'KTC Nagar, Palayamkottai, Tirunelveli, Tamil Nadu',
    ),
    TargetLocationModel(
      placeId: 'loc_vannarpettai',
      name: 'Vannarpettai',
      type: 'locality',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'Tamil Nadu',
      cityName: 'Tirunelveli',
      latitude: 8.7289,
      longitude: 77.7281,
      formattedAddress: 'Vannarpettai, Tirunelveli, Tamil Nadu, India',
    ),
    TargetLocationModel(
      placeId: 'loc_melapalayam',
      name: 'Melapalayam',
      type: 'locality',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'Tamil Nadu',
      cityName: 'Tirunelveli',
      latitude: 8.7042,
      longitude: 77.7180,
      formattedAddress: 'Melapalayam, Tirunelveli, Tamil Nadu, India',
    ),
    TargetLocationModel(
      placeId: 'loc_pettai',
      name: 'Pettai',
      type: 'locality',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'Tamil Nadu',
      cityName: 'Tirunelveli',
      latitude: 8.7369,
      longitude: 77.6854,
      formattedAddress: 'Pettai, Tirunelveli, Tamil Nadu, India',
    ),
    TargetLocationModel(
      placeId: 'loc_maharaja_nagar',
      name: 'Maharaja Nagar',
      type: 'locality',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'Tamil Nadu',
      cityName: 'Tirunelveli',
      latitude: 8.7310,
      longitude: 77.7610,
      formattedAddress: 'Maharaja Nagar, Tirunelveli, Tamil Nadu, India',
    ),

    // Nearby cities to Tirunelveli
    TargetLocationModel(
      placeId: 'city_tenkasi',
      name: 'Tenkasi',
      type: 'city',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'Tamil Nadu',
      cityName: 'Tenkasi',
      latitude: 8.9593,
      longitude: 77.3150,
      formattedAddress: 'Tenkasi, Tamil Nadu, India',
    ),
    TargetLocationModel(
      placeId: 'city_thoothukudi',
      name: 'Thoothukudi',
      type: 'city',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'Tamil Nadu',
      cityName: 'Thoothukudi',
      latitude: 8.7642,
      longitude: 78.1348,
      formattedAddress: 'Thoothukudi, Tamil Nadu, India',
    ),
    TargetLocationModel(
      placeId: 'city_virudhunagar',
      name: 'Virudhunagar',
      type: 'city',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'Tamil Nadu',
      cityName: 'Virudhunagar',
      latitude: 9.5680,
      longitude: 77.9624,
      formattedAddress: 'Virudhunagar, Tamil Nadu, India',
    ),

    // Madurai & Localities
    TargetLocationModel(
      placeId: 'city_madurai',
      name: 'Madurai',
      type: 'city',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'Tamil Nadu',
      cityName: 'Madurai',
      latitude: 9.9252,
      longitude: 78.1198,
      formattedAddress: 'Madurai, Tamil Nadu, India',
    ),
    TargetLocationModel(
      placeId: 'loc_anna_nagar_mdu',
      name: 'Anna Nagar (Madurai)',
      type: 'locality',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'Tamil Nadu',
      cityName: 'Madurai',
      latitude: 9.9192,
      longitude: 78.1520,
      formattedAddress: 'Anna Nagar, Madurai, Tamil Nadu, India',
    ),
    TargetLocationModel(
      placeId: 'loc_kk_nagar_mdu',
      name: 'KK Nagar (Madurai)',
      type: 'locality',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'Tamil Nadu',
      cityName: 'Madurai',
      latitude: 9.9360,
      longitude: 78.1490,
      formattedAddress: 'KK Nagar, Madurai, Tamil Nadu, India',
    ),

    // Chennai & Localities
    TargetLocationModel(
      placeId: 'city_chennai',
      name: 'Chennai',
      type: 'city',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'Tamil Nadu',
      cityName: 'Chennai',
      latitude: 13.0827,
      longitude: 80.2707,
      formattedAddress: 'Chennai, Tamil Nadu, India',
    ),
    TargetLocationModel(
      placeId: 'loc_t_nagar',
      name: 'T. Nagar',
      type: 'locality',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'Tamil Nadu',
      cityName: 'Chennai',
      latitude: 13.0418,
      longitude: 80.2341,
      formattedAddress: 'T. Nagar, Chennai, Tamil Nadu, India',
    ),
    TargetLocationModel(
      placeId: 'loc_anna_nagar_chn',
      name: 'Anna Nagar (Chennai)',
      type: 'locality',
      countryCode: 'IN',
      countryName: 'India',
      stateName: 'Tamil Nadu',
      cityName: 'Chennai',
      latitude: 13.0850,
      longitude: 80.2100,
      formattedAddress: 'Anna Nagar, Chennai, Tamil Nadu, India',
    ),
  ];
}
