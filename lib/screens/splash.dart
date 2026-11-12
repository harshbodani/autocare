import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth.dart';
import 'dashboard.dart';
import 'onboarding.dart';
import 'auth.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  State<SplashScreen> createState() => _S();
}

class _S extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), go);
  }

  @override
  Widget build(BuildContext c) => const Scaffold(
          body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.car_repair, size: 80),
        Text('AutoCare',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold))
      ])));
  Future go() async {
    final logged = await AuthService.isLoggedIn();
    if (!mounted) return;
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) =>
                logged ? const Dashboard() : const OnboardingScreen()));
  }
}
