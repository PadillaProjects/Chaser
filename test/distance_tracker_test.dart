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

/// Feed [readings] into a [tracker] and collect every write value returned.
List<double> simulate(DistanceTracker tracker, List<double> readings) {
  final writes = <double>[];
  for (final r in readings) {
    final w = tracker.tick(intervalMeters: r);
    if (w != null) writes.add(w);
  }
  return writes;
}

// ─── Threshold computation ────────────────────────────────────────────────────

void main() {
  group('Threshold computation', () {
    test('instant-capture game uses minimum noise gate (2 m)', () {
      final t = makeTracker(captureResistanceDistance: 0);
      expect(t.noiseGateMeters, equals(2.0));
    });

    test('noise gate capped at 5 m for large capture distances', () {
      final t = makeTracker(captureResistanceDistance: 500);
      // 500 / 10 = 50 → clamped to 5
      expect(t.noiseGateMeters, equals(5.0));
    });

    test('noise gate is 1/10th of capture distance when in range', () {
      final t = makeTracker(captureResistanceDistance: 30); // 30/10 = 3 m
      expect(t.noiseGateMeters, closeTo(3.0, 0.001));
    });

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

  // ─── Noise gate ─────────────────────────────────────────────────────────────

  group('Noise gate — sub-threshold readings are silently discarded', () {
    test('movement below gate returns null', () {
      // 7-day game so write threshold = 100 m — gate is our only blocker here.
      // gate = 2 m (instant capture). 1.9 m is below → null.
      final t = makeTracker(captureResistanceDistance: 0);
      expect(t.tick(intervalMeters: 1.9), isNull);
    });

    test('movement exactly at gate is accepted and accumulated', () {
      // Short game: threshold = 5 m, gate = 2 m.
      final t = makeTracker(
        captureResistanceDistance: 0,
        durationInMinutes: 5,
      );
      // 5 ticks of 1 m → below 2 m gate → discarded; total stays 0.
      for (var i = 0; i < 5; i++) {
        expect(t.tick(intervalMeters: 1.0), isNull);
      }
      expect(t.totalDistance, equals(0.0));

      // Tick of exactly 2 m (= gate) → accepted.
      // lastWrittenDistance starts at: baseOffset(0) - threshold(5) - 1 = -6
      // delta = 2 - (-6) = 8 >= 5 → WRITE fires immediately.
      final w = t.tick(intervalMeters: 2.0);
      expect(w, isNotNull);
      expect(w!, closeTo(2.0, 0.001));
    });

    test('discarded readings do NOT accumulate in total', () {
      final t = makeTracker(captureResistanceDistance: 0); // gate = 2 m
      for (var i = 0; i < 100; i++) {
        t.tick(intervalMeters: 1.5); // always below gate
      }
      expect(t.totalDistance, equals(0.0));
    });
  });

  // ─── Write threshold ─────────────────────────────────────────────────────────

  group('Write threshold — writes fire at correct cumulative distances', () {
    // NOTE: The tracker initialises lastWrittenDistance = baseOffset - threshold - 1.
    // For baseOffset=0, threshold=5: lastWritten = -6.
    // This means the FIRST tick that passes the gate immediately triggers a write
    // if it reaches the threshold (delta measured from -6, not 0).

    test('first write fires on first tick that meets gate (delta from -6)', () {
      // threshold = 5 m, gate = 2 m
      final t = makeTracker(durationInMinutes: 10);

      // 4 m tick: passes gate, total=4, delta = 4 - (-6) = 10 >= 5 → WRITE
      final w = t.tick(intervalMeters: 4.0);
      expect(w, isNotNull);
      expect(w!, closeTo(4.0, 0.001));
    });

    test('no write when movement passes gate but not write threshold after prior write', () {
      // threshold = 5 m, gate = 2 m
      final t = makeTracker(durationInMinutes: 10);

      // First write at 4 m (delta from -6 → 10 >= 5).
      t.tick(intervalMeters: 4.0);
      final lastWritten = t.lastWrittenDistance; // 4 m

      // 3 m tick: passes gate, total=7, delta = 7 - 4 = 3 < 5 → NO write
      final w = t.tick(intervalMeters: 3.0);
      expect(w, isNull);
      expect(t.lastWrittenDistance, equals(lastWritten)); // unchanged
    });

    test('second write fires once delta from last write reaches threshold', () {
      // threshold = 5 m, gate = 2 m
      final t = makeTracker(durationInMinutes: 10);

      t.tick(intervalMeters: 4.0); // first write at 4 m
      t.tick(intervalMeters: 3.0); // 7 m total, delta=3 → no write

      // Another 3 m: total=10, delta = 10 - 4 = 6 >= 5 → WRITE
      final w = t.tick(intervalMeters: 3.0);
      expect(w, isNotNull);
      expect(w!, closeTo(10.0, 0.001));
    });

    test('writes fire repeatedly as player keeps moving', () {
      // Each tick of 6 m passes gate (2 m) and threshold (5 m) every time.
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
      // 10 m ticks above 5 m gate.
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
      // 3 m ticks (above 2 m gate). First write fires on first tick.
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
      expect(w, isNotNull);
      expect(w!, closeTo(106.0, 0.001));
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
      expect(t.noiseGateMeters, equals(5.0));   // 50/10 = 5 (cap hit)
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
      expect(t.noiseGateMeters, equals(5.0));        // 200/10=20→clamped
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

    test('Mixed movement: below-gate ticks never leak into total', () {
      // gate = 5 m (capture zone 50 m), threshold = 5 m (30-min game)
      final t = makeTracker(
        captureResistanceDistance: 50,
        durationInMinutes: 30,
      );
      // Alternate: 4 m (below 5 m gate) and 6 m (above gate).
      for (var i = 0; i < 10; i++) {
        t.tick(intervalMeters: 4.0); // discarded
        t.tick(intervalMeters: 6.0); // counted
      }
      // Only 6 m ticks count: 10 × 6 = 60 m total.
      expect(t.totalDistance, closeTo(60.0, 0.001));
    });
  });
}
