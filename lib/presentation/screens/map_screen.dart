import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_colors.dart';
import '../providers/meters_provider.dart';
import '../widgets/gps_onboarding_sheet.dart';
import '../../data/models/meter_model.dart';
import '../../data/services/local/local_file_tile_provider.dart';
import '../../shared/widgets/sector_picker_sheet.dart';

/// Map screen showing meter locations with clustering, search, geolocation, and routing.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  // Palora, Ecuador default center
  static const LatLng _defaultCenter = LatLng(-1.7, -77.9);
  
  MeterModel? _selectedMeter;
  SectorModel? _selectedSector;
  LatLng? _userLocation;
  List<LatLng> _routePoints = [];
  bool _isLocating = false;
  bool _isRouting = false;
  
  List<MeterModel> _searchResults = [];
  bool _showSearchResults = false;
  String? _tilesPath;

  @override
  void initState() {
    super.initState();
    _initTilesPath();
    _checkLocationPermissionAndFetch();
  }

  Future<void> _initTilesPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    if (mounted) {
      setState(() => _tilesPath = '${appDir.path}/map_tiles');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _checkLocationPermissionAndFetch() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Option to show localized alert or just return
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
        });
        
        if (_selectedMeter == null) {
          _mapController.move(_userLocation!, 16);
        }
      }
    } catch (e) {
      debugPrint("Error checking location: $e");
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _requestLocationAndFetch() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por favor, activa el GPS para ubicarte en el mapa.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          await GpsOnboardingSheet.show(context);
        }
        permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });
      
      if (_selectedMeter == null) {
        _mapController.move(_userLocation!, 16);
      }
    } catch (e) {
      debugPrint("Error getting location: $e");
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _calculateRouteToSelected() async {
    if (_userLocation == null || _selectedMeter == null || !_selectedMeter!.geo.hasCoordinates) {
      setState(() => _routePoints = []);
      return;
    }

    setState(() => _isRouting = true);
    try {
      final start = _userLocation!;
      final end = LatLng(_selectedMeter!.geo.lat!, _selectedMeter!.geo.lon!);
      
      final dio = Dio();
      final url = 'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson';
      final response = await dio.get(url, options: Options(validateStatus: (status) => true));
      
      if (response.statusCode == 200 && response.data['routes'] != null && response.data['routes'].isNotEmpty) {
        final coords = response.data['routes'][0]['geometry']['coordinates'] as List;
        setState(() {
          _routePoints = coords.map((c) => LatLng(c[1] as double, c[0] as double)).toList();
        });
        
        // Fit bounds for route
        final bounds = LatLngBounds.fromPoints([start, end, ..._routePoints]);
        _mapController.fitCamera(CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
        ));
      } else {
        setState(() => _routePoints = []);
      }
    } catch (e) {
      debugPrint("Routing error: $e");
      setState(() => _routePoints = []);
    } finally {
      if (mounted) setState(() => _isRouting = false);
    }
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }
    
    final results = ref.read(metersProvider.notifier).searchMeters(query);
    // Only show meters that have coordinates
    final mapResults = results.where((m) => m.geo.hasCoordinates).take(10).toList();
    
    setState(() {
      _searchResults = mapResults;
      _showSearchResults = true;
    });
  }

  void _selectMeter(MeterModel meter) {
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() {
      _selectedMeter = meter;
      _showSearchResults = false;
      _searchResults = [];
    });
    
    _mapController.move(LatLng(meter.geo.lat!, meter.geo.lon!), 18);
    _calculateRouteToSelected();
    
    // NO auto-open sheet from search results as per user request
    // _showMeterDetailsSheet(context, meter);
  }

  // Removed unused _clearSelection since selection is cleared in whenComplete of bottom sheet.

  void _onSectorChanged(SectorModel? sector) {
    setState(() {
      _selectedSector = sector;
      _selectedMeter = null;
      _routePoints = [];
    });
    
    if (sector != null) {
      // Zoom to sector
      final points = [
        if (sector.point1Lat != null && sector.point1Lon != null) LatLng(sector.point1Lat!, sector.point1Lon!),
        if (sector.point2Lat != null && sector.point2Lon != null) LatLng(sector.point2Lat!, sector.point2Lon!),
        if (sector.point3Lat != null && sector.point3Lon != null) LatLng(sector.point3Lat!, sector.point3Lon!),
        if (sector.point4Lat != null && sector.point4Lon != null) LatLng(sector.point4Lat!, sector.point4Lon!),
      ];
      
      if (points.isNotEmpty) {
        final bounds = LatLngBounds.fromPoints(points);
        _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
      }
    }
    
    _calculateShortestRoute(meters: ref.read(metersProvider).meters);
  }

  void _showMeterDetailsSheet(BuildContext context, MeterModel meter) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.1),
      builder: (context) => FutureBuilder<PermissionStatus>(
        future: Permission.locationWhenInUse.status,
        builder: (context, permSnapshot) {
          final permission = permSnapshot.data ?? PermissionStatus.denied;
          return FutureBuilder<bool>(
            future: Geolocator.isLocationServiceEnabled(),
            builder: (context, gpsSnapshot) {
              final gpsEnabled = gpsSnapshot.data ?? false;
              return _MeterDetailsSheet(
                meter: meter,
                isRouting: _isRouting,
                hasPermission: permission.isGranted,
                gpsEnabled: gpsEnabled,
                onClose: () => Navigator.pop(context),
                onRoute: () {
                  Navigator.pop(context);
                  _calculateRouteToSelected();
                },
              );
            }
          );
        }
      ),
    ).whenComplete(() {
      setState(() {
        _selectedMeter = null;
        _routePoints = [];
      });
    });
  }

  void _calculateShortestRoute({required List<MeterModel> meters}) {
    if (_userLocation == null) return;
    
    // Filter unread meters in current sector
    final unreadMeters = meters.where((m) {
      final hasReading = ref.read(metersProvider).readings.containsKey(m.nAbonado);
      final isInSector = _selectedSector == null || m.sector?.name == _selectedSector!.name;
      return !hasReading && isInSector && m.geo.hasCoordinates;
    }).toList();

    if (unreadMeters.isEmpty) return;

    // Find nearest unread meter
    MeterModel? nearest;
    double minDistance = double.infinity;
    
    for (var m in unreadMeters) {
      final dist = Geolocator.distanceBetween(
        _userLocation!.latitude, _userLocation!.longitude,
        m.geo.lat!, m.geo.lon!
      );
      if (dist < minDistance) {
        minDistance = dist;
        nearest = m;
      }
    }

    if (nearest != null) {
      _selectMeter(nearest);
    }
  }

  @override
  Widget build(BuildContext context) {
    final metersState = ref.watch(metersProvider);

    // Build markers filtered by sector
    final markers = <Marker>[];
    for (final meter in metersState.meters) {
      // Improved sector filtering: compare trimmed version just in case
      if (_selectedSector != null) {
        final mSector = meter.sector?.name.trim().toLowerCase();
        final sSector = _selectedSector!.name.trim().toLowerCase();
        if (mSector != sSector) continue;
      }

      if (meter.geo.hasCoordinates) {
        final isSelected = _selectedMeter?.nAbonado == meter.nAbonado;
        final hasReading = metersState.readings.containsKey(meter.nAbonado);
        
        markers.add(Marker(
          point: LatLng(meter.geo.lat!, meter.geo.lon!),
          width: isSelected ? 50 : 30,
          height: isSelected ? 50 : 30,
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedMeter = meter);
              _showMeterDetailsSheet(context, meter);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: isSelected 
                    ? Colors.orange 
                    : (hasReading ? AppColors.success : AppColors.primary),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
                boxShadow: [
                  BoxShadow(
                    color: (isSelected ? Colors.orange : Colors.black).withValues(alpha: isSelected ? 0.6 : 0.2),
                    blurRadius: isSelected ? 12 : 4,
                    spreadRadius: isSelected ? 4 : 0,
                    offset: Offset(0, isSelected ? 0 : 2),
                  ),
                ],
              ),
              child: Icon(
                hasReading ? Icons.check_rounded : (isSelected ? Icons.person_pin_circle_rounded : Icons.water_drop_rounded),
                color: Colors.white,
                size: isSelected ? 28 : 16,
              ),
            ),
          ),
        ));
      }
    }

    // Include user location marker if available
    if (_userLocation != null) {
      markers.add(Marker(
        point: _userLocation!,
        width: 40,
        height: 40,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blueAccent,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withValues(alpha: 0.4),
                blurRadius: 10,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 20),
        ),
      ));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _tilesPath == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
          // ── Map Layer ──────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: 14,
              minZoom: 14,
              maxZoom: 17,
              onTap: (_, __) {
                if (_showSearchResults) {
                  setState(() => _showSearchResults = false);
                  _searchFocus.unfocus();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.edinky.smartframedev.aurora',
                tileProvider: LocalFileTileProvider(tilesPath: _tilesPath),
                minZoom: 14,
                maxZoom: 17,
              ),
              if (_selectedSector != null)
                Builder(builder: (ctx) {
                  final points = [
                    if (_selectedSector!.point1Lat != null && _selectedSector!.point1Lon != null) LatLng(_selectedSector!.point1Lat!, _selectedSector!.point1Lon!),
                    if (_selectedSector!.point2Lat != null && _selectedSector!.point2Lon != null) LatLng(_selectedSector!.point2Lat!, _selectedSector!.point2Lon!),
                    if (_selectedSector!.point3Lat != null && _selectedSector!.point3Lon != null) LatLng(_selectedSector!.point3Lat!, _selectedSector!.point3Lon!),
                    if (_selectedSector!.point4Lat != null && _selectedSector!.point4Lon != null) LatLng(_selectedSector!.point4Lat!, _selectedSector!.point4Lon!),
                  ];
                  
                  if (points.isEmpty) return const SizedBox.shrink();

                  return PolygonLayer(
                    polygons: [
                      Polygon(
                        points: points,
                        color: Colors.blueAccent.withValues(alpha: 0.15),
                        borderColor: Colors.blueAccent.withValues(alpha: 0.5),
                        borderStrokeWidth: 2,
                      ),
                    ],
                  );
                }),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: Colors.blueAccent,
                      strokeWidth: 5.0,
                    ),
                  ],
                ),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 45,
                  size: const Size(40, 40),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(50),
                  markers: markers,
                  builder: (context, clusterMarkers) {
                    // Check if cluster contains selected
                    bool hasSelected = false;
                    if (_selectedMeter != null) {
                       hasSelected = clusterMarkers.any((m) => m.point.latitude == _selectedMeter!.geo.lat && m.point.longitude == _selectedMeter!.geo.lon);
                    }
                    
                    return Container(
                      decoration: BoxDecoration(
                        color: hasSelected ? Colors.orange : AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          clusterMarkers.length.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // ── Search & Header UI ─────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 5, 16, 0),
              child: Column(
                children: [
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Buscar por cliente, abn, medidor...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                        prefixIcon: IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : const Icon(Icons.search_rounded, color: Color(0xFFCBD5E1)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Sector Searcher (Searchable Bottom Sheet)
                  if (metersState.sectors.isNotEmpty)
                    GestureDetector(
                      onTap: () => _showSectorPicker(context, metersState.sectors),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: _selectedSector == null ? 12 : 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.map_rounded, size: 20, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedSector?.name ?? 'Filtrar por sector',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _selectedSector == null ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                                  fontWeight: _selectedSector == null ? FontWeight.normal : FontWeight.w600,
                                ),
                              ),
                            ),
                            if (_selectedSector != null)
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () {
                                  _onSectorChanged(null);
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              )
                            else
                              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFCBD5E1)),
                          ],
                        ),
                      ),
                    ),

                  // Search Results Dropdown
                  if (_showSearchResults && _searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 300),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final m = _searchResults[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            title: Text(m.clientName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            subtitle: Text('${m.nAbonado} · ${m.address}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                            onTap: () => _selectMeter(m),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Selected Meter Bottom Card (Removed in favor of Modal) ──────
        ],
      ),
      
      // ── FAB My Location ──────────────────────────────────
      floatingActionButton: _selectedMeter == null ? FloatingActionButton(
        onPressed: _requestLocationAndFetch,
        backgroundColor: Colors.white,
        child: _isLocating 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(Icons.my_location_rounded, color: AppColors.primary),
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _showSectorPicker(BuildContext context, List<SectorModel> allSectors) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SectorPickerSheet(
        sectors: allSectors,
        selectedSector: _selectedSector,
        onSelect: (s) {
          _onSectorChanged(s);
        },
      ),
    );
  }
}

class _MeterDetailsSheet extends StatelessWidget {
  final MeterModel meter;
  final bool isRouting;
  final bool hasPermission;
  final bool gpsEnabled;
  final VoidCallback onClose;
  final VoidCallback onRoute;

  const _MeterDetailsSheet({
    required this.meter,
    required this.isRouting,
    required this.hasPermission,
    required this.gpsEnabled,
    required this.onClose,
    required this.onRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meter.clientName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        meter.nAbonado,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppColors.primary,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                onPressed: onClose,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Route button (small, above register button)
          Row(
            children: [
              Opacity(
                opacity: (hasPermission && gpsEnabled) ? 1.0 : 0.4,
                child: TextButton.icon(
                  onPressed: (hasPermission && gpsEnabled) ? onRoute : null,
                  icon: const Icon(Icons.directions_rounded, size: 20),
                  label: const Text('Marcar ruta', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              if (!hasPermission || !gpsEnabled) ...[
                const SizedBox(width: 8),
                Icon(Icons.info_outline_rounded, size: 14, color: Colors.orange.shade700),
                const SizedBox(width: 4),
                Text(
                  !gpsEnabled ? 'GPS desactivado' : 'Sin permisos GPS',
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.w500),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  meter.address,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isRouting) ...[
            const Row(
              children: [
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Text(
                  'Calculando ruta óptima...',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              icon: const Icon(Icons.edit_document),
              label: const Text(
                'Registrar lectura',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              onPressed: () {
                Navigator.pop(context); // Close sheet
                // Use push to allow back navigation to map
                context.push('/meters/${Uri.encodeComponent(meter.nAbonado)}');
              },
            ),
          ),
        ],
      ),
    );
  }
}

