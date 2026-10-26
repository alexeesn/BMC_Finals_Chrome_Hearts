import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

import '../models/admin.dart';
import '../models/shopping.dart';

Future<UploadImage?> pickProductImage() async {
  const type = XTypeGroup(
    label: 'Product images',
    extensions: ['jpg', 'jpeg', 'png', 'webp'],
    mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
    uniformTypeIdentifiers: ['public.image'],
  );
  try {
    // Open before any network/permission await to preserve the browser's user gesture.
    final file = await openFile(acceptedTypeGroups: [type]);
    if (file == null) return null;
    if (await file.length() > 5 * 1024 * 1024) {
      throw const ShoppingException('Choose an image up to 5 MB.');
    }
    return UploadImage.validate(await file.readAsBytes());
  } on MissingPluginException {
    throw const ShoppingException(
      'Photo picker is not loaded. Stop Flutter and run the app again.',
    );
  }
}
