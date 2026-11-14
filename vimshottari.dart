import 'kp_tables.dart';

const double _yearDays = 365.25;

DateTime _addYears(DateTime d, double years) =>
    d.add(Duration(microseconds: (years * _yearDays * 86400 * 1e6).round()));

class DashaPeriod {
  final String lord;
  final DateTime start;
  final DateTime end;
  const DashaPeriod(this.lord, this.start, this.end);
}

class DashaSnapshot {
  final DashaPeriod maha;
  final DashaPeriod antar;
  final DashaPeriod pratyantar;
  const DashaSnapshot(this.maha, this.antar, this.pratyantar);
}

/// Vimshottari dasha from the Moon's sidereal longitude at birth (or at the
/// question time for a Prashna). Year length = 365.25 days.
class Vimshottari {
  final DateTime birth;
  final String firstLord;
  final double balanceYears;
  final DateTime firstStart; // notional start of the first mahadasha

  const Vimshottari._(this.birth, this.firstLord, this.balanceYears, this.firstStart);

  factory Vimshottari(DateTime birth, double moonLongitude) {
    final lon = normalizeLongitude(moonLongitude);
    final i = (lon / nakSpan).floor().clamp(0, 26).toInt();
    final lord = kpOrder[i % 9];
    final frac = (lon - i * nakSpan) / nakSpan;
    final years = kpYears[lord]!.toDouble();
    return Vimshottari._(birth, lord, years * (1 - frac), _addYears(birth, -years * frac));
  }

  List<DashaPeriod> mahaDashas() {
    final out = <DashaPeriod>[];
    var start = firstStart;
    final k = kpOrder.indexOf(firstLord);
    for (var j = 0; j < 9; j++) {
      final l = kpOrder[(k + j) % 9];
      final end = _addYears(start, kpYears[l]!.toDouble());
      out.add(DashaPeriod(l, start, end));
      start = end;
    }
    return out;
  }

  /// Antar (inside a maha) or pratyantar (inside an antar) periods.
  List<DashaPeriod> subPeriods(DashaPeriod parent) {
    final total = parent.end.difference(parent.start).inMicroseconds;
    final k = kpOrder.indexOf(parent.lord);
    final out = <DashaPeriod>[];
    var start = parent.start;
    for (var j = 0; j < 9; j++) {
      final l = kpOrder[(k + j) % 9];
      final end = j == 8
          ? parent.end
          : start.add(Duration(microseconds: (total * kpYears[l]! / 120).round()));
      out.add(DashaPeriod(l, start, end));
      start = end;
    }
    return out;
  }

  DashaSnapshot at(DateTime when) {
    DashaPeriod pick(List<DashaPeriod> l) => l.firstWhere(
        (p) => !when.isBefore(p.start) && when.isBefore(p.end),
        orElse: () => l.last);
    final maha = pick(mahaDashas());
    final antar = pick(subPeriods(maha));
    final prat = pick(subPeriods(antar));
    return DashaSnapshot(maha, antar, prat);
  }
}
