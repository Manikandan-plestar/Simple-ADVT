import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/home/post_card.dart';
import '../widgets/skeleton/skeleton_post_card.dart';

class SavedItemsScreen extends StatefulWidget {
  final bool isTab;

  const SavedItemsScreen({super.key, this.isTab = false});

  @override
  State<SavedItemsScreen> createState() => _SavedItemsScreenState();
}

class _SavedItemsScreenState extends State<SavedItemsScreen> {
  bool _isInitialLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialLoaded) {
      _isInitialLoaded = true;
      _loadSavedPosts();
    }
  }

  Future<void> _loadSavedPosts() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final postService = Provider.of<PostService>(context, listen: false);
    if (authService.currentUser.userId.isNotEmpty) {
      await postService.fetchSavedPosts(
        authToken: authService.currentUser.authToken,
        userId: authService.currentUser.userId,
        userEmail: authService.currentUser.email,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final postService = Provider.of<PostService>(context);
    final authService = Provider.of<AuthService>(context);
    final savedList = postService.savedPosts;
    final isLoading = postService.isLoading;

    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: (!widget.isTab && canPop)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827)),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saved Posts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
            ),
            SizedBox(height: 2),
            Text(
              'Posts bookmarked by your account',
              style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadSavedPosts,
        color: const Color(0xFF4F46E5),
        child: isLoading && savedList.isEmpty
            ? ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: 4,
                itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: SkeletonPostCard(),
                ),
              )
            : savedList.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 80),
                      EmptyStateWidget(
                        icon: Icons.bookmark_border_rounded,
                        title: 'No saved posts yet',
                        subtitle: 'Tap the bookmark icon on any post in Explore to save it here for quick access.',
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    itemCount: savedList.length,
                    itemBuilder: (context, index) {
                      final post = savedList[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PostCard(
                          post: post,
                          onBookmarkTap: () {
                            postService.toggleSavePost(
                              post.postId,
                              authToken: authService.currentUser.authToken,
                              userId: authService.currentUser.userId,
                              userEmail: authService.currentUser.email,
                            );
                          },
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

