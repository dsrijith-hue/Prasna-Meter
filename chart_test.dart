import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashna_success_meter/analysis.dart';
import 'package:prashna_success_meter/chart.dart';
import 'package:prashna_success_meter/scoring_engine.dart';

const planets = '''AS Cpcn 22:33:24
SU Lib 20:44:49
MO Vir 27:42:14
MA Cnc 27:35:04
ME Lib 14:41:06 R C
JU Leo 00:53:51
VE Vir 29:38:23 R
SA Pis 14:46:07 R
RA Aqu 01:35:44 R
KE Leo 01:35:44 R''';

void main() {
  test('parses sample chart with flags and ignores unknown lines', () {
    final pc = parseChart('$planets\nUR Tau 10:17:41 R', '');
    expect(pc.planets.length, 9);
    expect(pc.planets['ME']!.combust, true);
    expect(pc.planets['ME']!.retro, true);
    expect(pc.equalHouse, true);
  });

  test('equal-house placement', () {
    final chart = KpChart(parseChart(planets, ''));
    expect(chart.houseOf(chart.pc.ascLon), 1);
    expect(chart.houseOf(chart.planets['SU']!.lon), 9);
    expect(chart.significators('MO').contains(9), true);
  });

  test('missing planet is reported', () {
    expect(() => parseChart('AS Cap 10:00:00', ''), throwsFormatException);
  });

  test('analysis score stays within 0..100', () {
    final cfg = jsonDecode(File('assets/player_performance_config.json').readAsStringSync())
        as Map<String, dynamic>;
    final a = analyse(
      engine: ScoringEngine(cfg),
      mode: Mode.batting,
      role: 'opener',
      planetText: planets,
      cuspText: '',
      chartTime: DateTime.utc(2026, 11, 14, 17),
      evalTime: DateTime.utc(2026, 11, 14, 17),
      moonVoid: false,
    );
    expect(a.result.score, inInclusiveRange(0, 100));
  });

  test('role planet strength is not zero (config uses planet codes)', () {
    final cfg = jsonDecode(File('assets/player_performance_config.json').readAsStringSync())
        as Map<String, dynamic>;
    final engine = ScoringEngine(cfg);
    final s = engine.rolePlanetStrengthFor('opener', {'MA': 1.0, 'SA': 0.7});
    expect(s, closeTo(0.85, 0.001));
  });
}
