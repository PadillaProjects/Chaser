import 'package:cm_pedometer/cm_pedometer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PedometerService {
  static const MethodChannel _channel = MethodChannel('cm_pedometer');

  Future<bool> requestPermissions() async {
    try {
      final now = DateTime.now();
      // Query for a small recent window to trigger permission prompt
      await getDistance(now.subtract(const Duration(minutes: 1)), now);
      return true;
    } catch (e) {
      debugPrint("Pedometer permissions/query error: $e");
      return false; 
    }
  }

  /// Fetch distance for a given time range
  Future<double> getDistance(DateTime start, DateTime end) async {
    try {
      // WORKAROUND: cm_pedometer 1.2.0 Dart code sends 'from'/'to' but iOS code expects 'startTime'/'endTime'
      // calling invokeMethod directly with correct keys.
      final Map<dynamic, dynamic>? data = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'queryPedometerData', 
        {
          'startTime': start.millisecondsSinceEpoch,
          'endTime': end.millisecondsSinceEpoch,
        }
      );
      
      if (data != null) {
          final distance = data['distance'];
          if (distance != null && distance is num) {
              return distance.toDouble();
          }
      }
      return 0.0;
    } catch (e) {
      debugPrint("Error fetching pedometer distance: $e");
      return 0.0;
    }
  }

  /// Get a stream of pedometer data starting from [start]
  Stream<dynamic> getPedometerStream(DateTime start) {
      // Returns dynamic stream to avoid type resolution issues
      // Stream keys seem to be correct in package, so using regular method
      return CMPedometer.stepCounterFirstStream(from: start);
  }
}
