import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/target_location_model.dart';
import '../../services/location_service.dart';
import '../../services/target_location_service.dart';

class TargetLocationPickerModal extends StatefulWidget {
  final List<TargetLocationModel> initialSelectedLocations;
  final ValueChanged<List<TargetLocationModel>> onApply;

  const TargetLocationPickerModal({
    super.key,
    required this.initialSelectedLocations,
    required this.onApply,
  });

  @override
  State<TargetLocationPickerModal> createState() => _TargetLocationPickerModalState();
}

class _TargetLocationPickerModalState extends State<TargetLocationPickerModal> {
  final TargetLocationService _locationService = TargetLocationService();
  final TextEditingController _searchController = TextEditingController();

  // Selected Target Locations
  List<TargetLocationModel> _selectedLocations = [];
  TargetLocationModel? _activeReferenceLocation;
  String? _feedbackMessage;

  // Search state
  List<TargetLocationModel> _searchResults = [];
  List<TargetLocationModel> _searchNearbyLocations = [];
  List<TargetLocationModel> _searchCoveredLocations = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _selectedLocations = List.from(widget.initialSelectedLocations);
    if (_selectedLocations.isNotEmpty) {
      _activeReferenceLocation = _selectedLocations.last;
    }
    // Do NOT automatically preload or select any default location (Requirements #1 & #2)
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ==========================================
  // SEARCH & AUTOCOMPLETE WITH EXACT MATCH FIRST
  // ==========================================

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _runSearch(query);
    });
  }

  Future<void> _runSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _searchNearbyLocations = [];
          _searchCoveredLocations = [];
          _isSearching = false;
        });
      }
      return;
    }

    setState(() => _isSearching = true);

    final locService = Provider.of<LocationService>(context, listen: false);
    final userLat = _activeReferenceLocation?.latitude ??
        (locService.currentLocation.latitude != 0.0 ? locService.currentLocation.latitude : null);
    final userLng = _activeReferenceLocation?.longitude ??
        (locService.currentLocation.longitude != 0.0 ? locService.currentLocation.longitude : null);

    final results = await _locationService.searchWorldwideLocations(
      cleanQuery,
      userLat: userLat,
      userLng: userLng,
    );

    List<TargetLocationModel> searchNearby = [];
    List<TargetLocationModel> searchCovered = [];
    if (results.isNotEmpty) {
      final topResult = results.first;

      // 1. Four (4) Nearby Areas (strictly proximity ranked, excluding covered/contained child locations)
      searchNearby = await _locationService.getNearbyLocationsForReference(
        referenceLocation: topResult,
        limit: 4,
        excludeLocations: _selectedLocations,
      );

      // 2. Covered Areas (geographically contained within or part of searched location)
      searchCovered = await _locationService.getCoveredLocationsForReference(
        referenceLocation: topResult,
        limit: 15,
      );
    }

    if (mounted) {
      setState(() {
        _searchResults = results;
        _searchNearbyLocations = searchNearby;
        _searchCoveredLocations = searchCovered;
        _isSearching = false;
      });
    }
  }

  // ==========================================
  // SELECTION & HIERARCHY CONSOLIDATION
  // ==========================================

  void _toggleLocation(TargetLocationModel location) {
    final isAlreadySelected = _selectedLocations.any((e) => _locationService.isSameLocation(e, location));

    if (isAlreadySelected) {
      // Remove it
      setState(() {
        _selectedLocations.removeWhere((e) => _locationService.isSameLocation(e, location));
        _feedbackMessage = null;
        if (_selectedLocations.isNotEmpty) {
          _activeReferenceLocation = _selectedLocations.last;
        } else {
          _activeReferenceLocation = null;
        }
      });
      return;
    }

    // Add and apply hierarchical consolidation
    final filterResult = _locationService.addAndFilterLocation(
      currentLocations: _selectedLocations,
      newLocation: location,
    );

    setState(() {
      _activeReferenceLocation = location;

      if (filterResult.wasAlreadyCovered) {
        final parentName = filterResult.coveringParent?.name ?? 'a broader area';
        _feedbackMessage = '"${location.name}" is already covered under $parentName.';
      } else {
        _selectedLocations = filterResult.updatedLocations;
        if (filterResult.removedChildLocations.isNotEmpty) {
          final removedNames = filterResult.removedChildLocations.map((e) => e.name).join(', ');
          _feedbackMessage = 'Consolidated $removedNames into ${location.name}.';
        } else {
          _feedbackMessage = null;
        }
      }
    });
  }

  void _removeLocation(TargetLocationModel location) {
    setState(() {
      _selectedLocations.removeWhere((e) => _locationService.isSameLocation(e, location));
      _feedbackMessage = null;
      if (_selectedLocations.isNotEmpty) {
        _activeReferenceLocation = _selectedLocations.last;
      } else {
        _activeReferenceLocation = null;
      }
    });
  }

  // ==========================================
  // UI HELPERS
  // ==========================================

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'country':
        return const Color(0xFF4338CA);
      case 'state':
      case 'province':
      case 'region':
        return const Color(0xFF7C3AED);
      case 'city':
      case 'district':
        return const Color(0xFF2563EB);
      case 'locality':
      case 'sublocality':
      case 'neighborhood':
      case 'area':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF4B5563);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'country':
        return Icons.public_rounded;
      case 'state':
      case 'province':
      case 'region':
        return Icons.map_outlined;
      case 'city':
      case 'district':
        return Icons.location_city_rounded;
      case 'locality':
      case 'sublocality':
      case 'neighborhood':
      case 'area':
        return Icons.place_rounded;
      default:
        return Icons.near_me_rounded;
    }
  }

  // ==========================================
  // BUILD METHOD (NO TABS)
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final hasSearchQuery = _searchController.text.trim().isNotEmpty;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Target Location',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Search location & select target areas',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),

          // 1. TOP SEARCH BAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search location... (e.g. Palayamkottai, Tirunelveli, New York)',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF6366F1), size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF9CA3AF)),
                          onPressed: () {
                            _searchController.clear();
                            _runSearch('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // 2. SELECTED TARGET LOCATIONS (Immediately below search bar)
          if (_selectedLocations.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SELECTED TARGET LOCATIONS (${_selectedLocations.length})',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B7280),
                          letterSpacing: 0.5,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedLocations.clear();
                            _activeReferenceLocation = null;
                            _feedbackMessage = null;
                          });
                        },
                        child: const Text(
                          'Clear All',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _selectedLocations.map((loc) {
                      final color = _getTypeColor(loc.type);
                      final isRef = _activeReferenceLocation != null &&
                          _locationService.isSameLocation(_activeReferenceLocation!, loc);
                      return GestureDetector(
                        onTap: () {
                          setState(() => _activeReferenceLocation = loc);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isRef ? color : color.withValues(alpha: 0.3),
                              width: isRef ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_getTypeIcon(loc.type), size: 13, color: color),
                              const SizedBox(width: 5),
                              Text(
                                loc.name,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => _removeLocation(loc),
                                child: Icon(Icons.close_rounded, size: 14, color: color),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

          // Feedback Notification Banner (Consolidation message)
          if (_feedbackMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF16A34A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _feedbackMessage!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF166534),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _feedbackMessage = null),
                    child: const Icon(Icons.close, size: 14, color: Color(0xFF16A34A)),
                  ),
                ],
              ),
            ),

          const Divider(height: 8, thickness: 1, color: Color(0xFFF3F4F6)),

          // Main List (Search results + 4 Nearby Areas + Covered Areas OR Initial empty state)
          Expanded(
            child: hasSearchQuery
                ? _buildSearchModeView()
                : _buildSelectionModeView(),
          ),

          // Google Attribution Badge
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map_rounded, size: 11, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  'Powered by Google Maps & Places',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Bottom Action Button
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 10,
              bottom: MediaQuery.of(context).padding.bottom + 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply(_selectedLocations);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _selectedLocations.isEmpty
                      ? 'Select Target Location'
                      : 'Apply ${_selectedLocations.length} Target Location${_selectedLocations.length > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SEARCH MODE: Exact Search Result -> 4 Nearby Areas -> Covered Areas (Strict Order)
  // ==========================================

  Widget _buildSearchModeView() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFF4F46E5),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 36, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'No locations found matching "${_searchController.text}"',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              'Try searching by city, district, state, or locality name.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    final exactOrTopResult = _searchResults.first;
    final otherResults = _searchResults.skip(1).take(2).toList();
    final nearby4 = _searchNearbyLocations.take(4).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      children: [
        // 1. SEARCH RESULT (Searched Location)
        _buildSectionHeader('SEARCH RESULT'),
        const SizedBox(height: 4),
        _buildLocationItemTile(exactOrTopResult),
        if (otherResults.isNotEmpty) ...[
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          ...otherResults.map((loc) => _buildLocationItemTile(loc)),
        ],

        // 2. FOUR (4) NEARBY AREAS
        if (nearby4.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionHeader(
            'NEARBY AREAS (TO ${exactOrTopResult.name.toUpperCase()})',
            badge: '${nearby4.length} Nearest',
          ),
          const SizedBox(height: 4),
          ...nearby4.map((loc) => _buildLocationItemTile(loc)),
        ],

        // 3. COVERED AREAS (Geographically contained within or part of searched location)
        if (_searchCoveredLocations.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionHeader(
            'COVERED AREAS (WITHIN ${exactOrTopResult.name.toUpperCase()})',
            badge: '${_searchCoveredLocations.length} Areas',
          ),
          const SizedBox(height: 4),
          ..._searchCoveredLocations.map((loc) => _buildLocationItemTile(loc)),
        ],
      ],
    );
  }

  // ==========================================
  // INITIAL / EMPTY VIEW: No preloaded default locations
  // ==========================================

  Widget _buildSelectionModeView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_rounded, size: 30, color: Color(0xFF6366F1)),
            ),
            const SizedBox(height: 14),
            const Text(
              'Search Target Location',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter a city, locality, district, state, or country in the search bar above to view results, 4 nearby areas, and covered localities.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {String? badge}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Color(0xFF9CA3AF),
            letterSpacing: 0.5,
          ),
        ),
        if (badge != null)
          Row(
            children: [
              Icon(Icons.near_me_rounded, size: 11, color: Colors.grey.shade500),
              const SizedBox(width: 2),
              Text(
                badge,
                style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildLocationItemTile(TargetLocationModel loc) {
    final isSelected = _selectedLocations.any((e) => _locationService.isSameLocation(e, loc));
    final isCoveredByParent = !isSelected && _selectedLocations.any((e) => _locationService.isParent(e, loc));
    final coveringParent = isCoveredByParent
        ? _selectedLocations.firstWhere((e) => _locationService.isParent(e, loc))
        : null;

    final color = _getTypeColor(loc.type);

    return InkWell(
      onTap: () => _toggleLocation(loc),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Row(
          children: [
            // Icon Badge
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_getTypeIcon(loc.type), color: color, size: 20),
            ),
            const SizedBox(width: 12),

            // Location details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          loc.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF111827),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          loc.typeLabel,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                      if (loc.formattedDistance != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.near_me_outlined, size: 9, color: Color(0xFF6B7280)),
                              const SizedBox(width: 2),
                              Text(
                                loc.formattedDistance!,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    loc.displayHierarchy,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isCoveredByParent)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '✓ Covered under ${coveringParent?.name}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Selection State Widget
            if (isSelected)
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: Color(0xFF4F46E5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
              )
            else if (isCoveredByParent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Text(
                  'Covered',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF059669),
                  ),
                ),
              )
            else
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFD1D5DB), width: 1.5),
                ),
                child: const Icon(Icons.add_rounded, color: Color(0xFF9CA3AF), size: 16),
              ),
          ],
        ),
      ),
    );
  }
}
