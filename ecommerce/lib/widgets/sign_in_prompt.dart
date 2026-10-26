import 'package:flutter/material.dart';

import '../services/shop_gateway.dart';
import '../screens/auth_screen.dart';

Future<bool> ensureSignedIn(BuildContext context, ShopGateway gateway) async {
  if (gateway.currentUser != null) return true;
  await Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => AuthScreen(gateway: gateway)));
  return context.mounted && gateway.currentUser != null;
}

class SignInPrompt extends StatelessWidget {
  const SignInPrompt({super.key, required this.gateway, required this.message});
  final ShopGateway gateway;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, size: 48),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => ensureSignedIn(context, gateway),
            child: const Text('Sign in'),
          ),
        ],
      ),
    ),
  );
}
