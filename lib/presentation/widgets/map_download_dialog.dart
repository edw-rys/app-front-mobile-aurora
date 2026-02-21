import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../data/services/local/map_downloader_service.dart';
import '../providers/meters_provider.dart';

class MapDownloadDialog extends ConsumerStatefulWidget {
  const MapDownloadDialog({super.key});

  @override
  ConsumerState<MapDownloadDialog> createState() => _MapDownloadDialogState();
}

class _MapDownloadDialogState extends ConsumerState<MapDownloadDialog> {
  final MapDownloaderService _service = MapDownloaderService();
  bool _isDownloading = false;
  double _progress = 0;
  int _downloadedCount = 0;
  int _totalCount = 0;
  bool _finished = false;
  String? _errorMessage;

  void _startDownload() async {
    final sectors = ref.read(metersProvider).sectors;
    if (sectors.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay sectores disponibles para descargar')),
        );
        Navigator.pop(context);
      }
      return;
    }

    double minLat = 90.0, maxLat = -90.0;
    double minLon = 180.0, maxLon = -180.0;

    void updateBounds(double? lat, double? lon) {
      if (lat == null || lon == null) return;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lon < minLon) minLon = lon;
      if (lon > maxLon) maxLon = lon;
    }

    for (var s in sectors) {
      updateBounds(s.point1Lat, s.point1Lon);
      updateBounds(s.point2Lat, s.point2Lon);
      updateBounds(s.point3Lat, s.point3Lon);
      updateBounds(s.point4Lat, s.point4Lon);
    }

    // Add buffer of about 1km
    minLat -= 0.009;
    maxLat += 0.009;
    minLon -= 0.009;
    maxLon += 0.009;

    setState(() {
      _isDownloading = true;
      _finished = false;
      _errorMessage = null;
    });

    try {
      await _service.downloadTilesInBounds(
        minLat: minLat,
        maxLat: maxLat,
        minLon: minLon,
        maxLon: maxLon,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _downloadedCount = current;
              _totalCount = total;
              _progress = total == 0 ? 0 : current / total;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _finished = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _service.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Descargar Mapa Offline'),
      content: _finished
          ? const Text('Descarga completada. El mapa ahora funcionará sin conexión en la zona de los medidores.')
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null)
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  )
                else
                  const Text('Se descargarán los mapas de la zona de tus medidores asignados para uso sin conexión.'),
                const SizedBox(height: 24),
                if (_isDownloading) ...[
                  LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: AppColors.border,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                  Text('$_downloadedCount / $_totalCount tiles', style: const TextStyle(fontSize: 12)),
                ]
              ],
            ),
      actions: [
        if (!_finished && !_isDownloading)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
        if (!_finished && !_isDownloading)
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: _startDownload,
            child: Text(_errorMessage != null ? 'Reintentar' : 'Descargar'),
          ),
        if (_isDownloading)
          TextButton(
            onPressed: () {
              _service.cancel();
              Navigator.pop(context);
            },
            child: const Text('Detener', style: TextStyle(color: Colors.red)),
          ),
        if (_finished)
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
      ],
    );
  }
}
