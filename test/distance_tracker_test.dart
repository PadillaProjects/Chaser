import 'package:chaser/utils/distance_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Create a tracker using explicit game parameters.
DistanceTracker makeTracker({
  double captureResistanceDistance = 0,
  int captureResistanceDuration = 0,
  int durationInMinutes = 10080, // 7 days default
  double baseOffset = 0,
}) =>
    DistanceTracker(
      captureResistanceDistance: captureResistanceDistance,
      captureResistanceDuration: captureResistanceDuration,
      durationInMinutes: durationInMinutes,
      baseOffset: baseOffset,
    );

/// Feed [readings] into a [tracker] and collect every total distance value 
/// at the time an upload is triggered.
List<double> simulate(DistanceTracker tracker, List<double> readings) {
  final writes = <double>[];
  for (final r in readings) {
    final shouldWrite = tracker.tick(intervalMeters: r);
    if (shouldWrite) writes.add(tracker.totalDistance);
  }
  return writes;
}

// ─── Threshold computation ────────────────────────────────────────────────────

void main() {
  group('Threshold computation', () {
    test('write threshold never exceeds captureDistance / 4', () {
      // 7-day game (durationBound=100 m), capture zone 80 m
      // captureBound = 80/4 = 20 m → wins over 100 m
      final t = makeTracker(
        captureResistanceDistance: 80,
        durationInMinutes: 10080,
      );
      expect(t.writeThresholdMeters, closeTo(20.0, 0.001));
    });

    test('write threshold bounded by duration for short games', () {
      // 5-min game → durationBound = 5/100 = 0.05 → clamped to 5 m
      // capture zone 100 m → captureBound = 25 m
      // min(5 m, 25 m) = 5 m wins
      final t = makeTracker(
        captureResistanceDistance: 100,
        durationInMinutes: 5,
      );
      expect(t.writeThresholdMeters, closeTo(5.0, 0.001));
    });

    test('check interval scales with resistance duration', () {
      // 5-min resistance → 300 s / 8 = 37 s
      final t = makeTracker(captureResistanceDuration: 5);
      expect(t.checkIntervalSecs, equals(37));
    });

    test('check interval clamped to 10 s for instant capture', () {
      final t = makeTracker(captureResistanceDuration: 0);
      expect(t.checkIntervalSecs, equals(10));
    });

    test('check interval clamped to 60 s for very long resistance windows', () {
      // 10-min resistance → 600 / 8 = 75 s → clamped to 60 s
      final t = makeTracker(captureResistanceDuration: 10);
      expect(t.checkIntervalSecs, equals(60));
    });
  });

  // ─── Continuous Tracking (No Noise Gate) ────────────────────────────────────

  group('Continuous Tracking — all small movements are perfectly accumulated', () {
    test('small sub-meter steps are instantly added to total distance', () {
      final t = makeTracker(captureResistanceDistance: 0);
      
      expect(t.tick(intervalMeters: 0.5), isTrue); // First passes threshold delta
      expect(t.totalDistance, equals(0.5));
      
      expect(t.tick(intervalMeters: 0.5), isFalse); // Accumulated but no upload triggered
      expect(t.totalDistance, equals(1.0));
      
      expect(t.tick(intervalMeters: 0.1), isFalse); 
      expect(t.totalDistance, closeTo(1.1, 0.001));
    });
  });

  // ─── Write threshold ─────────────────────────────────────────────────────────

  group('Write threshold — writes fire at correct cumulative distances', () {
    // NOTE: The tracker initialises lastWrittenDistance = baseOffset - threshold - 1.
    // For baseOffset=0, threshold=5: lastWritten = -6.
    // This means the FIRST tick immediately triggers a write
    // if it reaches the threshold (delta measured from -6, not 0).

    test('first write fires on first tick (delta from -6)', () {
      // threshold = 5 m
      final t = makeTracker(durationInMinutes: 10);

      // 4 m tick: total=4, delta = 4 - (-6) = 10 >= 5 → WRITE
      final w = t.tick(intervalMeters: 4.0);
      expect(w, isTrue);
      expect(t.totalDistance, closeTo(4.0, 0.001));
    });

    test('no write when movement passes gate but not write threshold after prior write', () {
      // threshold = 5 m
      final t = makeTracker(durationInMinutes: 10);

      // First write at 4 m (delta from -6 → 10 >= 5).
      t.tick(intervalMeters: 4.0);
      final lastWritten = t.lastWrittenDistance; // 4 m

      // 3 m tick: total=7, delta = 7 - 4 = 3 < 5 → NO write
      final w = t.tick(intervalMeters: 3.0);
      expect(w, isFalse);
      expect(t.lastWrittenDistance, equals(lastWritten)); // unchanged
    });

    test('second write fires once delta from last write reaches threshold', () {
      // threshold = 5 m
      final t = makeTracker(durationInMinutes: 10);

      t.tick(intervalMeters: 4.0); // first write at 4 m
      t.tick(intervalMeters: 3.0); // 7 m total, delta=3 → no write

      // Another 3 m: total=10, delta = 10 - 4 = 6 >= 5 → WRITE
      final w = t.tick(intervalMeters: 3.0);
      expect(w, isTrue);
      expect(t.totalDistance, closeTo(10.0, 0.001));
    });

    test('writes fire repeatedly as player keeps moving', () {
      // threshold (5 m) 
      final t = makeTracker(durationInMinutes: 10);
      final writes = simulate(t, [6.0, 6.0, 6.0]);
      // All 3 ticks write because delta always >= 5 m after each write resets.
      expect(writes, hasLength(3));
      expect(writes, equals([6.0, 12.0, 18.0]));
    });
  });

  // ─── Capture-window safety ────────────────────────────────────────────────

  group('Capture-window safety', () {
    test('7-day game with 100 m capture zone: write threshold is 25 m', () {
      final t = makeTracker(
        captureResistanceDistance: 100,
        durationInMinutes: 10080,
      );
      // durationBound = 10080/100 = 100.8 → clamped to 100 m
      // captureBound  = 100/4 = 25 m → wins
      expect(t.writeThresholdMeters, closeTo(25.0, 0.001));
    });

    test('7-day game: writes happen at most every 25 m for 10 m ticks', () {
      final t = makeTracker(
        captureResistanceDistance: 100,
        durationInMinutes: 10080,
      );
      // 10 m ticks.
      // First write: delta from -26 = 36 >= 25 → write at 10 m (first tick).
      // Then delta resets. Next write fires when cumulative delta >= 25 m.
      // 10+10=20 < 25, 10+10+10=30 >= 25 → write at 40 m.
      final writes = simulate(t, List.filled(10, 10.0));

      // Every write value should be no more than 25+10=35 m from the previous.
      for (var i = 1; i < writes.length; i++) {
        expect(writes[i] - writes[i - 1], lessThanOrEqualTo(35.0));
      }
      expect(writes.isNotEmpty, isTrue);
    });

    test('instant-capture game always writes within 5 m (short game)', () {
      final t = makeTracker(
        captureResistanceDistance: 0, // instant
        durationInMinutes: 5, // threshold = 5 m
      );
      // 3 m ticks. First write fires on first tick.
      final writes = simulate(t, [3.0, 3.0, 3.0]);
      expect(writes.isNotEmpty, isTrue);
      expect(writes.first, lessThanOrEqualTo(5.0));
    });

    test('with baseOffset: total includes headstart distance', () {
      final t = makeTracker(
        captureResistanceDistance: 0,
        durationInMinutes: 5, // threshold = 5 m
        baseOffset: 100.0, // runner headstart
      );
      // lastWritten = 100 - 5 - 1 = 94. First tick of 6 m: total=106, delta=12 >= 5 → WRITE
      final w = t.tick(intervalMeters: 6.0);
      expect(w, isTrue);
      expect(t.totalDistance, closeTo(106.0, 0.001));
    });
  });

  // ─── Real-world scenario simulations ─────────────────────────────────────

  group('Real-world scenarios', () {
    test('Test game: 30-min, 50 m capture, 3-min resistance', () {
      final t = makeTracker(
        captureResistanceDistance: 50,
        captureResistanceDuration: 3,
        durationInMinutes: 30,
      );
      // durationBound = 30/100 = 0.3 → clamped to 5 m
      // captureBound  = 50/4  = 12.5 m
      // min = 5 m → duration wins
      expect(t.checkIntervalSecs, equals(22));  // 180/8 = 22 s
      expect(t.writeThresholdMeters, closeTo(5.0, 0.001));
    });

    test('Production game: 7-day, 200 m capture, 10-min resistance', () {
      final t = makeTracker(
        captureResistanceDistance: 200,
        captureResistanceDuration: 10,
        durationInMinutes: 10080,
      );
      // durationBound = 10080/100 → clamped to 100 m
      // captureBound  = 200/4 = 50 m → wins
      expect(t.checkIntervalSecs, equals(60));       // 600/8=75→clamped
      expect(t.writeThresholdMeters, closeTo(50.0, 0.001));
    });

    test('Walking pace: 1.4 m/s × 37s poll ≈ 52 m/tick → every tick writes', () {
      // 7-day game, 100 m capture: writeThreshold = 25 m
      final t = makeTracker(
        captureResistanceDistance: 100,
        durationInMinutes: 10080,
      );
      // 52 m/tick > 25 m threshold → every tick triggers a write.
      final writes = simulate(t, List.filled(20, 52.0));
      expect(writes, hasLength(20));
    });

    test('Stationary player: zero movement, zero writes', () {
      final t = makeTracker(durationInMinutes: 10);
      final writes = simulate(t, List.filled(50, 0.0));
      expect(writes, isEmpty);
      expect(t.totalDistance, equals(0.0));
    });
  });
}
