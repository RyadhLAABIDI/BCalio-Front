import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.bottomNavigationBarTheme.backgroundColor ??
            theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, -2),
            blurRadius: 10,
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        selectedItemColor: theme.bottomNavigationBarTheme.selectedItemColor,
        unselectedItemColor: theme.bottomNavigationBarTheme.unselectedItemColor,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        elevation: 0,
        backgroundColor: Colors.transparent,
        items: [
          BottomNavigationBarItem(
            icon: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  EdgeInsets.symmetric(vertical: currentIndex == 0 ? 8 : 0),
              child: Icon(
                currentIndex == 0 ? Iconsax.message5 : Iconsax.message,
                size: currentIndex == 0 ? 28 : 24,
              ),
            ),
            label: "Chats".tr, // Translatable label
          ),
          BottomNavigationBarItem(
            icon: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  EdgeInsets.symmetric(vertical: currentIndex == 1 ? 8 : 0),
              child: Icon(
                currentIndex == 1 ? Iconsax.call5 : Iconsax.call,
                size: currentIndex == 1 ? 28 : 24,
              ),
            ),
            label: "Calls".tr, // Translatable label
          ),
        ],
      ),
    );
  }
}
