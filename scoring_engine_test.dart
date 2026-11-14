import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashna_success_meter/scoring_engine.dart';

void main() {
  final cfg = jsonDecode(File('assets/player_performance_config.json').readAsStringSync())
      as Map<String, dynamic>;
  final engine = ScoringEngine(cfg);

  test('sample batter scores 70 (Par)', () {
    expect(engine.combine(26 + 10 + 10 + 14 + 8 + 6, -4), 70);
    expect(engine.bandFor(Mode.batting, 70)['label'], 'Par');
  });

  test('sample bowler scores 66 (2 wickets)', () {
    expect(engine.combine(24 + 10 + 9 + 15 + 9 + 5, -6), 66);
    expect(engine.bandFor(Mode.bowling, 66)['wickets'], 2);
  });

  test('evaluate stays within 0..100', () {
    final r = engine.evaluate(
      Mode.batting,
      'opener',
      const ChartEvidence(
        cusp10SubLordHouses: {3, 6, 10},
        cusp6SubLordHouses: {6, 11, 1},
        ascMoonHouses: {1, 10, 11},
        dashaLordHouses: [{3, 10}, {6, 11}, {1}],
        rolePlanetStrength: 1,
        rulingMatches: 5,
      ),
    );
    expect(r.score, inInclusiveRange(0, 100));
  });
}
