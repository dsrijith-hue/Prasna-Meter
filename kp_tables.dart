/// KP star lord / sub lord / sub-sub lord calculator.
/// No lookup table needed: the 249 subs are derived from Vimshottari
/// proportions. Longitude must be sidereal (apply KP ayanamsa first).
const List<String> kpOrder = ['KE', 'VE', 'SU', 'MO', 'MA', 'RA', 'JU', 'SA', 'ME'];
const Map<String, int> kpYears = {
  'KE': 7, 'VE': 20, 'SU': 6, 'MO': 10, 'MA': 7,
  'RA': 18, 'JU': 16, 'SA': 19, 'ME': 17,
};
const double nakSpan = 360 / 27; // 13 deg 20 min

const List<String> signNames = [
  'Aries', 'Taurus', 'Gemini', 'Cancer', 'Leo', 'Virgo',
  'Libra', 'Scorpio', 'Sagittarius', 'Capricorn', 'Aquarius', 'Pisces',
];
const List<String> signLords = [
  'MA', 'VE', 'ME', 'MO', 'SU', 'ME', 'VE', 'MA', 'JU', 'SA', 'SA', 'JU',
];

class KpLords {
  final String signLord; // RL
  final String nl; // star lord
  final String sl; // sub lord
  final String ssl; // sub-sub lord
  const KpLords(this.signLord, this.nl, this.sl, this.ssl);
  @override
  String toString() => 'RL=$signLord NL=$nl SL=$sl SSL=$ssl';
}

class _Part {
  final String lord;
  final double offset;
  final double span;
  const _Part(this.lord, this.offset, this.span);
}

_Part _split(String start, double span, double off) {
  final k = kpOrder.indexOf(start);
  for (var j = 0; j < 9; j++) {
    final l = kpOrder[(k + j) % 9];
    final s = span * kpYears[l]! / 120;
    if (off < s || j == 8) return _Part(l, off, s);
    off -= s;
  }
  throw StateError('unreachable');
}

double normalizeLongitude(double lon) => ((lon % 360) + 360) % 360;

/// Longitude from sign index (0 = Aries ... 11 = Pisces) and deg/min/sec.
double longitudeFromDms(int signIndex, int deg, int min, double sec) =>
    signIndex * 30 + deg + min / 60 + sec / 3600;

KpLords kpLordsFor(double longitude) {
  final lon = normalizeLongitude(longitude);
  final signLord = signLords[(lon / 30).floor().clamp(0, 11).toInt()];
  final i = (lon / nakSpan).floor().clamp(0, 26).toInt();
  final nl = kpOrder[i % 9];
  final off = lon - i * nakSpan;
  final sub = _split(nl, nakSpan, off);
  final subSub = _split(sub.lord, sub.span, sub.offset);
  return KpLords(signLord, nl, sub.lord, subSub.lord);
}
