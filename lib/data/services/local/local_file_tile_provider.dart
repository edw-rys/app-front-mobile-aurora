import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path_provider/path_provider.dart';

/// A custom tile provider that checks for a locally downloaded tile before falling back to network.
class LocalFileTileProvider extends TileProvider {
  String? _tilesPath;

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
        debugPrint('LocalFileTileProvider: Found tile $fileName');
        return FileImage(localFile);
      } else {
        debugPrint('LocalFileTileProvider: Tile NOT found at ${localFile.path}');
      }
    } else {
      debugPrint('LocalFileTileProvider: _tilesPath is NULL');
    }

    final url = options.urlTemplate!
        .replaceFirst('{x}', coordinates.x.toString())
        .replaceFirst('{y}', coordinates.y.toString())
        .replaceFirst('{z}', coordinates.z.toString());
    
    return NetworkImage(url);
  }
}
