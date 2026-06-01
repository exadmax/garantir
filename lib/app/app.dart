import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/splash/presentation/splash_page.dart';

class SoyYoApp extends StatelessWidget {
  const SoyYoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Garantir',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _splashDone = false;
  bool _authResolved = false;
  User? _user;

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          _user = user;
          _authResolved = true;
        });
      }
    });
  }

  void _onSplashDone() {
    if (mounted) setState(() => _splashDone = true);
  }

  @override
  Widget build(BuildContext context) {
    final Widget page;

    if (!_splashDone || !_authResolved) {
      page = SplashPage(key: const ValueKey('splash'), onDone: _onSplashDone);
    } else if (_user != null) {
      page = const DashboardPage(key: ValueKey('dashboard'));
    } else {
      page = const LoginPage(key: ValueKey('login'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: page,
    );
  }
}
