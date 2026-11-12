import 'package:flutter/material.dart';
import '../services/auth.dart';
import '../widgets/common.dart';
import 'dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  final e = TextEditingController(text: 'admin@autocare.com'),
      p = TextEditingController(text: 'password');
  bool load = false;
  Future<void> go() async {
    setState(() => load = true);
    try {
      await AuthService.login(e.text, p.text);
      if (mounted)
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const Dashboard()));
    } catch (x) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(x.toString())));
    }
    if (mounted) setState(() => load = false);
  }

  Widget build(BuildContext c) => Scaffold(
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.car_repair, size: 70),
                    const SizedBox(height: 10),
                    const Text('AutoCare',
                        style: TextStyle(
                            fontSize: 32, fontWeight: FontWeight.bold)),
                    const Text('Vehicle Service Management'),
                    const SizedBox(height: 30),
                    Field(controller: e, label: 'Email'),
                    Field(controller: p, label: 'Password', obscure: true),
                    SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                            onPressed: load ? null : go,
                            child: Text(load ? 'Signing in...' : 'Login'))),
                    TextButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SignUpScreen())),
                        child: const Text('Create account')),
                    TextButton.icon(
                        onPressed: () => showServerSettings(context),
                        icon: const Icon(Icons.dns_outlined, size: 18),
                        label: const Text('Server settings'))
                  ])))));
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  State<SignUpScreen> createState() => _SignState();
}

class _SignState extends State<SignUpScreen> {
  final n = TextEditingController(),
      e = TextEditingController(),
      p = TextEditingController();
  Future<void> go() async {
    try {
      await AuthService.register(n.text, e.text, p.text);
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created. Login now.')));
    } catch (x) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(x.toString())));
    }
  }

  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Field(controller: n, label: 'Full Name'),
            Field(controller: e, label: 'Email'),
            Field(controller: p, label: 'Password', obscure: true),
            SizedBox(
                width: double.infinity,
                child: FilledButton(
                    onPressed: go, child: const Text('Create Account')))
          ])));
}
