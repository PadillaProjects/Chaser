/// Pure-Dart distance accumulation logic, extracted from [_DistanceMonitorState]
/// so it can be unit-tested without Flutter or Firebase.
///
/// Usage:
///   final tracker = DistanceTracker(
///     captureResistanceDistance: 100,
///     captureResistanceDuration: 5,
///     durationInMinutes: 10080,
///     baseOffset: 0,
///   );
///
///   // Feed one pedometer interval reading at a time.
///   // Returns the cumulative distance to write, or null if no write needed.
///   final write = tracker.tick(intervalMeters: 30.0);
class DistanceTracker {
  DistanceTracker({
    required this.captureResistanceDistance,
    required this.captureResistanceDuration,
    required this.durationInMinutes,
    this.baseOffset = 0.0,
  }) {
    _totalDistance = baseOffset;
    // Ensure first meaningful write fires immediately.
    _lastWrittenDistance = baseOffset - writeThresholdMeters - 1;
  }

  final double captureResistanceDistance; // metres
  final int captureResistanceDuration;    // minutes
  final int durationInMinutes;
  final double baseOffset;

  double _totalDistance = 0.0;
  double _lastWrittenDistance = 0.0;

  // ── Computed thresholds ──────────────────────────────────────────────────

  /// How often (seconds) the pedometer should be polled.
  /// Expose so tests can assert the correct interval was chosen.
  int get checkIntervalSecs {
    final resistanceSecs = captureResistanceDuration * 60;
    if (resistanceSecs <= 0) return 10;
    return (resistanceSecs / 8).clamp(10, 60).toInt();
  }

  /// Minimum metres in one poll window to qualify as real movement.
  double get noiseGateMeters {
    const absoluteMax = 5.0;
    const absoluteMin = 2.0;
    if (captureResistanceDistance <= 0) return absoluteMin;
    return (captureResistanceDistance / 10.0).clamp(absoluteMin, absoluteMax);
  }

  /// Minimum cumulative delta before a Firestore write is issued.
  double get writeThresholdMeters {
    final durationBound =
        (durationInMinutes / 100.0).clamp(5.0, 100.0);
    if (captureResistanceDistance <= 0) return durationBound;
    final captureBound = captureResistanceDistance / 4.0;
    return durationBound < captureBound ? durationBound : captureBound;
  }

  // ── Accessors ────────────────────────────────────────────────────────────

  /// Running total of verified distance (metres).
  double get totalDistance => _totalDistance;

  /// Most recently written distance (metres). -∞ before any write.
  double get lastWrittenDistance => _lastWrittenDistance;

  // ── Core logic ───────────────────────────────────────────────────────────

  /// Process one pedometer window reading.
  ///
  /// [intervalMeters] is the raw distance from the pedometer for the window
  /// since the last tick. The window is always reset by the caller — this
  /// method only cares about the magnitude.
  ///
  /// Returns the total distance to commit to Firestore if a write should
  /// fire, or `null` if no write is needed this tick.
  double? tick({required double intervalMeters}) {
    // ── Noise gate ──────────────────────────────────────────────────────────
    if (intervalMeters < noiseGateMeters) return null;

    // ── Accumulate ──────────────────────────────────────────────────────────
    _totalDistance += intervalMeters;

    // ── Write threshold ─────────────────────────────────────────────────────
    final delta = (_totalDistance - _lastWrittenDistance).abs();
    if (delta >= writeThresholdMeters) {
      _lastWrittenDistance = _totalDistance;
      return _totalDistance;
    }
    return null;
  }

  /// Reset to a fresh state (useful between test scenarios).
  void reset({double? newBaseOffset}) {
    final base = newBaseOffset ?? baseOffset;
    _totalDistance = base;
    _lastWrittenDistance = base - writeThresholdMeters - 1;
  }
}
