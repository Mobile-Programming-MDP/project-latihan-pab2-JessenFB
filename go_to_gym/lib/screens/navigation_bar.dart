import 'package:flutter/material.dart';
import 'package:go_to_gym/screens/chat_screen.dart';
import 'package:go_to_gym/screens/home_screen.dart';
import 'package:go_to_gym/screens/profile_screen.dart';
import 'package:go_to_gym/screens/search_screen.dart';
import 'package:go_to_gym/screens/create_post_screen.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;

  const CustomBottomNavBar({super.key, required this.currentIndex});

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Warna aktif dan tidak aktif
    const Color activeColor = Color(0xFF38BDF8);
    final Color inactiveColor = isDark ? Colors.white70 : Colors.black;

    // Warna background navbar
    final Color backgroundColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);

    // Garis atas
    final BorderSide topBorder = BorderSide(
      color: isDark ? Colors.white24 : Colors.black45,
      width: 0.8,
    );

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(top: topBorder),
      ),
      child: BottomAppBar(
        color: Colors.transparent,
        elevation: 0,
        shape: const CircularNotchedRectangle(),
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: Icon(
                  Icons.home,
                  color: currentIndex == 0 ? activeColor : inactiveColor,
                ),
                onPressed: () {
                  if (currentIndex != 0) {
                    _navigateWithoutAnimation(context, const HomeScreen());
                  }
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.search,
                  color: currentIndex == 1 ? activeColor : inactiveColor,
                ),
                onPressed: () {
                  if (currentIndex != 1) {
                    _navigateWithoutAnimation(context, const SearchScreen());
                  }
                },
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                  );
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: Color(0xFF38BDF8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.smart_toy,
                  color: currentIndex == 2 ? activeColor : inactiveColor,
                ),
                onPressed: () {
                  if (currentIndex != 2) {
                    _navigateWithoutAnimation(context, const ChatScreen());
                  }
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.person,
                  color: currentIndex == 3 ? activeColor : inactiveColor,
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
      ),
    );
  }
}
