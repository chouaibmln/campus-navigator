import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'navigation_page.dart';
import 'search_service.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? _googleMapController;
  late LatLng _currentCenter;
  double _zoomLevel = 18.0;
  // Initialize with a default marker instead of using late
  Marker _userLocationMarker = Marker(
    markerId: const MarkerId('userLocation'),
    position: const LatLng(
        30.267604, 77.995080), // Using the initial center coordinates
    icon: BitmapDescriptor.defaultMarker,
  );

  LatLng? _selectedPosition;
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];

  bool _isSearching = false;
  bool _isLoading = false;
  final SearchService _searchService = SearchService();

  bool _buildRoute = false;
  String _selectedRouteMethod = 'Walking';

  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _currentCenter = const LatLng(30.267604, 77.995080); // Initial location
    _loadCustomMarker();
    _getUserLocation();
    _searchController.addListener(() {
      _searchPlaces(_searchController.text);
    });
  }

  // Custom icon for user location marker
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
        markerId: const MarkerId('userLocation'),
        position: _currentCenter,
        icon: customIcon,
      );
    });
  }

  // Get the user's current location
  Future<void> _getUserLocation() async {
    setState(() {
      _isLoading = true;
    });

    LocationPermission permission = await _checkPermissions();
    if (permission == LocationPermission.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location permission is denied.")),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    Position position = await Geolocator.getCurrentPosition();

    setState(() {
      _currentCenter = LatLng(position.latitude, position.longitude);
      _zoomLevel = 18.0;
      _userLocationMarker = Marker(
        markerId: MarkerId('userLocation'),
        position: _currentCenter,
        icon: customIcon,
      );
      _isLoading = false;
    });

    _googleMapController
        ?.moveCamera(CameraUpdate.newLatLngZoom(_currentCenter, _zoomLevel));
  }

  // Check location permissions
  Future<LocationPermission> _checkPermissions() async {
    PermissionStatus status = await Permission.location.request();
    if (status.isGranted) {
      return LocationPermission.whileInUse;
    } else if (status.isDenied) {
      return LocationPermission.denied;
    } else {
      return LocationPermission.deniedForever;
    }
  }

  // Search for places
  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }
    try {
      final results = await _searchService.searchPlaces(query);

      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error searching places")),
      );
    }
  }

  // Move map to selected location
  void _moveToLocation(double lat, double lon) {
    setState(() {
      _selectedPosition = LatLng(lat, lon);
      _searchResults = [];
      _isSearching = false;
      _searchController.clear();
    });
    _googleMapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_selectedPosition!, _zoomLevel));
  }

  // Build route buttons (Car, Walk, Bike, Bus)
  Widget _buildRouteButtons() {
    if (_selectedPosition == null) {
      return SizedBox.shrink();
    }
    _buildRoute = true;
    return Positioned(
      bottom: 20,
      left: 15,
      right: 15,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _routeMethodButton(Icons.directions_walk, 'Walking'),
                _routeMethodButton(Icons.directions_car, 'Car'),
                _routeMethodButton(Icons.directions_bike, 'Bicycle'),
                _routeMethodButton(Icons.directions_bus, 'Bus'),
              ],
            ),
            const SizedBox(height: 10),
            // "Get Directions" Button
            FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NavigationPage(
                      startLocation: _currentCenter,
                      endLocation: _selectedPosition!,
                      method: _selectedRouteMethod.toLowerCase(),
                    ),
                  ),
                );
                if (result == 'back') {
                  setState(() {
                    _selectedPosition = null;
                    _buildRoute = false;
                  });
                }
              },
              backgroundColor: Colors.blue,
              label: Row(
                children: const [
                  Icon(Icons.directions, color: Colors.white),
                  SizedBox(width: 5),
                  Text('Get Directions', style: TextStyle(color: Colors.white)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // Helper for route buttons
  Widget _routeMethodButton(IconData icon, String method) {
    final isSelected = _selectedRouteMethod == method;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRouteMethod = method;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? Colors.blue : Colors.black),
          const SizedBox(height: 4),
          Text(
            method,
            style: TextStyle(
              color: isSelected ? Colors.blue : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Campus Navigator')),
        backgroundColor: Colors.greenAccent,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              _googleMapController = controller;
            },
            initialCameraPosition: CameraPosition(
              target: _currentCenter,
              zoom: _zoomLevel,
            ),
            markers: {
              _userLocationMarker,
              if (_selectedPosition != null)
                Marker(
                  markerId: MarkerId('selectedLocation'),
                  position: _selectedPosition!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed),
                ),
            },
            polylines: _polylines,
            onCameraMove: (position) {
              setState(() {
                _zoomLevel = position.zoom;
              });
            },
          ),

          // Search bar
          Positioned(
            top: 20,
            left: 15,
            right: 15,
            child: Column(
              children: [
                SizedBox(
                    height: 55.0,
                    child: Container(
                      decoration: BoxDecoration(boxShadow: [
                        BoxShadow(
                          color: const Color.fromARGB(30, 0, 0, 0),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: Offset(0, 3),
                        ),
                      ]),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                            hintText: 'Search places',
                            filled: true,
                            fillColor: Colors.white,
                            border: const OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(5.0)),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _isSearching
                                ? IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _isSearching = false;
                                        _searchResults = [];
                                      });
                                    },
                                    icon: const Icon(Icons.clear))
                                : null),
                        onTap: () {
                          setState(() {
                            _isSearching = true;
                          });
                        },
                      ),
                    )),
                if (_isSearching && _searchResults.isNotEmpty)
                  Container(
                    color: Colors.white,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final place = _searchResults[index];
                        return ListTile(
                          title: Text(place['name']),
                          onTap: () {
                            _moveToLocation(
                              place['lat'],
                              place['lon'],
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
              ),
            ),

          _buildRouteButtons(),
        ],
      ),
      floatingActionButton: _buildRoute == false
          ? Stack(
              children: [
                Positioned(
                  bottom: 10,
                  left: 30,
                  child: FloatingActionButton(
                    onPressed: _getUserLocation,
                    backgroundColor: Colors.greenAccent,
                    child: const Icon(
                      Icons.my_location,
                      size: 28,
                    ),
                  ),
                ),
              ],
            )
          : null,
    );
  }
}
