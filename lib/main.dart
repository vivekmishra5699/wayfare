import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'screens/map_screen.dart';
import 'services/app_settings.dart';
import 'services/render_quality.dart';
import 'util/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // One SharedPreferences read covers both; the render quality and the
  // restored camera must be known before the first frame to avoid building
  // the (expensive) tile layers twice.
  await Future.wait([RenderQualitySettings.load(), AppSettings.load()]);
  if (_frameStats) _installFrameStats();
  runApp(const WayfareApp());
}

/// Dev-only frame timing log (`--dart-define=OM_FRAMESTATS=true`): every 2 s
/// prints frame count, average / p90 UI and raster times and the number of
/// frames over the 16.7 ms budget for that window.
const _frameStats = bool.fromEnvironment('OM_FRAMESTATS');

void _installFrameStats() {
  final ui = <int>[];
  final raster = <int>[];
  var windowStart = DateTime.now();
  SchedulerBinding.instance.addTimingsCallback((timings) {
    for (final t in timings) {
      ui.add(t.buildDuration.inMicroseconds);
      raster.add(t.rasterDuration.inMicroseconds);
    }
    final now = DateTime.now();
    if (now.difference(windowStart).inMilliseconds < 2000 || ui.isEmpty) return;
    int p(List<int> v, double q) {
      final s = [...v]..sort();
      return s[((s.length - 1) * q).round()];
    }
    int avg(List<int> v) => v.reduce((a, b) => a + b) ~/ v.length;
    var janky = 0;
    for (var i = 0; i < ui.length; i++) {
      if (ui[i] + raster[i] > 16700) janky++;
    }
    // ignore: avoid_print
    print('FRAMESTATS n=${ui.length} ui avg=${avg(ui) ~/ 1000}ms p90=${p(ui, 0.9) ~/ 1000}ms '
        'raster avg=${avg(raster) ~/ 1000}ms p90=${p(raster, 0.9) ~/ 1000}ms '
        'janky=$janky (${(100 * janky / ui.length).round()}%)');
    ui.clear();
    raster.clear();
    windowStart = now;
  });
}

class WayfareApp extends StatelessWidget {
  const WayfareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSettings.themeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'Wayfare',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: kBrandBlue),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: kBrandBlue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: mode,
        home: const MapScreen(),
      ),
    );
  }
}
