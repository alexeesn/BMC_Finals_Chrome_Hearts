import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/order.dart';
import '../models/shopping.dart';

/// Recovery convenience only. Orders and payment status remain in Supabase.
class CheckoutAttemptStore {
  late final _preferences = SharedPreferencesAsync();
  String _key(String owner) =>
      'checkout.v1.${Uri.parse(AppConfig.supabaseUrl).host}.$owner';
  Future<CheckoutAttempt?> read(String owner) async {
    final raw = await _preferences.getString(_key(owner));
    if (raw == null) return null;
    try {
      return CheckoutAttempt.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      throw const ShoppingException(
        'Unable to restore checkout. Check My orders before placing another order.',
      );
    }
  }

  Future<void> save(String owner, CheckoutAttempt attempt) =>
      _preferences.setString(_key(owner), jsonEncode(attempt.toJson()));
  Future<void> clear(String owner, String expectedKey) async {
    final current = await read(owner);
    if (current?.key == expectedKey) await _preferences.remove(_key(owner));
  }
}
