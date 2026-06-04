import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class ShellPage extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const ShellPage({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: navigationShell,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: navigationShell.currentIndex,
          onTap: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
          selectedItemColor: AppColors.mobiliBlue,
          unselectedItemColor: AppColors.gray400,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded), label: 'Accueil'),
            BottomNavigationBarItem(
                icon: Icon(Icons.search_rounded), label: 'Recherche'),
            BottomNavigationBarItem(
                icon: Icon(Icons.bookmark_rounded), label: 'Réservations'),
            BottomNavigationBarItem(
                icon: Icon(Icons.notifications_rounded),
                label: 'Notifications'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded), label: 'Profil'),
          ],
        ),
      );
}
