import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/search_service.dart';
import '../services/business_service.dart';
import '../widgets/home/business_card.dart';
import '../widgets/common/notification_bell_button.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchService = Provider.of<SearchService>(context);
    final bizService = Provider.of<BusinessService>(context);

    final matchingBusinesses = searchService.searchBusinesses(
      query: _searchController.text,
      businesses: bizService.businesses,
    );

    final isSearching = _searchController.text.trim().isNotEmpty;
    final canPop = Navigator.canPop(context);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Standard Top Header: Title + Notification Bell + Simple Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 16, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 42,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          if (canPop) ...[
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827)),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 8),
                          ],
                          const Text(
                            'Search',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                      const NotificationBellButton(),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Simple Search Bar (Consistent with Coupons & Home)
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 18, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          autofocus: canPop,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF111827),
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Search businesses, shops, services...',
                            hintStyle: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF9CA3AF)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Business Results
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isSearching
                            ? 'MATCHING BUSINESSES (${matchingBusinesses.length})'
                            : 'EXPLORE BUSINESSES (${matchingBusinesses.length})',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF9CA3AF),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (matchingBusinesses.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.storefront_outlined, size: 48, color: Color(0xFFCBD5E1)),
                            const SizedBox(height: 12),
                            Text(
                              'No businesses found matching "${_searchController.text.trim()}"',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Try searching by business name, category, or city.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: matchingBusinesses.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final biz = matchingBusinesses[index];
                        return BusinessCard(
                          business: biz,
                          onTap: () {
                            Navigator.pushNamed(context, '/business-details', arguments: biz.businessProfileId);
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
