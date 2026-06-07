import 'package:geolocator/geolocator.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

class LocationService {
  const LocationService._();

  /// Requests permission and gets current device coordinates.
  /// Returns a record of (latitude, longitude) if successful, or throws an exception if failed/denied.
  static Future<(double, double)?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const LocationServiceDisabledException();
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Quyền truy cập vị trí bị từ chối.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Quyền truy cập vị trí bị từ chối vĩnh viễn. Vui lòng bật trong cài đặt thiết bị.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      safePrint('📍 Device coordinates fetched: ${position.latitude}, ${position.longitude}');
      return (position.latitude, position.longitude);
    } catch (e) {
      safePrint('❌ Error fetching geolocator location: $e');
      rethrow;
    }
  }
}
