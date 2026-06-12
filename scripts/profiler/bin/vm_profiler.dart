#!/usr/bin/env dart
// 사용법: dart run bin/vm_profiler.dart <ws-url> <output-json-path>
// flutter drive 와 병렬로 실행되어 CPU 프로파일을 수집합니다.
// SIGINT를 받으면 수집을 종료하고 리포트를 저장합니다.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

late VmService _service;
late String _isolateId;
final _frameMs = <double>[];
var _collecting = false;

void main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('Usage: vm_profiler.dart <ws-url> <output-json>');
    exit(1);
  }

  var wsUrl = args[0];
  if (wsUrl.startsWith('http://')) {
    wsUrl = wsUrl.replaceFirst('http://', 'ws://');
    if (!wsUrl.endsWith('ws')) wsUrl = '${wsUrl}ws';
  }
  final outputPath = args[1];

  // ── VM service 연결 ───────────────────────────────────
  stderr.writeln('[vm_profiler] 연결 중: $wsUrl');
  try {
    _service = await vmServiceConnectUri(wsUrl);
  } catch (e) {
    stderr.writeln('[vm_profiler] 연결 실패: $e');
    exit(1);
  }
  stderr.writeln('[vm_profiler] 연결 성공');

  // ── Flutter isolate 찾기 ──────────────────────────────
  final vm = await _service.getVM();
  IsolateRef? target;
  for (final ref in vm.isolates ?? []) {
    final iso = await _service.getIsolate(ref.id!);
    final hasFlutter = iso.extensionRPCs
            ?.contains('ext.flutter.reassemble') ==
        true;
    if (hasFlutter || iso.name?.contains('main') == true) {
      target = ref;
      break;
    }
  }
  target ??= vm.isolates?.first;
  if (target == null) {
    stderr.writeln('[vm_profiler] isolate를 찾을 수 없음');
    exit(1);
  }
  _isolateId = target.id!;
  stderr.writeln('[vm_profiler] Isolate: ${target.name}');

  // ── Timeline 스트림 구독 (프레임 타이밍) ──────────────
  try {
    await _service.streamListen('Timeline');
    _service.onTimelineEvent.listen((event) {
      if (!_collecting) return;
      for (final te in event.timelineEvents ?? []) {
        final dur = te.json?['dur'];
        if (te.name == 'Frame' && dur != null) {
          _frameMs.add((dur as num).toDouble() / 1000.0);
        }
      }
    });
  } catch (_) {}

  // ── CPU 샘플 초기화 후 수집 시작 ─────────────────────
  try {
    await _service.clearCpuSamples(_isolateId);
  } catch (_) {}
  _collecting = true;
  stderr.writeln('[vm_profiler] 수집 시작. SIGINT로 종료하세요.');

  // ── SIGINT 수신 시 리포트 출력 ────────────────────────
  ProcessSignal.sigint.watch().listen((_) async {
    _collecting = false;
    stderr.writeln('\n[vm_profiler] 수집 종료 중...');
    await _saveReport(outputPath);
    await _service.dispose();
    exit(0);
  });

  // ── 대기 (flutter drive 가 SIGINT 를 보낼 때까지) ─────
  await Completer<void>().future;
}

Future<void> _saveReport(String outputPath) async {
  CpuSamples? cpuSamples;
  try {
    cpuSamples = await _service.getCpuSamples(_isolateId, 0, 999999999999);
  } catch (e) {
    stderr.writeln('[vm_profiler] CPU 샘플 수집 실패: $e');
  }

  final totalTicks = cpuSamples?.sampleCount ?? 0;
  final functions = cpuSamples?.functions ?? [];

  // 사용자 코드만 필터 (package:soi/)
  final userFuncs = functions
      .where((f) {
        final uri = f.function?.location?.script?.uri ?? '';
        return uri.contains('package:soi/');
      })
      .toList()
    ..sort((a, b) =>
        (b.inclusiveTicks ?? 0).compareTo(a.inclusiveTicks ?? 0));

  final topFuncs = userFuncs.take(20).map((f) {
    final uri = f.function?.location?.script?.uri ?? '';
    final shortUri = uri.replaceFirst('package:soi/', 'lib/');
    final incl = totalTicks > 0
        ? (f.inclusiveTicks ?? 0) / totalTicks * 100
        : 0.0;
    final excl = totalTicks > 0
        ? (f.exclusiveTicks ?? 0) / totalTicks * 100
        : 0.0;
    return {
      'name': f.function?.name ?? '(unknown)',
      'uri': shortUri,
      'inclusiveCpuPct': double.parse(incl.toStringAsFixed(2)),
      'exclusiveCpuPct': double.parse(excl.toStringAsFixed(2)),
    };
  }).toList();

  // 프레임 통계
  Map<String, dynamic>? frameStats;
  if (_frameMs.isNotEmpty) {
    final sorted = List<double>.from(_frameMs)..sort();
    final avg = sorted.reduce((a, b) => a + b) / sorted.length;
    final p90 = sorted[(sorted.length * 0.9).toInt()];
    final jank = sorted.where((d) => d > 16).length;
    frameStats = {
      'count': sorted.length,
      'avgMs': double.parse(avg.toStringAsFixed(2)),
      'p90Ms': double.parse(p90.toStringAsFixed(2)),
      'jankCount': jank,
      'jankPercent': double.parse((jank / sorted.length * 100).toStringAsFixed(1)),
    };
  }

  final report = {
    'collectedAt': DateTime.now().toIso8601String(),
    'totalCpuSamples': totalTicks,
    'hotFunctions': topFuncs,
    if (frameStats != null) 'frames': frameStats,
  };

  File(outputPath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(report),
  );
  stderr.writeln('[vm_profiler] 저장: $outputPath');
}
