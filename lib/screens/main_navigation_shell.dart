import 'package:flutter/material.dart';
import 'package:quiz_master_app/controllers/app_controller.dart';
import 'package:quiz_master_app/screens/admin_dashboard_screen.dart';
import 'package:quiz_master_app/screens/home_screen.dart';
import 'package:quiz_master_app/screens/profile_screen.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key, required this.controller});

  final AppController controller;

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _selectedIndex = 0;

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.currentUser!;
    final isAdmin = user.isAdmin;

    final pages = <Widget>[
      if (isAdmin)
        AdminDashboardScreen(
          controller: widget.controller,
          showProfileShortcut: false,
        )
      else
        HomeScreen(
          controller: widget.controller,
          showProfileShortcut: false,
        ),
      ProfileScreen(controller: widget.controller),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: [
          NavigationDestination(
            icon: Icon(
              isAdmin ? Icons.space_dashboard_outlined : Icons.home_outlined,
            ),
            selectedIcon: Icon(
              isAdmin ? Icons.space_dashboard_rounded : Icons.home_rounded,
            ),
            label: isAdmin ? 'Dashboard' : 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
