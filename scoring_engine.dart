import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

enum Mode { batting, bowling }

/// Chart-derived evidence. House sets are the houses signified by each lord
/// (via its star, own house lordship and position), taken from your KP engine
/// or entered manually.
class ChartEvidence {
  final Set<int> cusp10SubLordHouses;
  final Set<int> cusp6SubLordHouses;
  final Set<int> ascMoonHouses;
  final List<Set<int>> dashaLordHouses; // dasha, bhukti, antara
  final double rolePlanetStrength; // 0..1
  final int rulingMatches; // ruling planets matching significators
  final int retrogradeCount;
  final int combustCount;
  final bool moonVoid;

  const ChartEvidence({
    this.cusp10SubLordHouses = const {},
    this.cusp6SubLordHouses = const {},
    this.ascMoonHouses = const {},
    this.dashaLordHouses = const [],
    this.rolePlanetStrength = 0,
    this.rulingMatches = 0,
    this.retrogradeCount = 0,
    this.combustCount = 0,
    this.moonVoid = false,
  });
}

class ScoreResult {
  final int score;
  final String band;
  final int? wickets;
  final Map<String, double> components;
  final double penalty;
  final double fantasyLow;
  final double fantasyHigh;
  final List<String> reasons;

  const ScoreResult({
    required this.score,
    required this.band,
    required this.wickets,
    required this.components,
    required this.penalty,
    required this.fantasyLow,
    required this.fantasyHigh,
    required this.reasons,
  });
}

class ScoringEngine {
  final Map<String, dynamic> cfg;
  ScoringEngine(this.cfg);

  static Future<ScoringEngine> load() async {
    final raw =
        await rootBundle.loadString('assets/player_performance_config.json');
    return ScoringEngine(jsonDecode(raw) as Map<String, dynamic>);
  }

  String _key(Mode m) => m == Mode.batting ? 'batting' : 'bowling';
  double _num(dynamic v) => (v as num).toDouble();
  List<int> _ints(dynamic v) => ((v as List?) ?? const []).cast<int>();

  List<int> supportHouses(Mode m) {
    final h = cfg['houses'][_key(m)] as Map<String, dynamic>;
    return [..._ints(h['support']), ..._ints(h['optional_support'])];
  }

  /// Share of the ideal (3 supporting houses) that the lord signifies.
  double _ratio(Set<int> houses, List<int> support) {
    final hits = houses.where(support.contains).length;
    return (hits / 3).clamp(0.0, 1.0).toDouble();
  }

  int combine(num componentSum, num penalty) =>
      (componentSum + penalty).clamp(0, 100).round();

  Map<String, dynamic> bandFor(Mode mode, int score) {
    final bands = (cfg['bands'][_key(mode)] as List).cast<Map<String, dynamic>>();
    return bands.firstWhere(
      (b) => score >= (b['min'] as int) && score <= (b['max'] as int),
      orElse: () => bands.last,
    );
  }

  double rolePlanetStrengthFor(String role, Map<String, double> planetStrength) {
    final planets = ((cfg['role_bonus'][role] as List?) ?? const []).cast<String>();
    if (planets.isEmpty) return 0;
    final vals = planets.map((p) => planetStrength[p] ?? 0.0);
    return vals.reduce((a, b) => a + b) / planets.length;
  }

  ScoreResult evaluate(Mode mode, String role, ChartEvidence e) {
    final k = _key(mode);
    final w = cfg['weights'][k] as Map<String, dynamic>;
    final h = cfg['houses'][k] as Map<String, dynamic>;
    final support = [..._ints(h['support']), ..._ints(h['optional_support'])];
    final deny = _ints(h['deny']);

    final dashaRatios =
        e.dashaLordHouses.map((s) => _ratio(s, support)).toList();
    final dashaRatio = dashaRatios.isEmpty
        ? 0.0
        : dashaRatios.reduce((a, b) => a + b) / dashaRatios.length;

    final ratios = <String, double>{
      'cusp10_sub_lord': _ratio(e.cusp10SubLordHouses, support),
      'cusp6_sub_lord': _ratio(e.cusp6SubLordHouses, support),
      'asc_moon_links': _ratio(e.ascMoonHouses, support),
      'dasha_lords': dashaRatio,
      'role_planet_strength': e.rolePlanetStrength.clamp(0.0, 1.0).toDouble(),
      'ruling_planets': (e.rulingMatches / 3).clamp(0.0, 1.0).toDouble(),
    };
    final comps = <String, double>{
      for (final en in ratios.entries) en.key: _num(w[en.key]) * en.value,
    };
    final sum = comps.values.fold<double>(0, (a, b) => a + b);

    final p = cfg['penalties'] as Map<String, dynamic>;
    final denyHits = [e.cusp10SubLordHouses, e.cusp6SubLordHouses]
        .fold<int>(0, (a, s) => a + s.where(deny.contains).length);
    var pen = denyHits * _num(p['deny_house_link']) +
        e.retrogradeCount * _num(p['significator_retrograde']) +
        e.combustCount * _num(p['significator_combust']) +
        (e.moonVoid ? _num(p['moon_void_of_course']) : 0);
    final cap = _num(p['max_total_penalty']);
    if (pen < cap) pen = cap;

    final score = combine(sum, pen);
    final band = bandFor(mode, score);

    final base = _num(cfg['fantasy_points']['base_by_role'][role] ?? 35);
    final mid = base * score / 50;

    final reasons = <String>[
      for (final en in comps.entries)
        '${en.key}: ${en.value.toStringAsFixed(1)} / ${_num(w[en.key]).toStringAsFixed(0)}',
      'penalty: ${pen.toStringAsFixed(1)}',
    ];

    return ScoreResult(
      score: score,
      band: band['label'] as String,
      wickets: mode == Mode.bowling ? band['wickets'] as int? : null,
      components: comps,
      penalty: pen,
      fantasyLow: mid * 0.8,
      fantasyHigh: mid * 1.2,
      reasons: reasons,
    );
  }
}
