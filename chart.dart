import 'kp_tables.dart';

const List<String> planetCodes = ['SU', 'MO', 'MA', 'ME', 'JU', 'VE', 'SA', 'RA', 'KE'];
const List<String> signAbbr = [
  'Ari', 'Tau', 'Gem', 'Cnc', 'Leo', 'Vir', 'Lib', 'Sco', 'Sag', 'Cap', 'Aqu', 'Pis',
];
const Map<String, int> _signAlias = {
  'ari': 0, 'tau': 1, 'gem': 2, 'cnc': 3, 'can': 3, 'leo': 4, 'vir': 5,
  'lib': 6, 'sco': 7, 'sag': 8, 'cap': 9, 'cpc': 9, 'aqu': 10, 'pis': 11,
};

class PlanetPos {
  final String code;
  final double lon;
  final bool retro;
  final bool combust;
  const PlanetPos(this.code, this.lon, {this.retro = false, this.combust = false});
  KpLords get lords => kpLordsFor(lon);
}

String fmtLon(double lon) {
  final l = normalizeLongitude(lon);
  final sign = (l / 30).floor().clamp(0, 11).toInt();
  final within = l - sign * 30;
  final d = within.floor();
  final m = ((within - d) * 60).floor();
  return "${signAbbr[sign]} $d\u00B0${m.toString().padLeft(2, '0')}'";
}

double _parseLon(String sign, String dms) {
  final key = sign.toLowerCase();
  final idx = _signAlias[key.length < 3 ? key : key.substring(0, 3)];
  if (idx == null) throw FormatException('Unknown sign "$sign"');
  final parts = dms.split(':');
  final d = int.tryParse(parts[0]);
  final m = parts.length > 1 ? int.tryParse(parts[1]) : 0;
  final s = parts.length > 2 ? double.tryParse(parts[2]) : 0.0;
  if (d == null || m == null || s == null) throw FormatException('Bad degrees "$dms"');
  return longitudeFromDms(idx, d, m, s);
}

class ParsedChart {
  final double ascLon;
  final Map<String, PlanetPos> planets;
  final List<double> cusps; // 12 sidereal cusp longitudes
  final bool equalHouse; // true when cusps were not supplied
  const ParsedChart(this.ascLon, this.planets, this.cusps, this.equalHouse);
}

/// planetText lines: "SU Lib 20:44:49" plus optional flags "R" and/or "C".
/// Line "AS Cpcn 22:33:24" is the ascendant. Unknown codes (UR, NE, PL...) are ignored.
/// cuspText: 12 lines "Sign DD:MM:SS" for cusps 1..12, or empty for equal houses.
ParsedChart parseChart(String planetText, String cuspText) {
  double? asc;
  final planets = <String, PlanetPos>{};
  for (final raw in planetText.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final t = line.split(RegExp(r'\s+'));
    if (t.length < 3) {
      throw FormatException('Line needs "PLANET Sign DD:MM:SS": $line');
    }
    final code = t[0].toUpperCase();
    final isAsc = code == 'AS' || code == 'ASC';
    if (!isAsc && !planetCodes.contains(code)) continue;
    final lon = _parseLon(t[1], t[2]);
    final flags = t
        .skip(3)
        .map((x) => x.toUpperCase().replaceAll(RegExp(r'[()/,]'), ''))
        .join();
    if (isAsc) {
      asc = lon;
    } else {
      planets[code] = PlanetPos(code, lon,
          retro: flags.contains('R'), combust: flags.contains('C'));
    }
  }
  final a = asc;
  if (a == null) throw const FormatException('Ascendant line (AS ...) is missing');
  final missing = planetCodes.where((c) => !planets.containsKey(c)).toList();
  if (missing.isNotEmpty) {
    throw FormatException('Missing planets: ${missing.join(', ')}');
  }

  final lines =
      cuspText.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  final List<double> cusps;
  var equal = false;
  if (lines.isEmpty) {
    equal = true;
    cusps = List<double>.generate(12, (i) => normalizeLongitude(a + 30.0 * i));
  } else {
    if (lines.length != 12) {
      throw FormatException('Need 12 cusp lines, found ${lines.length}');
    }
    cusps = lines.map((l) {
      final t = l.split(RegExp(r'\s+'));
      if (t.length < 2) throw FormatException('Bad cusp line: $l');
      return _parseLon(t[t.length - 2], t[t.length - 1]);
    }).toList();
  }
  return ParsedChart(a, planets, cusps, equal);
}

class KpChart {
  final ParsedChart pc;
  const KpChart(this.pc);

  Map<String, PlanetPos> get planets => pc.planets;

  int houseOf(double lon) {
    final l = normalizeLongitude(lon);
    for (var h = 0; h < 12; h++) {
      final s = pc.cusps[h];
      final e = pc.cusps[(h + 1) % 12];
      final inside = s <= e ? (l >= s && l < e) : (l >= s || l < e);
      if (inside) return h + 1;
    }
    return 1;
  }

  List<int> housesOwned(String planet) => [
        for (var h = 0; h < 12; h++)
          if (signLords[(pc.cusps[h] / 30).floor().clamp(0, 11).toInt()] == planet)
            h + 1,
      ];

  /// KP significators of a planet: house of its star lord, its own house,
  /// houses owned by its star lord, houses it owns. Rahu/Ketu also take the
  /// houses owned by their sign lord.
  Set<int> significators(String code) {
    final p = planets[code]!;
    final nl = p.lords.nl;
    final s = <int>{};
    final nlPos = planets[nl];
    if (nlPos != null) s.add(houseOf(nlPos.lon));
    s.add(houseOf(p.lon));
    s.addAll(housesOwned(nl));
    s.addAll(housesOwned(code));
    if (code == 'RA' || code == 'KE') s.addAll(housesOwned(p.lords.signLord));
    return s;
  }

  /// 1.0 = unafflicted, lowered for retrograde (not nodes) and combust.
  double strength(String code) {
    final p = planets[code]!;
    var s = 1.0;
    if (p.retro && code != 'RA' && code != 'KE') s -= 0.3;
    if (p.combust) s -= 0.4;
    return s.clamp(0.0, 1.0).toDouble();
  }
}
