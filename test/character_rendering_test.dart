import 'package:flutter_test/flutter_test.dart';
import 'package:chaser/character/layout/character_layout.dart';
import 'package:chaser/models/character/character_profile.dart';
import 'dart:ui';

void main() {
  group('Character Layout Logic', () {
    test('scaleFor calculates correct scale', () {
      // DESIGN_SIZE is 512.0
      expect(scaleFor(const Size(512, 512)), 1.0);
      expect(scaleFor(const Size(256, 256)), 0.5);
      expect(scaleFor(const Size(1024, 1024)), 2.0);
      
      // Should use min dimension
      expect(scaleFor(const Size(256, 512)), 0.5); 
    });

    test('characterLayout contains all parts', () {
      for (var part in CharacterPart.values) {
        expect(characterLayout.containsKey(part), true, reason: 'Missing layout for $part');
      }
    });

    test('All asset paths are valid strings', () {
      final profile = CharacterProfile.runnerBlue();
      
      // All parts should default to 'default' skin
      expect(profile.partSkins[CharacterPart.head], 'default');
      
      for (var part in CharacterPart.values) {
        final asset = profile.assetFor(part);
        expect(asset, startsWith('assets/characters/default/'));
        expect(asset, endsWith('.png'));
      }
    });

    test('PartLayout pivots are normalized (0-1)', () {
      characterLayout.forEach((part, layout) {
        expect(layout.pivot.dx, greaterThanOrEqualTo(0.0));
        expect(layout.pivot.dx, lessThanOrEqualTo(1.0));
        expect(layout.pivot.dy, greaterThanOrEqualTo(0.0));
        expect(layout.pivot.dy, lessThanOrEqualTo(1.0));
      });
    });
  });
}
