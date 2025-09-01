import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

import 'package:bcalio/controllers/location_controller.dart';
import 'package:bcalio/controllers/user_controller.dart';
import 'package:bcalio/utils/shared_preferens_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Clusters
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supercharged/supercharged.dart';

// Appel audio/vidéo
import 'package:bcalio/widgets/chat/chat_room/audio_call_screen.dart';
import 'package:bcalio/widgets/chat/chat_room/video_call_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _RouteInfo {
  final double distanceMeters;   // ex: 1234.5
  final double durationSeconds;  // ex: 567.0
  final List<LatLng> points;
  final String fromName;
  final String toName;

  const _RouteInfo({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.points,
    required this.fromName,
    required this.toName,
  });
}

class _MapScreenState extends State<MapScreen> {
  final LocationController controller = Get.put(LocationController());
  final UserController userController = Get.find<UserController>();

  // Carte
  final MapController _mapController = MapController();
  bool _mapReady = false;
  bool _pendingFitAll = false;

  // Position par défaut (Tunis)
  double latitude = 36.80337682348026;
  double longitude = 10.185501791058773;

  // Nom “moi”
  String _selfName = 'You';

  bool isLoading = true;

  final List<Marker> _markers = [];
  final List<Polyline> _polylines = [];

  _RouteInfo? _routeInfo; // info distance/durée + noms

  LatLng get _me => LatLng(latitude, longitude);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAndDisplay());
  }

  Future<void> _loadAndDisplay() async {
    try {
      final hasPermission = await controller.checkAndRequestPermission();
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }

      latitude = (await SharedPreferensHelper.getLatitude()) ?? latitude;
      longitude = (await SharedPreferensHelper.getLongitude()) ?? longitude;

      final name  = (await SharedPreferensHelper.getName())  ?? "You";
      final image = (await SharedPreferensHelper.getImage()) ?? "Unknown";
      final about = (await SharedPreferensHelper.getAbout()) ?? "Unknown";
      _selfName   = name;

      final fcmToken = await SharedPreferensHelper.getFcmToken();

      if (fcmToken != null) {
        await userController.updateProfile(
          name: name,
          image: image,
          about: about,
          geolocalisation: latitude.toString(),
          screenshotToken: longitude.toString(),
          rfcToken: fcmToken,
        );
      }

      final prefs = await SharedPreferences.getInstance();
      final userImage = prefs.getString('image') ?? '';

      final contacts = await controller.getContactsLocations();

      final List<Marker> built = [];

      // Marqueur “moi”
      built.add(
        Marker(
          width: 80,
          height: 80,
          point: _me,
          child: Column(
            children: [
              userImage.isNotEmpty
                  ? CircleAvatar(radius: 15, backgroundImage: NetworkImage(userImage))
                  : Image.asset(
                      "assets/img/user_avatar.png",
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                    ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _selfName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      // Marqueurs contacts
      for (final loc in contacts) {
        final lat = double.tryParse(loc['latitude'].toString());
        final lng = double.tryParse(loc['longitude'].toString());
        final cid    = (loc['id']    ?? '').toString(); // ← pour les appels
        final cname  = (loc['name']  ?? '').toString();
        final cimage = (loc['image'] ?? '').toString();
        final cemail = (loc['email'] ?? '').toString();
        final cphone = (loc['phone'] ?? '').toString();

        if (lat == null || lng == null) continue;

        final point = LatLng(lat, lng);

        built.add(
          Marker(
            width: 100,
            height: 100,
            point: point,
            child: GestureDetector(
              onTap: () async {
                // Itinéraire + pill avec noms + distance/durée
                await _showRouteTo(point, cname);
              },
              onDoubleTap: () {
                // Fiche contact (double-tap) + actions d’appel
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) => _buildContactDetailsBottomSheet(
                    id: cid,
                    name: cname,
                    image: cimage,
                    email: cemail,
                    phone: cphone,
                  ),
                ).whenComplete(() {
                  setState(() {
                    _polylines.clear();
                    _routeInfo = null; // masque la pill
                  });
                  _fitAllSafe();
                });
              },
              child: Column(
                children: [
                  cimage.isNotEmpty
                      ? CircleAvatar(radius: 15, backgroundImage: NetworkImage(cimage))
                      : const Icon(Icons.person_pin_circle, color: Colors.red, size: 40),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.6),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      cname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _markers
          ..clear()
          ..addAll(built);
        isLoading = false;
      });

      // ⛔️ SnackBar d'aide supprimé ici (aucun autre changement)

      _fitAllSafe();
    } catch (e) {
      if (!mounted) return;
      debugPrint("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading locations: $e')),
      );
    }
  }

  /// Affiche un itinéraire entre _me et [to], met à jour _routeInfo (inclut les NOMS)
  Future<void> _showRouteTo(LatLng to, String toName) async {
    try {
      final info = await _fetchOsrmDetailed(_me, to, _selfName, toName);
      setState(() {
        _polylines
          ..clear()
          ..add(Polyline(points: info.points, color: Colors.deepPurpleAccent, strokeWidth: 5));
        _routeInfo = info;
      });
      _fitPointsSafe(info.points);
    } catch (_) {
      // Fallback : ligne droite avec estimation
      final line = [_me, to];
      final d = const Distance().as(LengthUnit.Meter, _me, to); // mètres
      // Vitesse moyenne 50 km/h → 13.8889 m/s
      final secs = d / 13.8889;
      final info = _RouteInfo(
        distanceMeters: d,
        durationSeconds: secs,
        points: line,
        fromName: _selfName,
        toName: toName,
      );

      setState(() {
        _polylines
          ..clear()
          ..add(Polyline(points: line, color: Colors.deepPurpleAccent, strokeWidth: 5));
        _routeInfo = info;
      });
      _fitPointsSafe(line);
    }
  }

  /// OSRM: récupère points + distance/durée (driving)
  Future<_RouteInfo> _fetchOsrmDetailed(
    LatLng from,
    LatLng to,
    String fromName,
    String toName,
  ) async {
    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${from.longitude},${from.latitude};'
      '${to.longitude},${to.latitude}'
      '?overview=full&geometries=geojson',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('OSRM status=${res.statusCode}');
    }
    final data = json.decode(res.body);
    final route = data['routes'][0];
    final coords = (route['geometry']['coordinates'] as List)
        .map<LatLng>((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();

    final distance = (route['distance'] as num).toDouble(); // meters
    final duration = (route['duration'] as num).toDouble(); // seconds

    return _RouteInfo(
      distanceMeters: distance,
      durationSeconds: duration,
      points: coords,
      fromName: fromName,
      toName: toName,
    );
  }

  /// Fit sûr (attend que la carte soit prête)
  void _fitAllSafe() {
    if (!_mapReady) {
      _pendingFitAll = true;
      return;
    }
    _pendingFitAll = false;
    if (_markers.isEmpty) return;

    if (_markers.length == 1) {
      _mapController.move(_markers.first.point, 13.0);
      return;
    }

    final bounds = LatLngBounds.fromPoints(_markers.map((m) => m.point).toList());
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
    );
  }

  /// Fit sur des points, sécurisé
  void _fitPointsSafe(List<LatLng> pts) {
    if (!_mapReady) {
      _pendingFitAll = true; // sécurité : recadrera quand prêt
      return;
    }
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      _mapController.move(pts.first, 14.0);
      return;
    }
    final bounds = LatLngBounds.fromPoints(pts);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
    );
  }

  String _fmtDistance(double meters) {
    if (meters < 950) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _fmtDuration(double seconds) {
    final s = seconds.round();
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (h >= 1) {
      return '${h}h ${m}m';
    }
    return '${m} min';
  }

  Widget _routeInfoPill() {
    final info = _routeInfo!;
    final dist = _fmtDistance(info.distanceMeters);
    final dura = _fmtDuration(info.durationSeconds);

    return AnimatedSlide(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      offset: Offset.zero,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.deepPurpleAccent, Colors.blueAccent.shade200],
                      ),
                    ),
                    child: const Icon(Icons.route, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Les DEUX NOMS
                        Text(
                          '${info.fromName} ↔ ${info.toName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$dist • $dura',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _polylines.clear();
                        _routeInfo = null;
                      });
                      _fitAllSafe();
                    },
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final map = FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _me,
        initialZoom: 13.0,
        onMapReady: () {
          _mapReady = true;
          if (_pendingFitAll) _fitAllSafe();
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.elite.bcalio.app',
        ),
        if (_polylines.isNotEmpty) PolylineLayer(polylines: _polylines),
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            markers: _markers,
            maxClusterRadius: 45,
            size: const Size(40, 40),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(50),
            builder: (context, cluster) => Container(
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Center(
                child: Text(
                  cluster.count.toString(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    // On superpose la carte et la pill (EN BAS)
    return Stack(
      children: [
        Positioned.fill(child: map),
        if (_routeInfo != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              bottom: true,
              child: Padding(
                // marge pour ne pas chevaucher la BottomNavyBar
                padding: EdgeInsets.only(
                  bottom: 12 + MediaQuery.of(context).size.height * 0.09,
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _routeInfoPill(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildContactDetailsBottomSheet({
    required String id,
    required String name,
    required String image,
    required String email,
    required String phone,
  }) {
    final myId = userController.userId;

    return Container(
      padding: const EdgeInsets.all(16.0),
      width: double.infinity,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundImage: image.isNotEmpty ? NetworkImage(image) : null,
            child: image.isEmpty ? const Icon(Icons.person, size: 40) : null,
          ),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(phone, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(email, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 16),

          // Boutons Appel audio / vidéo
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    if (id.isEmpty) {
                      Get.snackbar('Erreur', 'Impossible de lancer l’appel (ID manquant)',
                          backgroundColor: Colors.red, colorText: Colors.white);
                      return;
                    }
                    Navigator.of(context).pop(); // fermer la bottom sheet
                    Get.to(() => AudioCallScreen(
                          name: name,
                          avatarUrl: image.isNotEmpty ? image : null,
                          phoneNumber: phone,
                          recipientID: id,
                          userId: myId,
                          isCaller: true,
                          existingCallId: null,
                        ));
                  },
                  icon: const Icon(Iconsax.call, size: 20),
                  label: const Text('Appel audio'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.deepPurpleAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    if (id.isEmpty) {
                      Get.snackbar('Erreur', 'Impossible de lancer l’appel (ID manquant)',
                          backgroundColor: Colors.red, colorText: Colors.white);
                      return;
                    }
                    Navigator.of(context).pop(); // fermer la bottom sheet
                    Get.to(() => VideoCallScreen(
                          name: name,
                          avatarUrl: image.isNotEmpty ? image : null,
                          phoneNumber: phone,
                          recipientID: id,
                          userId: myId,
                          isCaller: true,
                          existingCallId: null,
                        ));
                  },
                  icon: const Icon(Iconsax.video, size: 20),
                  label: const Text('Appel vidéo'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
