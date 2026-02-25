import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../../core/config/app_config.dart';

/// Compresses any image to WebP (or JPEG) and saves it locally.
/// Reads config from AppConfig (IMAGE_MAX_WIDTH, IMAGE_MAX_HEIGHT, IMAGE_QUALITY).
/// Ensures the result is ≤ 1 MB; if still over 1 MB after first pass, retries
/// with lower quality until it fits or quality reaches 40.
class ImageCompressionService {
  static const int _maxBytesHard = 900 * 1024; // 900 KB hard cap

  /// Compress [sourcePath] and return the path of the saved compressed file.
  /// The returned file is stored in the app's document directory under `images/`.
  Future<String> compressAndSave(String sourcePath) async {
    final docDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(path.join(docDir.path, 'images'));
    if (!imagesDir.existsSync()) {
      imagesDir.createSync(recursive: true);
    }

    final extension = AppConfig.imageFormat == 'webp' ? '.webp' : '.jpg';
    final fileName = '${DateTime.now().millisecondsSinceEpoch}$extension';
    final targetPath = path.join(imagesDir.path, fileName);

    int quality = AppConfig.imageQuality;
    XFile? result;

    // Try compression; reduce quality if still above hard cap
    while (quality >= 40) {
      result = await FlutterImageCompress.compressAndGetFile(
        sourcePath,
        targetPath,
        minWidth: AppConfig.imageMaxWidth,
        minHeight: AppConfig.imageMaxHeight,
        quality: quality,
        format: AppConfig.imageFormat == 'webp'
            ? CompressFormat.webp
            : CompressFormat.jpeg,
      );

      if (result == null) break;

      final bytes = await result.length();
      if (bytes <= _maxBytesHard) break;

      // Still too large — reduce quality by 10 and retry
      quality -= 10;
    }

    if (result == null) {
      throw Exception('No se pudo comprimir la imagen');
    }

    return result.path;
  }
}
