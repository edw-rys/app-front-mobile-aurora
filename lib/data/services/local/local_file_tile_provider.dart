import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path_provider/path_provider.dart';

/// A custom tile provider that:
/// 1. First serves tiles from local disk cache (offline mode).
/// 2. If not found locally, fetches from the network using a proper
///    User-Agent header to comply with OSM's tile usage policy.
class LocalFileTileProvider extends TileProvider {
  String? _tilesPath;

  /// User-Agent required by OSM tile usage policy.
  /// See: https://operations.osmfoundation.org/policies/tiles/
  static const String _userAgent =
      'AuroraLecturas/1.0 (com.edinky.smartframedev.aurora; contact@edinky.com)';

  LocalFileTileProvider({String? tilesPath}) : _tilesPath = tilesPath {
    if (_tilesPath == null) {
      _initPath();
    }
  }

  Future<void> _initPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    _tilesPath = '${appDir.path}/map_tiles';
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    if (_tilesPath != null) {
      final fileName = '${coordinates.z}-${coordinates.x}-${coordinates.y}.png';
      final localFile = File('$_tilesPath/$fileName');

      if (localFile.existsSync()) {
        return FileImage(localFile);
      }
    }

    // Fallback: fetch the tile from the network with a proper User-Agent
    final url = options.urlTemplate!
        .replaceFirst('{x}', coordinates.x.toString())
        .replaceFirst('{y}', coordinates.y.toString())
        .replaceFirst('{z}', coordinates.z.toString());

    return NetworkImage(url, headers: {'User-Agent': _userAgent});
  }
}
