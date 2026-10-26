import 'package:flutter/material.dart';

import '../services/shop_gateway.dart';
import '../screens/auth_screen.dart';
import 'shop_layout.dart';

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
  Widget build(BuildContext context) => ShopEmptyState(
    icon: Icons.lock_outline,
    title: 'Keep your collection close.',
    message: message,
    action: FilledButton(
      onPressed: () => ensureSignedIn(context, gateway),
      child: const Text('Sign in'),
    ),
  );
}
