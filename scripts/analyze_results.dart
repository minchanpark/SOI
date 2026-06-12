#!/usr/bin/env dart
// ignore_for_file: avoid_print
// CPU 프로파일 + Timeline 을 합쳐서 병목 요약을 출력합니다.
// Claude Code 가 이 출력을 읽고 수정 계획을 수립합니다.

import 'dart:convert';
import 'dart:io';

void main() {
  final cpuFile = File('build/cpu_profile_report.json');
  final summaryFiles = Directory('build')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.timeline_summary.json'))
      .toList();

  final hasCpu = cpuFile.existsSync();
  final hasTimeline = summaryFiles.isNotEmpty;

  if (!hasCpu && !hasTimeline) {
    print('❌  분석할 데이터가 없습니다. run_profile_session.sh 를 먼저 실행하세요.');
    exit(1);
  }

  print('');
  print('╔═══════════════════════════════════════════════════════════╗');
  print('║              SOI 성능 분석 리포트                         ║');
  print('╚═══════════════════════════════════════════════════════════╝');

  // ── Timeline 요약 ─────────────────────────────────────
  if (hasTimeline) {
    print('');
    print('▶ 프레임 통계 (Timeline)');
    for (final f in summaryFiles) {
      _printTimeline(f);
    }
  }

  // ── CPU 프로파일 ──────────────────────────────────────
  if (hasCpu) {
    _printCpu(cpuFile);
  }

  // ── 종합 진단 ─────────────────────────────────────────
  _printDiagnosis(cpuFile, summaryFiles);

  print('');
  print('════════════════════════════════════════════════════════════');
  print('💡  다음 단계: Claude에게 위 리포트를 바탕으로 수정 계획을 요청하세요.');
  print('════════════════════════════════════════════════════════════');
}

void _printTimeline(File f) {
  final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  final name = f.path.split('/').last.replaceAll('.timeline_summary.json', '');
  double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
  int i(String k) => (j[k] as num?)?.toInt() ?? 0;

  final missedBuild = i('missed_frame_build_budget_count');
  final missedRaster = i('missed_frame_rasterizer_budget_count');
  print('');
  print('  [$name]');
  print('  UI   avg ${_ms(d("average_frame_build_time_millis"))} | '
      'p90 ${_ms(d("90th_percentile_frame_build_time_millis"))} | '
      'jank $missedBuild 프레임 ${_jBadge(missedBuild)}');
  print('  GPU  avg ${_ms(d("average_frame_rasterizer_time_millis"))} | '
      'p90 ${_ms(d("90th_percentile_frame_rasterizer_time_millis"))} | '
      'jank $missedRaster 프레임 ${_jBadge(missedRaster)}');
}

void _printCpu(File f) {
  final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  final total = j['totalCpuSamples'] as int? ?? 0;
  final fns = (j['hotFunctions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  final frames = j['frames'] as Map<String, dynamic>?;

  print('');
  print('▶ CPU 핫스팟 (사용자 코드 상위 20, 총 샘플: $total)');
  if (fns.isEmpty) {
    print('  (데이터 없음 — VM service가 연결되지 않았을 수 있습니다)');
    return;
  }

  print('  ${"PCT".padLeft(6)}  ${"함수".padRight(50)} 파일');
  print('  ${"─" * 85}');
  for (final fn in fns) {
    final pct = (fn['inclusiveCpuPct'] as num).toStringAsFixed(1).padLeft(5);
    final name = _trunc(fn['name'] as String, 50);
    final uri = fn['uri'] as String;
    print('  $pct%  ${name.padRight(50)} $uri');
  }

  if (frames != null) {
    print('');
    print('  [VM 프레임 — vm_profiler 집계]');
    print('  avg ${_ms((frames["avgMs"] as num).toDouble())} | '
        'p90 ${_ms((frames["p90Ms"] as num).toDouble())} | '
        'jank ${frames["jankCount"]} 프레임 (${frames["jankPercent"]}%)');
  }
}

void _printDiagnosis(File cpuFile, List<File> summaryFiles) {
  print('');
  print('▶ 종합 진단');

  final issues = <String>[];

  // Timeline 기반 진단
  for (final f in summaryFiles) {
    final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    int i(String k) => (j[k] as num?)?.toInt() ?? 0;
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    final name = f.path.split('/').last.replaceAll('.timeline_summary.json', '');

    if (i('missed_frame_build_budget_count') > 3) {
      issues.add('[$name] UI Thread jank → widget rebuild 과다 또는 build()내 무거운 연산');
    }
    if (d('average_frame_build_time_millis') > 8) {
      issues.add('[$name] UI avg >8ms → setState 범위 확인, const 위젯 활용 검토');
    }
    if (i('missed_frame_rasterizer_budget_count') > 3) {
      issues.add('[$name] GPU Thread jank → Opacity/ClipPath/saveLayer 남용 또는 이미지 디코딩 병목');
    }
  }

  // CPU 기반 진단
  if (cpuFile.existsSync()) {
    final j = jsonDecode(cpuFile.readAsStringSync()) as Map<String, dynamic>;
    final fns = (j['hotFunctions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    for (final fn in fns.take(5)) {
      final pct = (fn['inclusiveCpuPct'] as num).toDouble();
      if (pct > 10) {
        issues.add('CPU 핫스팟 ${pct.toStringAsFixed(1)}%: '
            '${fn["name"]} (${fn["uri"]})');
      }
    }
  }

  if (issues.isEmpty) {
    print('  ✅  명확한 병목 없음. 세밀한 분석은 build/*.timeline.json 을 DevTools에서 확인.');
  } else {
    for (final issue in issues) {
      print('  ⚠️   $issue');
    }
  }
}

String _ms(double ms) => '${ms.toStringAsFixed(1).padLeft(5)}ms';
String _jBadge(int n) => n == 0 ? '✅' : n < 5 ? '⚠️' : '❌';
String _trunc(String s, int n) => s.length > n ? '${s.substring(0, n - 2)}..' : s;
