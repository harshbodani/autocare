import 'package:flutter/material.dart';
import '../services/api.dart';

class Loading extends StatelessWidget {
  const Loading({super.key});
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF4F46E5)),
            SizedBox(height: 16),
            Text('Loading...', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500, fontSize: 14)),
          ],
        ),
      );
}

class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final double? elevation;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.03),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Card(
          elevation: elevation ?? 0,
          color: color ?? Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: const Color(0xFFE2E8F0), width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: child,
            ),
          ),
        ),
      );
}

class Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final TextInputType? type;
  final bool obscure;

  const Field({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.type,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextField(
          controller: controller,
          keyboardType: type,
          obscureText: obscure,
          style: const TextStyle(fontSize: 15, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
            prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF4F46E5), size: 20) : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          ),
        ),
      );
}

class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;

  const StatusBadge({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withOpacity(0.25), width: 1),
        ),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.6,
          ),
        ),
      );
}

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onAction;
  final String? actionLabel;

  const SectionHeader({
    super.key,
    required this.title,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
            if (onAction != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  foregroundColor: const Color(0xFF4F46E5),
                ),
                child: Text(actionLabel ?? 'View All', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
          ],
        ),
      );
}

/// Dialog to change the server address (needed once after deploying to Render).
Future<void> showServerSettings(BuildContext context) async {
  final c = TextEditingController(text: ApiService.host);
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Server settings'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Address of your AutoCare server on Render, for example https://autocare-api.onrender.com'),
        const SizedBox(height: 12),
        TextField(controller: c, keyboardType: TextInputType.url, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Server URL')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            await ApiService.setServerUrl(c.text);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

/// Thin banner shown when the phone cannot reach the server or changes are waiting to sync.
class SyncBanner extends StatelessWidget {
  const SyncBanner({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: ApiService.online,
        builder: (_, on, __) => ValueListenableBuilder<int>(
          valueListenable: ApiService.pending,
          builder: (_, n, __) {
            if (on && n == 0) return const SizedBox.shrink();
            final text = on
                ? 'Syncing $n change${n == 1 ? '' : 's'}...'
                : 'Offline - showing saved data${n > 0 ? ' - $n change${n == 1 ? '' : 's'} will sync later' : ''}';
            return Material(
              color: on ? const Color(0xFF4F46E5) : const Color(0xFFB45309),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(on ? Icons.sync : Icons.cloud_off, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Flexible(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12.5))),
                  ]),
                ),
              ),
            );
          },
        ),
      );
}
