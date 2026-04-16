import 'package:flutter/material.dart';
import 'package:quiz_master_app/controllers/app_controller.dart';
import 'package:quiz_master_app/screens/admin_dashboard_screen.dart';
import 'package:quiz_master_app/screens/auth_screen.dart';
import 'package:quiz_master_app/screens/home_screen.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isLoading) {
          return const _LoadingScreen();
        }

        final user = controller.currentUser;
        if (user == null) {
          return AuthScreen(controller: controller);
        }

        if (user.isAdmin) {
          return AdminDashboardScreen(controller: controller);
        }

        return HomeScreen(controller: controller);
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
