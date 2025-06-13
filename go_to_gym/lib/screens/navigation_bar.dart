import 'package:flutter/material.dart';
import 'package:go_to_gym/screens/chat_screen.dart';
import 'package:go_to_gym/screens/home_screen.dart';
import 'package:go_to_gym/screens/profile_screen.dart';
import 'package:go_to_gym/screens/search_screen.dart';
import 'package:go_to_gym/screens/create_post_screen.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
  });

  void _navigateWithoutAnimation(BuildContext context, Widget destination) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: const Color(0xFF1E293B),
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Home
            IconButton(
              icon: Icon(
                Icons.home,
                color: currentIndex == 0 ? Colors.white : Colors.white54,
              ),
              onPressed: () {
                if (currentIndex != 0) {
                  _navigateWithoutAnimation(context, const HomeScreen());
                }
              },
            ),

            // Search
            IconButton(
              icon: Icon(
                Icons.search,
                color: currentIndex == 1 ? Colors.white : Colors.white54,
              ),
              onPressed: () {
                if (currentIndex != 1) {
                  _navigateWithoutAnimation(context, const SearchScreen());
                }
              },
            ),

            // Create Post (with circle background)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                );
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: Color(0xFF38BDF8), // Light blue background
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Icon(
                    Icons.add_circle_outline,
                    size: 30,
                    color: Colors.white,
                  ),
                ],
              ),
            ),

            // AI Chat
            IconButton(
              icon: Icon(
                Icons.smart_toy,
                color: currentIndex == 2 ? Colors.white : Colors.white54,
              ),
              onPressed: () {
                if (currentIndex != 2) {
                  _navigateWithoutAnimation(context, const ChatScreen());
                }
              },
            ),

            // Profile
            IconButton(
              icon: Icon(
                Icons.person,
                color: currentIndex == 3 ? Colors.white : Colors.white54,
              ),
              onPressed: () {
                if (currentIndex != 3) {
                  _navigateWithoutAnimation(context, const ProfileScreen());
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
