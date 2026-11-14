import 'chart.dart';
import 'kp_tables.dart';
import 'scoring_engine.dart';
import 'vimshottari.dart';

class Analysis {
  final KpChart chart;
  final ChartEvidence evidence;
  final ScoreResult result;
  final DashaSnapshot dasha;
  final List<String> ruling;
  const Analysis(this.chart, this.evidence, this.result, this.dasha, this.ruling);
}

Analysis analyse({
  required ScoringEngine engine,
  required Mode mode,
  required String role,
  required String planetText,
  required String cuspText,
  required DateTime chartTime,
  required DateTime evalTime,
  required bool moonVoid,
}) {
  final pc = parseChart(planetText, cuspText);
  final chart = KpChart(pc);
  final moon = pc.planets['MO']!;
  final dasha = Vimshottari(chartTime, moon.lon).at(evalTime);

  String cuspSl(int h) => kpLordsFor(pc.cusps[h - 1]).sl;
  final sl1 = cuspSl(1);
  final sl6 = cuspSl(6);
  final sl10 = cuspSl(10);
  final moonSl = moon.lords.sl;
  final dashaLords = [dasha.maha.lord, dasha.antar.lord, dasha.pratyantar.lord];

  final keyLords = <String>{sl10, sl6, ...dashaLords};
  var retro = 0;
  var combust = 0;
  for (final c in keyLords) {
    final p = pc.planets[c];
    if (p == null) continue;
    if (p.retro && c != 'RA' && c != 'KE') retro++;
    if (p.combust) combust++;
  }

  final strengths = <String, double>{
    for (final c in planetCodes) c: chart.strength(c),
  };
  final roleStrength = engine.rolePlanetStrengthFor(role, strengths);

  const dayLords = ['MO', 'MA', 'ME', 'JU', 'VE', 'SA', 'SU'];
  final dayLord = dayLords[chartTime.weekday - 1];
  int signIdx(double lon) => (normalizeLongitude(lon) / 30).floor().clamp(0, 11).toInt();
  final ascNl = kpLordsFor(pc.ascLon).nl;
  final ruling = <String>{
    dayLord,
    signLords[signIdx(moon.lon)],
    moon.lords.nl,
    signLords[signIdx(pc.ascLon)],
    ascNl,
  }.toList();
  final support = engine.supportHouses(mode);
  var matches = 0;
  for (final r in ruling) {
    if (chart.significators(r).any(support.contains)) matches++;
  }

  final evidence = ChartEvidence(
    cusp10SubLordHouses: chart.significators(sl10),
    cusp6SubLordHouses: chart.significators(sl6),
    ascMoonHouses: {...chart.significators(sl1), ...chart.significators(moonSl)},
    dashaLordHouses: [for (final l in dashaLords) chart.significators(l)],
    rolePlanetStrength: roleStrength,
    rulingMatches: matches,
    retrogradeCount: retro,
    combustCount: combust,
    moonVoid: moonVoid,
  );
  return Analysis(chart, evidence, engine.evaluate(mode, role, evidence), dasha, ruling);
}
