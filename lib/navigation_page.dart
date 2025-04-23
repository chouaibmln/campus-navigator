import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_project/webview.dart';
import 'package:google_maps_project/routes.dart';
import 'package:image/image.dart' as img;

class NavigationPage extends StatefulWidget {
  final LatLng startLocation;
  final LatLng endLocation;
  final String method;

  const NavigationPage({
    required this.startLocation,
    required this.endLocation,
    required this.method,
    super.key,
  });

  @override
  _NavigationPageState createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  GoogleMapController? _googleMapController;
  late RouteService _routeService;
  List<LatLng> _route = [];
  String _distance = '';
  String _duration = '';
  bool _isLoading = true;
  late Marker _userLocationMarker;
  late Marker _destinationMarker;
  late Polyline _polyline = Polyline(
    polylineId: PolylineId('default'),
    points: [],
    color: Colors.blue,
    width: 5,
  );
  bool _followUser = true;
  // ignore: unused_field
  bool _isUserInteracting = false;
  StreamSubscription<Position>? _locationSubscription;
  Position? _currentPosition;

  final LocationSettings locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
  );

  bool _showWebViewButton = false;

  @override
  void initState() {
    super.initState();
    _routeService = RouteService();
    _loadCustomMarker();
    _destinationMarker = Marker(
      markerId: MarkerId('destination'),
      position: widget.endLocation,
      icon: BitmapDescriptor.defaultMarker,
    );

    _locationSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position? position) {
        if (position != null) {
          _updateLocation(position);
        }
      },
    );

    _calculateRoute();
  }

  BitmapDescriptor customIcon = BitmapDescriptor.defaultMarker;

  Future<void> _loadCustomMarker() async {
    final ByteData byteData = await rootBundle.load('assets/user.png');
    final Uint8List originalBytes = byteData.buffer.asUint8List();

    final img.Image? originalImage = img.decodeImage(originalBytes);
    if (originalImage == null) {
      return;
    }

    final img.Image resizedImage = img.copyResize(
      originalImage,
      width: 120,
      height: 120,
    );

    final Uint8List resizedBytes =
        Uint8List.fromList(img.encodePng(resizedImage));

    setState(() {
      customIcon = BitmapDescriptor.fromBytes(resizedBytes);
      _userLocationMarker = Marker(
        markerId: MarkerId('start'),
        position: widget.startLocation,
        icon: customIcon,
      );
    });
  }

  // Update user location on map
  Future<void> _updateLocation(Position position) async {
    setState(() {
      _currentPosition = position;
      _userLocationMarker = Marker(
        markerId: MarkerId('userLocation'),
        position: LatLng(position.latitude, position.longitude),
        icon: customIcon,
      );
    });

    // Check if user has reached the destination
    double distanceToDestination = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      widget.endLocation.latitude,
      widget.endLocation.longitude,
    );

    if (distanceToDestination < 20.0) {
      setState(() {
        _isLoading = false;
        _showWebViewButton = true;
      });
    } else {
      await _calculateRoute();
    }
  }

  // Navigate to WebView page
  void _navigateToWebView() {
    _locationSubscription?.cancel();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewPage(
          url: 'https://app.mappedin.com/map/672a67c1d3b850000baa8ccf',
        ),
      ),
    );
  }

  // Calculate route from user location to destination
  Future<void> _calculateRoute() async {
    if (_currentPosition == null) return;

    String method;
    switch (widget.method.toLowerCase()) {
      case 'walking':
        method = 'foot-walking';
        break;
      case 'bicycle':
        method = 'cycling-regular';
        break;
      case 'bus':
        method = 'driving-hgv';
        break;
      default:
        method = 'driving-car';
    }

    try {
      final routeDetails = await _routeService.getRoute(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        widget.endLocation,
        method,
      );

      if (routeDetails['coordinates'] == null ||
          routeDetails['coordinates'].isEmpty) {
        throw Exception('No coordinates found in the route details.');
      }

      final distance = routeDetails['distance'] / 1000;
      final duration = routeDetails['duration'] / 60;

      setState(() {
        _route = List<LatLng>.from(routeDetails['coordinates']);
        _distance = '${distance.toStringAsFixed(2)} km';
        _duration = '${duration.toStringAsFixed(0)} mins';
        _polyline = Polyline(
          polylineId: PolylineId('route'),
          points: _route,
          color: Colors.blue,
          width: 5,
        );
        _isLoading = false;
      });

      if (_googleMapController != null) {
        _googleMapController!.moveCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            18.0,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to load route. Please try again later.')),
      );
    }
  }

  // Toggle follow user camera behavior
  void _toggleFollowUser() {
    setState(() {
      _followUser = !_followUser;
    });

    if (_followUser &&
        _currentPosition != null &&
        _googleMapController != null) {
      _googleMapController!.moveCamera(
        CameraUpdate.newLatLng(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude)),
      );
    }
  }

  // Detect if the user is interacting with the map
  void _onCameraMoveStarted() {
    setState(() {
      _isUserInteracting = true;
    });
  }

  // Detect when the user stops interacting with the map
  void _onCameraIdle() {
    setState(() {
      _isUserInteracting = false;
    });

    // Recenter camera if needed
    if (_followUser &&
        _currentPosition != null &&
        _googleMapController != null) {
      _googleMapController!.moveCamera(
        CameraUpdate.newLatLng(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude)),
      );
    }
  }

  IconData _getNavigationModeIcon() {
    switch (widget.method) {
      case 'walking':
        return Icons.directions_walk;
      case 'bicycle':
        return Icons.directions_bike;
      case 'bus':
        return Icons.directions_bus;
      default:
        return Icons.directions_car;
    }
  }

  @override
  void dispose() {
    super.dispose();
    _locationSubscription?.cancel();
  }

  Widget _buildBottomWidget() {
    return _showWebViewButton
        ? Positioned(
            bottom: 10,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: ElevatedButton(
                  onPressed: _navigateToWebView,
                  child: Text('Open'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
          )
        : Positioned(
            bottom: 10,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context, 'back');
                    },
                    icon: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 32,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          _duration,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const Divider(
                          color: Colors.black26,
                          height: 2,
                          indent: 80,
                          endIndent: 80,
                        ),
                        Text(
                          _distance,
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Icon(
                      _getNavigationModeIcon(),
                      size: 40,
                    ),
                  ),
                ],
              ),
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context, 'back');
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Navigation'),
        backgroundColor: Colors.greenAccent,
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: widget.startLocation,
                    zoom: 18.0,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    _googleMapController = controller;
                  },
                  onCameraMoveStarted: _onCameraMoveStarted,
                  onCameraIdle: _onCameraIdle,
                  markers: {
                    _userLocationMarker,
                    _destinationMarker,
                  },
                  polylines: {
                    _polyline,
                  },
                ),
                _buildBottomWidget(),
                _showWebViewButton == false
                    ? Positioned(
                        bottom: 115,
                        right: 20,
                        child: Container(
                          width: 130,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: TextButton(
                            onPressed: _toggleFollowUser,
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.navigation_outlined,
                                    size: 28, color: Colors.blue.shade700),
                                SizedBox(width: 5),
                                Text(
                                  'Recenter',
                                  style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.blue.shade800),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : Container(),
              ],
            ),
    );
  }
}
