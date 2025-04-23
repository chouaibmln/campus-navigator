import 'custom_locations.dart';

class SearchService {
  Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    List<CustomLocation> localResults =
        LocationRepository.searchLocations(query);

    if (localResults.isNotEmpty) {
      return localResults.map((location) {
        return {
          'name': location.name,
          'lat': location.coordinates.latitude,
          'lon': location.coordinates.longitude,
        };
      }).toList();
    }
    throw Exception('Failed to search places');
  }
}
