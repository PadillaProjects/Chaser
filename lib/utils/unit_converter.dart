/// Utility for converting between display units and canonical DB units.
///
/// Database stores:
///   - Distance fields in **meters** (double)
///   - Duration fields in **minutes** (int)
///
/// The *Unit string (e.g. 'm', 'km', 'mi', 'min', 'hours', 'days') is stored
/// alongside the canonical value so the UI can display it back to the user in
/// the original unit.
class UnitConverter {
  // ---------------------------------------------------------------------------
  // Distance
  // ---------------------------------------------------------------------------

  /// Converts [value] expressed in [unit] to meters.
  static double toMeters(double value, String unit) {
    switch (unit) {
      case 'km':
        return value * 1000;
      case 'mi':
        return value * 1609.344;
      case 'm':
      default:
        return value;
    }
  }

  /// Converts [meters] to the given [unit].
  static double fromMeters(double meters, String unit) {
    switch (unit) {
      case 'km':
        return meters / 1000;
      case 'mi':
        return meters / 1609.344;
      case 'm':
      default:
        return meters;
    }
  }

  // ---------------------------------------------------------------------------
  // Duration
  // ---------------------------------------------------------------------------

  /// Converts [value] expressed in [unit] to minutes.
  static int toMinutes(num value, String unit) {
    switch (unit) {
      case 'hours':
        return (value * 60).round();
      case 'days':
        return (value * 60 * 24).round();
      case 'min':
      default:
        return value.round();
    }
  }

  /// Converts [minutes] to the given [unit].
  ///
  /// Returns a [double] so callers can decide how to round/display.
  static double fromMinutes(int minutes, String unit) {
    switch (unit) {
      case 'hours':
        return minutes / 60;
      case 'days':
        return minutes / (60 * 24);
      case 'min':
      default:
        return minutes.toDouble();
    }
  }

  // ---------------------------------------------------------------------------
  // Formatting helpers
  // ---------------------------------------------------------------------------

  /// Formats a meter value for display in the given unit.
  /// Strips trailing zeros to avoid "1.00 km" → shows "1 km" instead.
  static String formatDistance(double meters, String unit) {
    final converted = fromMeters(meters, unit);
    // Show up to 2 decimal places, strip trailing zeros
    final formatted = converted.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
    return '$formatted $unit';
  }

  /// Formats a minute value for display in the given unit.
  static String formatDuration(int minutes, String unit) {
    final converted = fromMinutes(minutes, unit);
    final formatted = converted.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
    return '$formatted $unit';
  }
}
