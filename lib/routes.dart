import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RouteService {
  // Method to get the route between two locations from OpenRouteService
  Future<Map<String, dynamic>> getRoute(
      LatLng from, LatLng to, String method) async {
    final String apiKey =
        'YOUR_OPENROUTESERVICE_API_KEY'; // Replace with your OpenRouteService API key

    final String url =
        'https://api.openrouteservice.org/v2/directions/$method?api_key=$apiKey&start=${from.longitude},${from.latitude}&end=${to.longitude},${to.latitude}';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        return {
          'coordinates':
              (data['features'][0]['geometry']['coordinates'] as List)
                  .map((c) => LatLng(c[1], c[0]))
                  .toList(),
          'distance': data['features'][0]['properties']['segments'][0]
              ['distance'],
          'duration': data['features'][0]['properties']['segments'][0]
              ['duration'],
        };
      } else {
        throw Exception('Failed to fetch route');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Method to generate a polyline for the route from a list of LatLng coordinates
  Polyline getPolyline(List<LatLng> route) {
    return Polyline(
      polylineId: PolylineId('route'),
      points: route,
      width: 5,
      color: Colors.blue,
      patterns: [PatternItem.dash(20.0), PatternItem.gap(10.0)],
    );
  }
}
