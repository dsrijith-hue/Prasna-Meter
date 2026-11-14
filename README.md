# Prashna Success Meter

KP scoring engine (batting and bowling) driven by assets/player_performance_config.json.

## Build the APK locally
1. Install Flutter (stable) and Android Studio / Android SDK.
2. In this folder run:
   flutter create --platforms=android --project-name prashna_success_meter .
   rm -f test/widget_test.dart
   flutter pub get
   flutter test
   flutter build apk --release
3. APK: build/app/outputs/flutter-apk/app-release.apk

## Build without installing anything
Push this folder to a GitHub repo (branch main). The "Build APK" workflow
builds it and attaches the APK under Actions > latest run > Artifacts.

## Modules
- lib/kp_tables.dart: RL/NL/SL/SSL from a sidereal longitude (no 249-row table needed).
- lib/vimshottari.dart: maha, antar and pratyantar periods at any date.
- lib/chart.dart: parses pasted positions/cusps, house placement, KP significators.
- lib/analysis.dart: builds the evidence automatically and scores it.
- lib/scoring_engine.dart: percentage scoring driven by the JSON config.

## Notes
- Planet longitudes still need an ephemeris (e.g. Swiss Ephemeris) with KP
  ayanamsa; this project does not compute them yet.
- Tune weights, bands and penalties only in the JSON config.
