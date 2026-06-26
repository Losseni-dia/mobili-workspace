import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobilipro/core/theme/app_colors.dart';
import 'package:mobilipro/features/notifications/data/notification_service.dart';
import 'package:mobilipro/features/notifications/providers/notification_provider.dart';

class ShellAdmin extends ConsumerWidget {
  const ShellAdmin({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(unreadCountProvider);
    final unread = unreadAsync.valueOrNull ?? 0;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (i) async {
          navigationShell.goBranch(
            i,
            initialLocation: i == navigationShell.currentIndex,
          );
          // Index 5 = Notifications
          if (i == 5) {
            await NotificationService().markAllRead();
            ref.invalidate(unreadCountProvider);
          }
        },
        selectedItemColor: AppColors.mobiliBlue,
        unselectedItemColor: AppColors.gray400,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.manage_accounts_rounded),
            label: 'Gestion',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'Activité',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.forum_rounded),
            label: 'Communications',
          ),
          BottomNavigationBarItem(
            icon: _BadgeIcon(icon: Icons.notifications_rounded, count: unread),
            label: 'Notifications',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.icon, required this.count});
  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return Icon(icon);
    return Badge(
      label: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(fontSize: 10, color: Colors.white),
      ),
      backgroundColor: AppColors.danger,
      child: Icon(icon),
    );
  }
}
