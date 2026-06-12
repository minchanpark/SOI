#!/usr/bin/env dart
// ignore_for_file: avoid_print
// Usage: dart run scripts/analyze_timeline.dart [build_dir]

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final buildDir = Directory(args.isNotEmpty ? args[0] : 'build');

  if (!buildDir.existsSync()) {
    _err('build/ directory not found. Run the perf test first.');
    exit(1);
  }

  final summaryFiles = buildDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.timeline_summary.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (summaryFiles.isEmpty) {
    _err('No *.timeline_summary.json found in ${buildDir.path}/');
    _err('Run: bash scripts/run_perf.sh');
    exit(1);
  }

  var hasJank = false;
  for (final f in summaryFiles) {
    if (_analyzeFile(f)) hasJank = true;
  }

  exit(hasJank ? 1 : 0);
}

/// Returns true if jank was detected.
bool _analyzeFile(File file) {
  final Map<String, dynamic> json;
  try {
    json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  } catch (e) {
    _err('Failed to parse ${file.path}: $e');
    return false;
  }

  double d(String key) => (json[key] as num?)?.toDouble() ?? 0.0;
  int i(String key) => (json[key] as num?)?.toInt() ?? 0;

  final avgBuild = d('average_frame_build_time_millis');
  final p90Build = d('90th_percentile_frame_build_time_millis');
  final p99Build = d('99th_percentile_frame_build_time_millis');
  final worstBuild = d('worst_frame_build_time_millis');
  final missedBuild = i('missed_frame_build_budget_count');

  final avgRaster = d('average_frame_rasterizer_time_millis');
  final p90Raster = d('90th_percentile_frame_rasterizer_time_millis');
  final worstRaster = d('worst_frame_rasterizer_time_millis');
  final missedRaster = i('missed_frame_rasterizer_budget_count');

  final frameCount = i('frame_count');
  final testName = file.path.split('/').last.replaceAll('.timeline_summary.json', '');

  print('');
  print('══════════════════════════════════════════════');
  print('  📊  $testName');
  print('══════════════════════════════════════════════');
  print('  총 프레임: $frameCount');
  print('');
  print('  [UI Thread — Build]');
  print('    avg   : ${_ms(avgBuild)}  ${_badge(avgBuild, 8, 16)}');
  print('    p90   : ${_ms(p90Build)}  ${_badge(p90Build, 12, 16)}');
  print('    p99   : ${_ms(p99Build)}  ${_badge(p99Build, 16, 32)}');
  print('    worst : ${_ms(worstBuild)}');
  print('    jank (>16ms): $missedBuild 프레임  ${_jankBadge(missedBuild)}');
  print('');
  print('  [GPU Thread — Raster]');
  print('    avg   : ${_ms(avgRaster)}  ${_badge(avgRaster, 8, 16)}');
  print('    p90   : ${_ms(p90Raster)}  ${_badge(p90Raster, 12, 16)}');
  print('    worst : ${_ms(worstRaster)}');
  print('    jank (>16ms): $missedRaster 프레임  ${_jankBadge(missedRaster)}');

  final hasJank = missedBuild > 0 || missedRaster > 0;
  if (hasJank) {
    print('');
    print('  [진단]');
    if (avgBuild > 8) {
      print('  ⚠  UI avg >8ms → widget build/layout 부하');
      print('     → setState 범위, build()내 연산, 불필요한 rebuild 확인');
    }
    if (avgRaster > 8) {
      print('  ⚠  GPU avg >8ms → 렌더링 부하');
      print('     → Opacity/ClipPath/saveLayer 남용, shader 복잡도 확인');
    }
    if (worstBuild > 32) {
      print('  ❌  worst >32ms → 특정 프레임에서 blocking 연산 의심');
      print('     → 전체 timeline.json에서 해당 프레임 이벤트 추적 필요');
    }
    if (missedRaster > missedBuild * 2) {
      print('  ⚠  GPU jank이 UI jank보다 많음 → 이미지 디코딩/캐시 미스 의심');
    }
  } else {
    print('');
    print('  ✅  Jank 없음 — 60fps 목표 달성');
  }

  print('══════════════════════════════════════════════');
  return hasJank;
}

String _ms(double ms) => '${ms.toStringAsFixed(1).padLeft(6)} ms';

String _badge(double ms, double warn, double bad) {
  if (ms < warn) return '✅';
  if (ms < bad) return '⚠️ ';
  return '❌';
}

String _jankBadge(int count) {
  if (count == 0) return '✅';
  if (count < 5) return '⚠️ ';
  return '❌';
}

void _err(String msg) => stderr.writeln('  ERROR: $msg');
