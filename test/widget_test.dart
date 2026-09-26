import 'package:flutter_test/flutter_test.dart';
import 'package:advt_app/main.dart';
import 'package:advt_app/services/auth_service.dart';
import 'package:advt_app/services/business_service.dart';
import 'package:advt_app/services/post_service.dart';
import 'package:advt_app/services/search_service.dart';

void main() {
  testWidgets('ADVT APP splash screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const AdvtApp());
    expect(find.text('ADVT APP'), findsOneWidget);
    expect(find.text('Connect with local jobs, offers & businesses'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  group('AuthService Unit Tests', () {
    test('Initial user details', () async {
      final auth = AuthService();
      expect(auth.isLoggedIn, isFalse);
    });

    test('Verify OTP code requires server response', () async {
      final auth = AuthService();
      final response = await auth.verifyOtp('000000');
      expect(response.success, isFalse);
    });
  });

  group('BusinessService Unit Tests', () {
    test('Business profile count and independent profiles', () {
      final bizService = BusinessService();
      expect(bizService.businesses.length, 3);

      final userBusinesses = bizService.getUserBusinesses('U001');
      expect(userBusinesses.length, 3);
      expect(userBusinesses.first.businessProfileId, 'BP001');
      expect(userBusinesses.last.businessProfileId, 'BP003');
    });

    test('Follow toggle', () {
      final bizService = BusinessService();
      final initialFollow = bizService.getBusinessById('BP003')?.isFollowed ?? false;
      bizService.toggleFollow('BP003');
      expect(bizService.getBusinessById('BP003')?.isFollowed, !initialFollow);
    });
  });

  group('SearchService Unit Tests', () {
    test('Fuzzy search over businesses and posts', () {
      final searchService = SearchService();
      final bizService = BusinessService();
      final postService = PostService();

      final result = searchService.search(
        query: 'Dental',
        businesses: bizService.businesses,
        posts: postService.allPosts,
      );

      expect(result.businesses.any((b) => b.name == 'ABC Dental Clinic'), isTrue);
    });
  });
}
