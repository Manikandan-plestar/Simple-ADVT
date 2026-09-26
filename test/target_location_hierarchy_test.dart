import 'package:flutter_test/flutter_test.dart';
import 'package:advt_app/models/target_location_model.dart';
import 'package:advt_app/services/target_location_service.dart';
import 'package:advt_app/services/post_service.dart';
import 'package:advt_app/services/business_service.dart';
import 'package:advt_app/services/search_service.dart';

void main() {
  group('Target Location Hierarchical Filtering Tests', () {
    final service = TargetLocationService();

    final india = TargetLocationService.defaultLocations.firstWhere((e) => e.placeId == 'country_in');
    final tamilNadu = TargetLocationService.defaultLocations.firstWhere((e) => e.placeId == 'state_tn');
    final tirunelveli = TargetLocationService.defaultLocations.firstWhere((e) => e.placeId == 'city_tirunelveli');
    final palayamkottai = TargetLocationService.defaultLocations.firstWhere((e) => e.placeId == 'loc_palayamkottai');
    final samathanapuram = TargetLocationService.defaultLocations.firstWhere((e) => e.placeId == 'loc_samathanapuram');
    final ktcNagar = TargetLocationService.defaultLocations.firstWhere((e) => e.placeId == 'loc_ktc_nagar');
    final madurai = TargetLocationService.defaultLocations.firstWhere((e) => e.placeId == 'city_madurai');

    test('Scenario A: Palayamkottai first, then Tirunelveli -> keeps Tirunelveli', () {
      List<TargetLocationModel> current = [];

      // 1. User selects Palayamkottai
      final res1 = service.addAndFilterLocation(currentLocations: current, newLocation: palayamkottai);
      current = res1.updatedLocations;
      expect(current.map((e) => e.name).toList(), ['Palayamkottai']);

      // 2. User selects Tirunelveli (Parent of Palayamkottai)
      final res2 = service.addAndFilterLocation(currentLocations: current, newLocation: tirunelveli);
      current = res2.updatedLocations;

      expect(current.map((e) => e.name).toList(), ['Tirunelveli']);
      expect(res2.removedChildLocations.map((e) => e.name).toList(), ['Palayamkottai']);
    });

    test('Scenario B: Tirunelveli first, then Palayamkottai -> keeps Tirunelveli, rejects child', () {
      List<TargetLocationModel> current = [];

      // 1. User selects Tirunelveli
      final res1 = service.addAndFilterLocation(currentLocations: current, newLocation: tirunelveli);
      current = res1.updatedLocations;
      expect(current.map((e) => e.name).toList(), ['Tirunelveli']);

      // 2. User tries to select Palayamkottai
      final res2 = service.addAndFilterLocation(currentLocations: current, newLocation: palayamkottai);
      current = res2.updatedLocations;

      expect(current.map((e) => e.name).toList(), ['Tirunelveli']);
      expect(res2.wasAlreadyCovered, isTrue);
      expect(res2.coveringParent?.name, 'Tirunelveli');
    });

    test('Scenario C: Palayamkottai and Madurai -> both remain (unrelated)', () {
      List<TargetLocationModel> current = [];

      // 1. User selects Palayamkottai
      final res1 = service.addAndFilterLocation(currentLocations: current, newLocation: palayamkottai);
      current = res1.updatedLocations;

      // 2. User selects Madurai
      final res2 = service.addAndFilterLocation(currentLocations: current, newLocation: madurai);
      current = res2.updatedLocations;

      expect(current.map((e) => e.name).toSet(), {'Palayamkottai', 'Madurai'});
      expect(res2.wasAlreadyCovered, isFalse);
      expect(res2.removedChildLocations, isEmpty);
    });

    test('Scenario D: India, Tamil Nadu, Tirunelveli -> keeps only India (broadest parent)', () {
      final list = [tirunelveli, tamilNadu, india];
      final filtered = service.removeCoveredLocations(list);

      expect(filtered.map((e) => e.name).toList(), ['India']);
    });

    test('Child locations selected first: Palayamkottai, Samathanapuram, KTC Nagar then Tirunelveli', () {
      List<TargetLocationModel> current = [];

      // Select 3 localities
      current = service.addAndFilterLocation(currentLocations: current, newLocation: palayamkottai).updatedLocations;
      current = service.addAndFilterLocation(currentLocations: current, newLocation: samathanapuram).updatedLocations;
      current = service.addAndFilterLocation(currentLocations: current, newLocation: ktcNagar).updatedLocations;
      expect(current.length, 3);

      // Now select parent Tirunelveli
      final res = service.addAndFilterLocation(currentLocations: current, newLocation: tirunelveli);
      current = res.updatedLocations;

      expect(current.map((e) => e.name).toList(), ['Tirunelveli']);
      expect(res.removedChildLocations.length, 3);
      expect(res.removedChildLocations.map((e) => e.name).toSet(), {
        'Palayamkottai',
        'Samathanapuram',
        'KTC Nagar',
      });
    });

    test('Duplicate locations prevented', () {
      List<TargetLocationModel> current = [];
      current = service.addAndFilterLocation(currentLocations: current, newLocation: tirunelveli).updatedLocations;
      final res = service.addAndFilterLocation(currentLocations: current, newLocation: tirunelveli);
      expect(res.updatedLocations.length, 1);
      expect(res.wasAlreadyCovered, isTrue);
    });

    group('Dynamic Nearby Locations Proximity Tests', () {
      test('Exact search query ranks first', () async {
        final results = await service.searchWorldwideLocations('Palayamkottai');
        expect(results.isNotEmpty, isTrue);
        expect(results.first.name, 'Palayamkottai');
      });

      test('Nearby locations for Palayamkottai returns exactly 4 local areas sorted by distance', () async {
        final nearby = await service.getNearbyLocationsForReference(
          referenceLocation: palayamkottai,
          limit: 4,
        );
        expect(nearby.length, 4);
        expect(nearby.any((e) => e.placeId == 'loc_palayamkottai'), isFalse); // Excludes self

        // Verify all 4 are nearby localities
        expect(nearby.every((e) => e.type == 'locality'), isTrue);

        // Verify distance is strictly ascending
        for (int i = 0; i < nearby.length - 1; i++) {
          final d1 = nearby[i].distanceInKm ?? 0.0;
          final d2 = nearby[i + 1].distanceInKm ?? 0.0;
          expect(d1 <= d2, isTrue);
        }
      });

      test('Nearby locations for Tirunelveli excludes contained child localities and returns 4 independent nearby areas', () async {
        final nearby = await service.getNearbyLocationsForReference(
          referenceLocation: tirunelveli,
          limit: 4,
        );
        expect(nearby.length, 4);
        expect(nearby.any((e) => e.placeId == 'city_tirunelveli'), isFalse);

        // Contained localities MUST NOT be in the nearby list of Tirunelveli
        final names = nearby.map((e) => e.name).toList();
        expect(names.contains('Palayamkottai'), isFalse);
        expect(names.contains('Samathanapuram'), isFalse);
        expect(names.contains('KTC Nagar'), isFalse);
        expect(names.contains('Melapalayam'), isFalse);
      });

      test('Covered locations for Tirunelveli returns contained child localities', () async {
        final covered = await service.getCoveredLocationsForReference(
          referenceLocation: tirunelveli,
          limit: 10,
        );
        expect(covered.isNotEmpty, isTrue);

        final names = covered.map((e) => e.name).toList();
        expect(names.contains('Palayamkottai'), isTrue);
        expect(names.contains('Samathanapuram'), isTrue);
        expect(names.contains('KTC Nagar'), isTrue);
        expect(names.contains('Melapalayam'), isTrue);
      });

      test('Worldwide search and containment for United States and UK', () async {
        final usResults = await service.searchWorldwideLocations('United States');
        expect(usResults.isNotEmpty, isTrue);
        final us = usResults.first;
        expect(us.name, 'United States');

        final usCovered = await service.getCoveredLocationsForReference(referenceLocation: us);
        expect(usCovered.isNotEmpty, isTrue);
        expect(usCovered.any((e) => e.name == 'California' || e.name == 'New York' || e.name == 'Texas'), isTrue);
      });
    });
  });

  group('PostItem Multiple Images & Deletion Tests', () {
    test('Multiple images stored and ordered correctly on PostItem', () {
      final post = PostItem(
        postId: 'P100',
        businessProfileId: 'BP001',
        bizName: 'ABC Store',
        type: 'offer',
        title: 'Special Offer',
        subtitle: 'ABC Store • Tirunelveli',
        description: 'Great discounts on products.',
        timeAgo: 'Just now',
        images: [
          '/data/user/0/app/cache/img1.jpg',
          '/data/user/0/app/cache/img2.jpg',
          '/data/user/0/app/cache/img3.jpg',
        ],
      );

      expect(post.images.length, 3);
      expect(post.images[0], '/data/user/0/app/cache/img1.jpg');
      expect(post.images[1], '/data/user/0/app/cache/img2.jpg');
      expect(post.images[2], '/data/user/0/app/cache/img3.jpg');
      expect(post.image, '/data/user/0/app/cache/img1.jpg');
    });

    test('Single image backward compatibility', () {
      final post = PostItem(
        postId: 'P101',
        businessProfileId: 'BP001',
        bizName: 'ABC Store',
        type: 'job',
        title: 'Developer Opening',
        subtitle: 'ABC Store • Madurai',
        description: 'Hiring Flutter developer.',
        timeAgo: 'Just now',
        image: 'https://example.com/banner.jpg',
      );

      expect(post.images.length, 1);
      expect(post.images.first, 'https://example.com/banner.jpg');
      expect(post.image, 'https://example.com/banner.jpg');
    });

    test('Empty images list handled gracefully', () {
      final post = PostItem(
        postId: 'P102',
        businessProfileId: 'BP002',
        bizName: 'Tech Co',
        type: 'job',
        title: 'Manager Needed',
        subtitle: 'Tech Co • Chennai',
        description: 'Office manager position.',
        timeAgo: 'Just now',
      );

      expect(post.images, isEmpty);
      expect(post.image, isNull);
    });

    test('Post deletion removes post from PostService and enforces ownership', () {
      final postService = PostService();
      final initialCount = postService.allPosts.length;
      expect(initialCount > 0, isTrue);

      final targetPost = postService.allPosts.first;

      // Unauthorized business cannot delete target post
      final failDelete = postService.deletePost(targetPost.postId, callerBusinessProfileId: 'BP_UNAUTHORIZED');
      expect(failDelete, isFalse);
      expect(postService.allPosts.length, initialCount);

      // Authorized owner deletes post
      final successDelete = postService.deletePost(targetPost.postId, callerBusinessProfileId: targetPost.businessProfileId);
      expect(successDelete, isTrue);
      expect(postService.allPosts.length, initialCount - 1);
      expect(postService.getPostById(targetPost.postId), isNull);
    });

    test('Business profile deletion removes profile and enforces ownership', () {
      final bizService = BusinessService();
      final initialBizCount = bizService.businesses.length;
      expect(initialBizCount > 0, isTrue);

      final targetBiz = bizService.businesses.first;

      // Unauthorized user cannot delete
      final fail = bizService.deleteBusinessProfile(targetBiz.businessProfileId, callerUserId: 'U_UNAUTHORIZED');
      expect(fail, isFalse);
      expect(bizService.businesses.length, initialBizCount);

      // Authorized owner deletes
      final ok = bizService.deleteBusinessProfile(targetBiz.businessProfileId, callerUserId: targetBiz.ownerUserId);
      expect(ok, isTrue);
      expect(bizService.businesses.length, initialBizCount - 1);
      expect(bizService.getBusinessById(targetBiz.businessProfileId), isNull);
    });

    test('Post time is formatted correctly for bottom-right corner display', () {
      final post1 = PostItem(
        postId: 'P200',
        businessProfileId: 'BP001',
        bizName: 'ABC Store',
        type: 'offer',
        title: 'Morning Deal',
        subtitle: 'ABC Store • Tirunelveli',
        description: 'Discount offer.',
        timeAgo: '1 hour ago',
        createdAt: DateTime(2026, 9, 16, 10, 35),
      );
      expect(post1.formattedPostTime, '10:35 AM');

      final post2 = PostItem(
        postId: 'P201',
        businessProfileId: 'BP002',
        bizName: 'Tech Store',
        type: 'job',
        title: 'Afternoon Job',
        subtitle: 'Tech Store • Madurai',
        description: 'Developer job.',
        timeAgo: '3 hours ago',
        createdAt: DateTime(2026, 9, 16, 14, 05),
      );
      expect(post2.formattedPostTime, '2:05 PM');
    });

    test('SearchService matches posts by targetLocation and type', () {
      final searchService = SearchService();
      final post1 = PostItem(
        postId: 'P300',
        businessProfileId: 'BP001',
        bizName: 'Apex Dental',
        type: 'offer',
        title: 'Discount Dental Checkup',
        subtitle: 'Apex • Palayamkottai',
        description: 'Great offers',
        timeAgo: '1 hour ago',
        targetLocation: 'Palayamkottai, Tirunelveli',
      );
      final post2 = PostItem(
        postId: 'P301',
        businessProfileId: 'BP002',
        bizName: 'Tech Corp',
        type: 'job',
        title: 'Flutter Developer Opening',
        subtitle: 'Tech Corp • Madurai',
        description: 'Hiring devs',
        timeAgo: '2 hours ago',
        targetLocation: 'Anna Nagar, Madurai',
      );

      final res1 = searchService.search(query: 'Palayamkottai', businesses: [], posts: [post1, post2]);
      expect(res1.posts.length, 1);
      expect(res1.posts.first.postId, 'P300');

      final res2 = searchService.search(query: 'Flutter', businesses: [], posts: [post1, post2]);
      expect(res2.posts.length, 1);
      expect(res2.posts.first.postId, 'P301');

      final res3 = searchService.search(query: 'job', businesses: [], posts: [post1, post2]);
      expect(res3.posts.length, 1);
      expect(res3.posts.first.type, 'job');
    });
  });
}

