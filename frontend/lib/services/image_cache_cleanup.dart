import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Only camera/picker cache paths emitted by the installed Android plugins.
class ImageCacheCleanup {
  const ImageCacheCleanup._();

  static bool isOwnedImage(String relativePath) {
    final parts = p.split(relativePath);
    if (parts.length == 1) {
      return RegExp(r'^CAP[0-9]+\.jpg$').hasMatch(parts.single);
    }
    return parts.length == 2 &&
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        ).hasMatch(parts.first) &&
        RegExp(
          r'\.(jpg|jpeg|png|webp|heic|heif|bmp|gif)$',
          caseSensitive: false,
        ).hasMatch(parts.last);
  }

  static Future<void> delete(String path) async {
    final cache = await getTemporaryDirectory();
    // Never delete a source gallery file outside app cache, including symlinks.
    final file = File(path);
    if (!await file.exists()) return;
    final root = await cache.resolveSymbolicLinks();
    final resolved = await file.resolveSymbolicLinks();
    if (!p.isWithin(root, resolved)) return;
    await file.delete();
  }

  static Future<void> purgeOrphans() async {
    try {
      final cache = await getTemporaryDirectory();
      if (!await cache.exists()) return;
      await for (final entry in cache.list(followLinks: false)) {
        final relative = p.relative(entry.path, from: cache.path);
        if (entry is File && isOwnedImage(relative)) {
          await delete(entry.path);
        } else if (entry is Directory &&
            isOwnedImage(p.join(relative, 'image.jpg'))) {
          await for (final child in entry.list(followLinks: false)) {
            if (child is File &&
                isOwnedImage(p.relative(child.path, from: cache.path))) {
              await delete(child.path);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[ImageCacheCleanup] Cleanup failed: ${e.runtimeType}');
    }
  }
}
