import 'package:flutter/material.dart';
import 'auth.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  State<OnboardingScreen> createState() => _O();
}

class _O extends State<OnboardingScreen> {
  final pages = [
    [
      'Manage Customers',
      'Keep customer profiles and contact details organized.'
    ],
    ['Track Vehicles', 'Store vehicle details and complete service history.'],
    ['Book & Invoice', 'Schedule services, generate invoices and reminders.']
  ];
  int i = 0;
  @override
  Widget build(BuildContext c) => Scaffold(
      body: SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(children: [
                const Spacer(),
                Icon(
                    [Icons.people, Icons.directions_car, Icons.receipt_long][i],
                    size: 100),
                const SizedBox(height: 30),
                Text(pages[i][0],
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(pages[i][1],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16)),
                const Spacer(),
                Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                        3,
                        (j) => Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: j == i ? Colors.indigo : Colors.grey)))),
                const SizedBox(height: 25),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        onPressed: () {
                          if (i < 2)
                            setState(() => i++);
                          else
                            Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const LoginScreen()));
                        },
                        child: Text(i < 2 ? 'Next' : 'Get Started')))
              ]))));
}
