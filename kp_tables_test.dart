import 'package:flutter_test/flutter_test.dart';
import 'package:prashna_success_meter/kp_tables.dart';
import 'package:prashna_success_meter/vimshottari.dart';

void main() {
  // name, sign index, deg, min, sec, RL, NL, SL, SSL  (from the KP app screenshot)
  final rows = <List<dynamic>>[
    ['Asc', 9, 22, 33, 24.0, 'SA', 'MO', 'VE', 'KE'],
    ['Sun', 6, 20, 44, 49.0, 'VE', 'JU', 'JU', 'ME'],
    ['Moon', 5, 27, 42, 14.0, 'ME', 'MA', 'JU', 'RA'],
    ['Mars', 3, 27, 35, 4.0, 'MO', 'ME', 'JU', 'MA'],
    ['Mercury', 6, 14, 41, 6.0, 'VE', 'RA', 'KE', 'MO'],
    ['Jupiter', 4, 0, 53, 51.0, 'SU', 'KE', 'VE', 'VE'],
    ['Venus', 5, 29, 38, 23.0, 'ME', 'MA', 'SA', 'RA'],
    ['Saturn', 11, 14, 46, 7.0, 'JU', 'SA', 'RA', 'MO'],
    ['Rahu', 10, 1, 35, 44.0, 'SA', 'MA', 'ME', 'SA'],
    ['Ketu', 4, 1, 35, 44.0, 'SU', 'KE', 'VE', 'RA'],
    ['Uranus', 1, 10, 17, 41.0, 'VE', 'MO', 'MO', 'RA'],
    ['Neptune', 11, 7, 48, 55.0, 'JU', 'SA', 'KE', 'JU'],
    ['Pluto', 9, 9, 2, 28.0, 'SA', 'SU', 'VE', 'JU'],
  ];

  for (final r in rows) {
    test('${r[0]} lords match KP app', () {
      final lon = longitudeFromDms(r[1] as int, r[2] as int, r[3] as int, r[4] as double);
      final k = kpLordsFor(lon);
      expect([k.signLord, k.nl, k.sl, k.ssl], [r[5], r[6], r[7], r[8]]);
    });
  }

  test('Moon dasha balance (Mars) is about 4.7 years', () {
    final moon = longitudeFromDms(5, 27, 42, 14);
    final v = Vimshottari(DateTime.utc(2000, 1, 1), moon);
    expect(v.firstLord, 'MA');
    expect(v.balanceYears, closeTo(4.705, 0.01));
  });

  test('sub periods tile the parent exactly', () {
    final v = Vimshottari(DateTime.utc(2000, 1, 1), 177.7039);
    final maha = v.mahaDashas().first;
    final subs = v.subPeriods(maha);
    expect(subs.first.lord, maha.lord);
    expect(subs.first.start, maha.start);
    expect(subs.last.end, maha.end);
  });

  test('at() returns the period containing the date', () {
    final v = Vimshottari(DateTime.utc(2000, 1, 1), 177.7039);
    final s = v.at(DateTime.utc(2010, 6, 1));
    expect(s.maha.start.isBefore(DateTime.utc(2010, 6, 2)), true);
    expect(s.maha.end.isAfter(DateTime.utc(2010, 6, 1)), true);
    expect(s.antar.start.isBefore(s.pratyantar.end), true);
  });
}
