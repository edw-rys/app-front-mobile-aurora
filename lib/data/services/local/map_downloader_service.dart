import 'dart:io';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class MapDownloaderService {
  final Dio _dio = Dio();
  bool _isCancelled = false;
  
  void cancel() => _isCancelled = true;

  /// Calculates the tile coordinates for a given lat/lon and zoom.
  math.Point<int> _latLonToTile(double lat, double lon, int zoom) {
    final n = math.pow(2.0, zoom);
    final x = (lon + 180.0) / 360.0 * n;
    final latRad = lat * math.pi / 180.0;
    final y = (1.0 - math.log(math.tan(latRad) + (1.0 / math.cos(latRad))) / math.pi) / 2.0 * n;
    return math.Point(x.floor(), y.floor());
  }

  /// Downloads tiles within a bounding box for zooms 14 to 17.
  Future<void> downloadTilesInBounds({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    required Function(int current, int total) onProgress,
  }) async {
    _isCancelled = false;
    final appDir = await getApplicationDocumentsDirectory();
    final tilesDir = Directory('${appDir.path}/map_tiles');
    
    // REQUIREMENT: Clear previous images before starting
    if (tilesDir.existsSync()) {
      tilesDir.deleteSync(recursive: true);
    }
    tilesDir.createSync(recursive: true);

    final urlsToDownload = <String, String>{}; // url -> localPath

    for (int z = 14; z <= 17; z++) {
      final p1 = _latLonToTile(maxLat, minLon, z);
      final p2 = _latLonToTile(minLat, maxLon, z);

      final minX = math.min(p1.x, p2.x);
      final maxX = math.max(p1.x, p2.x);
      final minY = math.min(p1.y, p2.y);
      final maxY = math.max(p1.y, p2.y);

      // Limiting reasonable area to avoid infinite hanging if bounds are huge
      for (int x = minX; x <= maxX; x++) {
        for (int y = minY; y <= maxY; y++) {
          final url = 'https://tile.openstreetmap.org/$z/$x/$y.png';
          final localPath = '${tilesDir.path}/$z-$x-$y.png';
          urlsToDownload[url] = localPath;
        }
      }
    }

    final total = urlsToDownload.length;
    int current = 0;
    int successCount = 0;
    onProgress(0, total);

    if (total == 0) return;

    // Check connectivity for the first tile to fail fast if no internet
    try {
      final firstTile = urlsToDownload.keys.first;
      await _dio.head(firstTile, options: Options(
        headers: {'User-Agent': 'com.edinky.smartframedev.aurora'},
        connectTimeout: const Duration(seconds: 5),
      ));
    } catch (e) {
      throw 'No hay conexión a internet para descargar el mapa.';
    }

    // Download with concurrency 5
    final entries = urlsToDownload.entries.toList();
    for (int i = 0; i < entries.length; i += 5) {
      if (_isCancelled) break;
      final chunk = entries.skip(i).take(5);
      await Future.wait(chunk.map((entry) async {
        if (_isCancelled) return;
        final url = entry.key;
        final localPath = entry.value;
        
        try {
          await _dio.download(
            url,
            localPath,
            options: Options(
              headers: {'User-Agent': 'com.edinky.smartframedev.aurora'},
              receiveTimeout: const Duration(seconds: 10),
              sendTimeout: const Duration(seconds: 10),
            ),
          );
          successCount++;
        } catch (e) {
          // We don't necessarily want to kill the whole process for ONE tile failure
          // unless it's a persistent connection issue.
        }
      }));
      
      current += chunk.length;
      if (current > total) current = total;
      onProgress(current, total);
    }

    if (_isCancelled) {
      throw 'Descarga cancelada.';
    }

    if (successCount == 0 && total > 0) {
      throw 'No se pudo descargar ningún tile. Revisa tu conexión.';
    }
  }
}
