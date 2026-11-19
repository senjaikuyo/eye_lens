import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:eye_lens/features/camera/logic/camera_input_policy.dart';
import 'package:eye_lens/core/services/image_cache_cleanup.dart';

void main() {
  test('focus maps center, edges and cropped cover preview', () {
    expect(
      CameraInputPolicy.focusPoint(
        const Offset(50, 100),
        const Size(100, 200),
        const Size(200, 200),
      ),
      const Offset(.5, .5),
    );
    expect(
      CameraInputPolicy.focusPoint(
        Offset.zero,
        const Size(100, 200),
        const Size(200, 200),
      ),
      const Offset(.25, 0),
    );
    expect(
      CameraInputPolicy.focusPoint(
        const Offset(200, 100),
        const Size(200, 100),
        const Size(200, 100),
      ),
      const Offset(1, 1),
    );
  });

  test('invalid focus geometry is rejected', () {
    expect(
      () => CameraInputPolicy.focusPoint(
        Offset.zero,
        Size.zero,
        const Size(100, 200),
      ),
      throwsArgumentError,
    );
  });

  test(
    'gallery budget preserves small images and bounds large aspect ratios',
    () {
      expect(
        CameraInputPolicy.boundedSize(
          const Size(3000, 4000),
          CameraInputPolicy.galleryMaxPixels,
        ),
        const Size(3000, 4000),
      );
      for (final size in [const Size(8000, 6000), const Size(20000, 1000)]) {
        final target = CameraInputPolicy.boundedSize(
          size,
          CameraInputPolicy.galleryMaxPixels,
        );
        expect(
          target.width * target.height,
          lessThanOrEqualTo(CameraInputPolicy.galleryMaxPixels),
        );
        expect(
          target.width / target.height,
          closeTo(size.width / size.height, .01),
        );
      }
    },
  );

  test('orphan cleanup matches only installed plugin image naming', () {
    expect(ImageCacheCleanup.isOwnedImage('CAP12345.jpg'), isTrue);
    expect(
      ImageCacheCleanup.isOwnedImage(
        '12345678-abcd-abcd-abcd-123456789abc/photo.png',
      ),
      isTrue,
    );
    for (final path in [
      'history.db',
      'other/photo.jpg',
      'CAPnotes.jpg',
      '../CAP123.jpg',
      '12345678-abcd-abcd-abcd-123456789abc/data.db',
    ]) {
      expect(ImageCacheCleanup.isOwnedImage(path), isFalse);
    }
  });
}
