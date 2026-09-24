import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../data/thing_ai_service.dart';
import '../domain/scanned_thing_candidate.dart';
import '../domain/thing_recognition.dart';

enum MultiScanStage {
  preparing,
  splitting,
  scanning,
  merging,
  completed,
  failed,
}

class MultiScanProgress {
  const MultiScanProgress({
    required this.stage,
    required this.message,
    required this.progress,
    required this.totalTiles,
    required this.completedTiles,
    required this.currentTile,
    required this.items,
    required this.elapsed,
    required this.logs,
    this.estimatedRemaining,
    this.failedTiles = 0,
    this.errorMessage,
  });

  final MultiScanStage stage;
  final String message;
  final double progress;
  final int totalTiles;
  final int completedTiles;
  final int currentTile;
  final List<ScannedThingCandidate> items;
  final Duration elapsed;
  final Duration? estimatedRemaining;
  final int failedTiles;
  final List<String> logs;
  final String? errorMessage;

  int get itemCount => items.length;
}

class MultiItemScanService {
  const MultiItemScanService({
    this.overlapRatio = 0.12,
    this.jpegQuality = 86,
  });

  final double overlapRatio;
  final int jpegQuality;

  Stream<MultiScanProgress> scan({
    required Uint8List imageBytes,
  }) async* {
    final stopwatch = Stopwatch()..start();
    final logs = <String>[];
    final candidates = <ScannedThingCandidate>[];
    final tileDurations = <Duration>[];
    var failedTiles = 0;

    void log(String line) {
      logs.add(line);
      if (logs.length > 8) {
        logs.removeAt(0);
      }
    }

    MultiScanProgress progress({
      required MultiScanStage stage,
      required String message,
      required double value,
      required int totalTiles,
      required int completedTiles,
      required int currentTile,
      Duration? remaining,
      String? error,
    }) {
      return MultiScanProgress(
        stage: stage,
        message: message,
        progress: value.clamp(0.0, 1.0).toDouble(),
        totalTiles: totalTiles,
        completedTiles: completedTiles,
        currentTile: currentTile,
        items: List<ScannedThingCandidate>.unmodifiable(candidates),
        elapsed: stopwatch.elapsed,
        estimatedRemaining: remaining,
        failedTiles: failedTiles,
        logs: List<String>.unmodifiable(logs),
        errorMessage: error,
      );
    }

    try {
      log('Preparing image');
      yield progress(
        stage: MultiScanStage.preparing,
        message: 'Preparing image...',
        value: 0.04,
        totalTiles: 0,
        completedTiles: 0,
        currentTile: 0,
      );

      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) {
        throw StateError('Keepi could not decode this image.');
      }

      final plan = _choosePlan(decoded.width, decoded.height);
      final tiles = _createTiles(
        source: decoded,
        rows: plan.rows,
        columns: plan.columns,
      );

      log('Created ${tiles.length} overlapping scan areas');
      yield progress(
        stage: MultiScanStage.splitting,
        message: 'Found ${tiles.length} scan areas',
        value: 0.12,
        totalTiles: tiles.length,
        completedTiles: 0,
        currentTile: 0,
      );

      for (var i = 0; i < tiles.length; i++) {
        final tile = tiles[i];
        final tileNumber = i + 1;
        final tileStopwatch = Stopwatch()..start();

        log('Scanning area $tileNumber of ${tiles.length}');
        yield progress(
          stage: MultiScanStage.scanning,
          message: 'Scanning area $tileNumber of ${tiles.length}',
          value: _scanProgress(i, tiles.length),
          totalTiles: tiles.length,
          completedTiles: i,
          currentTile: tileNumber,
          remaining: _estimateRemaining(
            tileDurations,
            tiles.length - i,
          ),
        );

        final tileBytes = Uint8List.fromList(
          img.encodeJpg(tile, quality: jpegQuality),
        );

        try {
          final recognized = await ThingAiService.recognizeMultipleTile(
            imageBytes: tileBytes,
            tileIndex: tileNumber,
            totalTiles: tiles.length,
          );

          final incoming = recognized
              .map(
                (recognition) => ScannedThingCandidate(
                  recognition: recognition,
                  tileBytes: tileBytes,
                  tileIndex: tileNumber,
                  totalTiles: tiles.length,
                ),
              )
              .toList();

          final before = candidates.length;
          _mergeCandidates(candidates, incoming);
          final added = candidates.length - before;

          log(
            'Area $tileNumber complete: '
            '${recognized.length} detected, $added new',
          );
        } catch (error) {
          failedTiles++;
          log('Area $tileNumber failed; continuing');
        } finally {
          tileStopwatch.stop();
          tileDurations.add(tileStopwatch.elapsed);
        }

        yield progress(
          stage: MultiScanStage.scanning,
          message:
              'Area $tileNumber complete · ${candidates.length} items found',
          value: _scanProgress(tileNumber, tiles.length),
          totalTiles: tiles.length,
          completedTiles: tileNumber,
          currentTile: tileNumber,
          remaining: _estimateRemaining(
            tileDurations,
            tiles.length - tileNumber,
          ),
        );
      }

      if (failedTiles == tiles.length) {
        throw StateError(
          'All scan areas failed to reach Keepi AI. Please try again.',
        );
      }

      log('Merging overlapping results');
      yield progress(
        stage: MultiScanStage.merging,
        message: 'Removing duplicates...',
        value: 0.96,
        totalTiles: tiles.length,
        completedTiles: tiles.length,
        currentTile: tiles.length,
      );

      stopwatch.stop();
      log('Scan complete: ${candidates.length} unique items');

      yield MultiScanProgress(
        stage: MultiScanStage.completed,
        message: 'Found ${candidates.length} Things',
        progress: 1,
        totalTiles: tiles.length,
        completedTiles: tiles.length,
        currentTile: tiles.length,
        items: List<ScannedThingCandidate>.unmodifiable(candidates),
        elapsed: stopwatch.elapsed,
        estimatedRemaining: Duration.zero,
        failedTiles: failedTiles,
        logs: List<String>.unmodifiable(logs),
      );
    } catch (error) {
      stopwatch.stop();
      log('Scan stopped');

      yield MultiScanProgress(
        stage: MultiScanStage.failed,
        message: 'Scan failed',
        progress: 1,
        totalTiles: 0,
        completedTiles: 0,
        currentTile: 0,
        items: List<ScannedThingCandidate>.unmodifiable(candidates),
        elapsed: stopwatch.elapsed,
        failedTiles: failedTiles,
        logs: List<String>.unmodifiable(logs),
        errorMessage: error.toString(),
      );
    }
  }

  _GridPlan _choosePlan(int width, int height) {
    final ratio = width / height;

    if (ratio >= 1.28) {
      return const _GridPlan(rows: 3, columns: 2);
    }

    if (ratio <= 0.78) {
      return const _GridPlan(rows: 2, columns: 3);
    }

    return const _GridPlan(rows: 3, columns: 3);
  }

  List<img.Image> _createTiles({
    required img.Image source,
    required int rows,
    required int columns,
  }) {
    final cellWidth = source.width / columns;
    final cellHeight = source.height / rows;
    final overlapX = (cellWidth * overlapRatio).round();
    final overlapY = (cellHeight * overlapRatio).round();

    final tiles = <img.Image>[];

    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final rawLeft = (column * cellWidth).floor();
        final rawTop = (row * cellHeight).floor();
        final rawRight = ((column + 1) * cellWidth).ceil();
        final rawBottom = ((row + 1) * cellHeight).ceil();

        final left = math.max(0, rawLeft - overlapX);
        final top = math.max(0, rawTop - overlapY);
        final right = math.min(source.width, rawRight + overlapX);
        final bottom = math.min(source.height, rawBottom + overlapY);

        tiles.add(
          img.copyCrop(
            source,
            x: left,
            y: top,
            width: math.max(1, right - left),
            height: math.max(1, bottom - top),
          ),
        );
      }
    }

    return tiles;
  }

  double _scanProgress(int completedTiles, int totalTiles) {
    const start = 0.15;
    const span = 0.78;
    if (totalTiles <= 0) return start;
    return start + (completedTiles / totalTiles) * span;
  }

  Duration? _estimateRemaining(
    List<Duration> completedDurations,
    int tilesRemaining,
  ) {
    if (completedDurations.isEmpty || tilesRemaining <= 0) {
      return null;
    }

    final totalMilliseconds = completedDurations.fold<int>(
      0,
      (sum, duration) => sum + duration.inMilliseconds,
    );

    final average = totalMilliseconds / completedDurations.length;
    return Duration(
      milliseconds: (average * tilesRemaining).round(),
    );
  }

  void _mergeCandidates(
    List<ScannedThingCandidate> existing,
    List<ScannedThingCandidate> incoming,
  ) {
    for (final candidate in incoming) {
      final duplicateIndex = existing.indexWhere(
        (current) => _sameThing(
          current.recognition,
          candidate.recognition,
        ),
      );

      if (duplicateIndex == -1) {
        existing.add(candidate);
        continue;
      }

      if (candidate.recognition.confidence >
          existing[duplicateIndex].recognition.confidence) {
        existing[duplicateIndex] = candidate;
      }
    }
  }

  bool _sameThing(
    ThingRecognition a,
    ThingRecognition b,
  ) {
    if (a.categoryId != b.categoryId) {
      return false;
    }

    final aName = _normalize(a.name);
    final bName = _normalize(b.name);

    if (aName.isEmpty || bName.isEmpty) {
      return false;
    }

    if (aName == bName) {
      return true;
    }

    final aTokens = aName.split(' ').where((value) => value.length > 1).toSet();
    final bTokens = bName.split(' ').where((value) => value.length > 1).toSet();

    if (aTokens.isEmpty || bTokens.isEmpty) {
      return false;
    }

    final intersection = aTokens.intersection(bTokens).length;
    final union = aTokens.union(bTokens).length;
    final similarity = union == 0 ? 0.0 : intersection / union;

    return similarity >= 0.8;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9א-ת]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}

class _GridPlan {
  const _GridPlan({
    required this.rows,
    required this.columns,
  });

  final int rows;
  final int columns;
}
