import 'package:flutter/material.dart';
import '../services/api.dart';
import '../services/auth.dart';
import '../widgets/common.dart';
import 'dashboard.dart';

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  const _PasswordField({required this.controller, this.label = 'Password'});
  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool hide = true;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextField(
          controller: widget.controller,
          obscureText: hide,
          decoration: fieldDecoration(widget.label, Icons.lock_outline,
              suffix: IconButton(icon: Icon(hide ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => hide = !hide))),
        ),
      );
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(24)),
          child: const Icon(Icons.car_repair, size: 46, color: Colors.white),
        ),
        const SizedBox(height: 14),
        const Text('AutoCare', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        const SizedBox(height: 4),
        const Text('Vehicle Service Management', style: TextStyle(color: Color(0xFF64748B))),
      ]);
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  // The demo login is only prefilled for the PostgreSQL demo server.
  final e = TextEditingController(text: ApiService.useFirebase ? '' : 'admin@autocare.com'),
      p = TextEditingController(text: ApiService.useFirebase ? '' : 'password');
  bool load = false;

  void snack(String t) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> go() async {
    setState(() => load = true);
    try {
      await AuthService.login(e.text, p.text);
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Dashboard()));
    } catch (x) {
      snack(x.toString());
    }
    if (mounted) setState(() => load = false);
  }

  Future<void> forgot() async {
    try {
      await AuthService.sendPasswordReset(e.text);
      snack('Password reset email sent to ${e.text.trim()}.');
    } catch (x) {
      snack(x.toString());
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
      body: SafeArea(
          child: Center(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const _Brand(),
                        const SizedBox(height: 32),
                        Field(controller: e, label: 'Email', icon: Icons.email_outlined, type: TextInputType.emailAddress),
                        _PasswordField(controller: p),
                        SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: FilledButton(onPressed: load ? null : go, child: Text(load ? 'Signing in...' : 'Log in'))),
                        if (ApiService.useFirebase) TextButton(onPressed: forgot, child: const Text('Forgot password?')),
                        const SizedBox(height: 4),
                        OutlinedButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpScreen())),
                            child: const Text('New customer? Create an account')),
                        if (!ApiService.useFirebase)
                          TextButton.icon(
                              onPressed: () => showServerSettings(context),
                              icon: const Icon(Icons.dns_outlined, size: 18),
                              label: const Text('Server settings')),
                      ]))))));
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignState();
}

class _SignState extends State<SignUpScreen> {
  final n = TextEditingController(), ph = TextEditingController(), e = TextEditingController(), p = TextEditingController();
  bool load = false;

  Future<void> go() async {
    setState(() => load = true);
    try {
      final signedIn = await AuthService.register(n.text, e.text, p.text, ph.text);
      if (!mounted) return;
      if (signedIn) {
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const Dashboard()), (r) => false);
      } else {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created. Log in now.')));
      }
      return;
    } catch (x) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(x.toString())));
    }
    if (mounted) setState(() => load = false);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(children: [
                const Text('Your own login lets you see your cars, book services, and view your invoices and reminders.', style: TextStyle(color: Color(0xFF64748B))),
                const SizedBox(height: 20),
                Field(controller: n, label: 'Full name', icon: Icons.person_outline),
                Field(controller: ph, label: 'Phone number', icon: Icons.phone_android_outlined, type: TextInputType.phone),
                Field(controller: e, label: 'Email', icon: Icons.email_outlined, type: TextInputType.emailAddress),
                _PasswordField(controller: p),
                if (ApiService.useFirebase)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text('Use the same email your workshop has on file to see your existing vehicles and history. At least 6 characters for the password.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ),
                SizedBox(width: double.infinity, height: 50, child: FilledButton(onPressed: load ? null : go, child: Text(load ? 'Creating...' : 'Create account'))),
              ]),
            ),
          ),
        ),
      ));
}
