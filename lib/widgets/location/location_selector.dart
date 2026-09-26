import 'package:flutter/material.dart';

class LocationSelector extends StatelessWidget {
  final String initialValue;
  final ValueChanged<String> onLocationSelected;

  const LocationSelector({
    super.key,
    required this.initialValue,
    required this.onLocationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final locations = [
      'T. Nagar, Chennai',
      'Pondy Bazaar, Chennai',
      'Alwarpet, Chennai',
      'Anna Nagar, Chennai',
      'Velachery, Chennai',
      'Adyar, Chennai',
      'Coimbatore',
      'Madurai',
      'Tamil Nadu (State-wide)',
      'Pan-India',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: locations.contains(initialValue) ? initialValue : locations.first,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF9CA3AF)),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF111827),
          ),
          items: locations.map((loc) {
            return DropdownMenuItem<String>(
              value: loc,
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFFEF4444)),
                  const SizedBox(width: 8),
                  Text(loc),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              onLocationSelected(val);
            }
          },
        ),
      ),
    );
  }
}
