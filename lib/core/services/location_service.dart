import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Requests location permission. Returns true if granted or limited, false if denied.
  Future<bool> requestPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false; // Location services are not enabled
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false; // Permissions are denied
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        return false; // Permissions are denied forever
      }

      return true;
    } catch (e) {
      // Si faltan permisos en el manifest, o hay error nativo, devolvemos false para no romper flujos
      return false;
    }
  }

  /// Gets the current location if permissions are granted.
  /// If [requestIfNotGranted] is true, it will attempt to request permission.
  Future<Position?> getCurrentLocation({bool requestIfNotGranted = true}) async {
    if (requestIfNotGranted) {
      final hasPermission = await requestPermission();
      if (!hasPermission) return null;
    } else {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }
    }

    try {
      // Fast path: try to get the last known position first (great for emulators and bad signal)
      Position? pos = await Geolocator.getLastKnownPosition();
      
      // If we don't have it, or want fresh data
      pos ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 4), // Wait at most 4 seconds so UI is snappy
        )
      );
      
      return pos;
    } catch (e) {
      // In case of timeout or any error getting the current location, fallback again
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }
}
