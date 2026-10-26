import 'package:flutter/material.dart';

import '../models/shopping.dart';

void showShoppingError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        error is ShoppingException
            ? error.message
            : 'Unable to save changes. Check your connection and try again.',
      ),
    ),
  );
}
