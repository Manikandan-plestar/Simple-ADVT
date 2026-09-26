import 'package:flutter/material.dart';

class FilterDropdown extends StatelessWidget {
  final String activeFilter;
  final ValueChanged<String> onSelectFilter;

  const FilterDropdown({
    super.key,
    required this.activeFilter,
    required this.onSelectFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOption('all', 'All'),
          _buildOption('jobs', 'Jobs'),
          _buildOption('offers', 'Offers'),
          _buildOption('followed', 'Followed'),
        ],
      ),
    );
  }

  Widget _buildOption(String key, String title) {
    final isSelected = activeFilter == key;
    return InkWell(
      onTap: () => onSelectFilter(key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected ? const Color(0xFFEEF2FF) : Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF374151),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_rounded,
                size: 16,
                color: Color(0xFF4F46E5),
              ),
          ],
        ),
      ),
    );
  }
}
