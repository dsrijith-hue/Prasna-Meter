import 'package:flutter/material.dart';
import 'analysis.dart';
import 'chart.dart';
import 'kp_tables.dart';
import 'scoring_engine.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Prashna Success Meter',
        theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
        home: const HomePage(),
      );
}

String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

const String samplePlanets = '''AS Cpcn 22:33:24
SU Lib 20:44:49
MO Vir 27:42:14
MA Cnc 27:35:04
ME Lib 14:41:06 R C
JU Leo 00:53:51
VE Vir 29:38:23 R
SA Pis 14:46:07 R
RA Aqu 01:35:44 R
KE Leo 01:35:44 R''';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const roles = [
    'opener', 'middle_order', 'finisher', 'pacer', 'spinner', 'all_rounder', 'keeper'
  ];
  ScoringEngine? engine;
  Mode mode = Mode.batting;
  String role = 'opener';
  final planetCtl = TextEditingController(text: samplePlanets);
  final cuspCtl = TextEditingController();
  DateTime chartDate = DateTime.now();
  DateTime evalDate = DateTime.now();
  bool moonVoid = false;
  Analysis? analysis;
  String? error;

  @override
  void initState() {
    super.initState();
    ScoringEngine.load().then((e) {
      setState(() => engine = e);
      _calc();
    });
  }

  void _calc() {
    final e = engine;
    if (e == null) return;
    try {
      final a = analyse(
        engine: e,
        mode: mode,
        role: role,
        planetText: planetCtl.text,
        cuspText: cuspCtl.text,
        chartTime: chartDate,
        evalTime: evalDate,
        moonVoid: moonVoid,
      );
      setState(() {
        analysis = a;
        error = null;
      });
    } catch (ex) {
      setState(() {
        analysis = null;
        error = ex is FormatException ? ex.message : ex.toString();
      });
    }
  }

  Future<void> _pick(bool forChart) async {
    final d = await showDatePicker(
      context: context,
      initialDate: forChart ? chartDate : evalDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    setState(() {
      if (forChart) {
        chartDate = d;
      } else {
        evalDate = d;
      }
    });
  }

  Widget _gauge(ScoreResult r) => Column(children: [
        SizedBox(
          width: 150,
          height: 150,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox.expand(
                child: CircularProgressIndicator(value: r.score / 100, strokeWidth: 12)),
            Text('${r.score}%',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          ]),
        ),
        const SizedBox(height: 10),
        Text(r.band, style: Theme.of(context).textTheme.titleLarge),
        if (r.wickets != null) Text('Expected wickets: ${r.wickets}+'),
        Text('Fantasy points: ${r.fantasyLow.toStringAsFixed(0)} to ${r.fantasyHigh.toStringAsFixed(0)}'),
      ]);

  Widget _scroll(Widget table) =>
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: table);

  Widget _planetTable(Analysis a) {
    final rows = <DataRow>[];
    for (final code in planetCodes) {
      final p = a.chart.planets[code]!;
      final k = p.lords;
      final flags = '${p.retro ? "(R)" : ""}${p.combust ? "(C)" : ""}';
      final sig = a.chart.significators(code).toList()..sort();
      rows.add(DataRow(cells: [
        DataCell(Text('$code$flags')),
        DataCell(Text(fmtLon(p.lon))),
        DataCell(Text(k.signLord)),
        DataCell(Text(k.nl)),
        DataCell(Text(k.sl)),
        DataCell(Text(k.ssl)),
        DataCell(Text('${a.chart.houseOf(p.lon)}')),
        DataCell(Text(sig.join(','))),
      ]));
    }
    return _scroll(DataTable(
      columnSpacing: 14,
      headingRowHeight: 36,
      dataRowMinHeight: 32,
      dataRowMaxHeight: 36,
      columns: const [
        DataColumn(label: Text('Plt')),
        DataColumn(label: Text('Position')),
        DataColumn(label: Text('RL')),
        DataColumn(label: Text('NL')),
        DataColumn(label: Text('SL')),
        DataColumn(label: Text('SSL')),
        DataColumn(label: Text('Hse')),
        DataColumn(label: Text('Signifies')),
      ],
      rows: rows,
    ));
  }

  Widget _cuspTable(Analysis a) {
    final rows = <DataRow>[];
    for (var h = 1; h <= 12; h++) {
      final lon = a.chart.pc.cusps[h - 1];
      final k = kpLordsFor(lon);
      final sig = a.chart.significators(k.sl).toList()..sort();
      rows.add(DataRow(cells: [
        DataCell(Text('C$h')),
        DataCell(Text(fmtLon(lon))),
        DataCell(Text(k.nl)),
        DataCell(Text(k.sl)),
        DataCell(Text(sig.join(','))),
      ]));
    }
    return _scroll(DataTable(
      columnSpacing: 14,
      headingRowHeight: 36,
      dataRowMinHeight: 32,
      dataRowMaxHeight: 36,
      columns: const [
        DataColumn(label: Text('Cusp')),
        DataColumn(label: Text('Position')),
        DataColumn(label: Text('NL')),
        DataColumn(label: Text('SL')),
        DataColumn(label: Text('SL signifies')),
      ],
      rows: rows,
    ));
  }

  Widget _results(Analysis a) {
    final d = a.dasha;
    final title = Theme.of(context).textTheme.titleMedium;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      Center(child: _gauge(a.result)),
      const SizedBox(height: 16),
      Text('Running dasha on ${fmtDate(evalDate)}', style: title),
      Text('Maha ${d.maha.lord} until ${fmtDate(d.maha.end)}'),
      Text('Antar ${d.antar.lord} until ${fmtDate(d.antar.end)}'),
      Text('Pratyantar ${d.pratyantar.lord} until ${fmtDate(d.pratyantar.end)}'),
      const SizedBox(height: 8),
      Text('Ruling planets: ${a.ruling.join(', ')}'),
      const SizedBox(height: 16),
      Text('Planets', style: title),
      _planetTable(a),
      const SizedBox(height: 16),
      Text('Cusps', style: title),
      if (a.chart.pc.equalHouse)
        const Text(
            'Equal-house approximation: cusps 120 degrees apart share the same sub lord, so scores are only rough. Paste real Placidus cusps for reliable KP results.',
            style: TextStyle(fontSize: 12)),
      _cuspTable(a),
      ExpansionTile(
        title: const Text('Why this score?'),
        children: a.result.reasons
            .map((x) => ListTile(dense: true, title: Text(x)))
            .toList(),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text(
            'Astrological guidance only, not a guarantee. Do not stake money you cannot afford to lose.',
            style: TextStyle(fontSize: 12)),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final a = analysis;
    return Scaffold(
      appBar: AppBar(title: const Text('Prashna Success Meter')),
      body: engine == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              SegmentedButton<Mode>(
                segments: const [
                  ButtonSegment(value: Mode.batting, label: Text('Batting')),
                  ButtonSegment(value: Mode.bowling, label: Text('Bowling')),
                ],
                selected: {mode},
                onSelectionChanged: (s) {
                  setState(() => mode = s.first);
                  _calc();
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(
                    labelText: 'Role', border: OutlineInputBorder()),
                items: roles
                    .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                    .toList(),
                onChanged: (v) {
                  setState(() => role = v ?? role);
                  _calc();
                },
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: OutlinedButton(
                        onPressed: () => _pick(true),
                        child: Text('Chart: ${fmtDate(chartDate)}'))),
                const SizedBox(width: 8),
                Expanded(
                    child: OutlinedButton(
                        onPressed: () => _pick(false),
                        child: Text('Evaluate: ${fmtDate(evalDate)}'))),
              ]),
              ExpansionTile(
                title: const Text('Chart data (paste from your KP app)'),
                children: [
                  TextField(
                    controller: planetCtl,
                    maxLines: 10,
                    decoration: const InputDecoration(
                        labelText: 'Planets: CODE Sign DD:MM:SS [R] [C]',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: cuspCtl,
                    maxLines: 12,
                    decoration: const InputDecoration(
                        labelText: 'Optional 12 cusps: Sign DD:MM:SS (blank = equal house)',
                        border: OutlineInputBorder()),
                  ),
                ],
              ),
              SwitchListTile(
                  title: const Text('Moon void of course'),
                  value: moonVoid,
                  onChanged: (v) => setState(() => moonVoid = v)),
              FilledButton(onPressed: _calc, child: const Text('Calculate')),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(error!, style: const TextStyle(color: Colors.red)),
                ),
              if (a != null) _results(a),
            ]),
    );
  }
}
