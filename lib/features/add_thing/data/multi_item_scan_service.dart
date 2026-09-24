import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'thing_ai_service.dart';
import '../domain/scanned_thing_candidate.dart';
import '../domain/thing_detection.dart';

enum MultiScanStage {
  preparing,
  locating,
  cropping,
  identifying,
  completed,
  failed,
}

class MultiScanProgress {
  const MultiScanProgress({
    required this.stage,
    required this.message,
    required this.progress,
    required this.totalDetected,
    required this.completedItems,
    required this.currentItem,
    required this.items,
    required this.elapsed,
    required this.logs,
    this.estimatedRemaining,
    this.failedItems = 0,
    this.currentCropBytes,
    this.currentHint,
    this.errorMessage,
  });

  final MultiScanStage stage;
  final String message;
  final double progress;
  final int totalDetected;
  final int completedItems;
  final int currentItem;
  final List<ScannedThingCandidate> items;
  final Duration elapsed;
  final Duration? estimatedRemaining;
  final int failedItems;
  final Uint8List? currentCropBytes;
  final String? currentHint;
  final List<String> logs;
  final String? errorMessage;

  int get identifiedCount => items.length;
}

class MultiItemScanService {
  const MultiItemScanService({
    this.jpegQuality = 90,
    this.cropPaddingRatio = 0.08,
  });

  final int jpegQuality;
  final double cropPaddingRatio;

  Stream<MultiScanProgress> scan({
    required Uint8List imageBytes,
  }) async* {
    final stopwatch = Stopwatch()..start();
    final logs = <String>[];
    final candidates = <ScannedThingCandidate>[];
    final recognitionDurations = <Duration>[];
    var failedItems = 0;
    var totalDetected = 0;

    void log(String line) {
      logs.add(line);
      if (logs.length > 8) {
        logs.removeAt(0);
      }
    }

    MultiScanProgress buildProgress({
      required MultiScanStage stage,
      required String message,
      required double value,
      required int completedItems,
      required int currentItem,
      Duration? remaining,
      Uint8List? currentCropBytes,
      String? currentHint,
      String? error,
    }) {
      return MultiScanProgress(
        stage: stage,
        message: message,
        progress: value.clamp(0.0, 1.0).toDouble(),
        totalDetected: totalDetected,
        completedItems: completedItems,
        currentItem: currentItem,
        items: List<ScannedThingCandidate>.unmodifiable(candidates),
        elapsed: stopwatch.elapsed,
        estimatedRemaining: remaining,
        failedItems: failedItems,
        currentCropBytes: currentCropBytes,
        currentHint: currentHint,
        logs: List<String>.unmodifiable(logs),
        errorMessage: error,
      );
    }

    try {
      log('Preparing full image');
      yield buildProgress(
        stage: MultiScanStage.preparing,
        message: 'Preparing image...',
        value: 0.03,
        completedItems: 0,
        currentItem: 0,
      );

      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) {
        throw StateError('Keepi could not decode this image.');
      }

      final source = img.bakeOrientation(decoded);
      final normalizedBytes = Uint8List.fromList(
        img.encodeJpg(source, quality: jpegQuality),
      );

      log('AI is locating separate products');
      yield buildProgress(
        stage: MultiScanStage.locating,
        message: 'AI is finding separate products...',
        value: 0.08,
        completedItems: 0,
        currentItem: 0,
      );

      final rawDetections = await ThingAiService.detectThings(
        imageBytes: normalizedBytes,
        mimeType: 'image/jpeg',
      );

      final detections = _prepareDetections(rawDetections);
      totalDetected = detections.length;

      if (detections.isEmpty) {
        throw StateError(
          'Keepi could not find separate products in this image.',
        );
      }

      log('AI found $totalDetected separate products');
      yield buildProgress(
        stage: MultiScanStage.cropping,
        message: 'Found $totalDetected products · creating individual crops...',
        value: 0.16,
        completedItems: 0,
        currentItem: 0,
      );

      final crops = <_DetectedCrop>[];
      for (var i = 0; i < detections.length; i++) {
        final detection = detections[i];
        final crop = _cropDetection(
          source: source,
          detection: detection,
          itemIndex: i + 1,
          totalItems: detections.length,
        );
        crops.add(crop);
      }

      log('Created ${crops.length} product images');
      yield buildProgress(
        stage: MultiScanStage.cropping,
        message: 'Created ${crops.length} individual product images',
        value: 0.20,
        completedItems: 0,
        currentItem: 0,
      );

      for (var i = 0; i < crops.length; i++) {
        final crop = crops[i];
        final itemNumber = i + 1;
        final itemStopwatch = Stopwatch()..start();

        log(
          'Identifying product $itemNumber/$totalDetected'
          '${crop.detection.hint.isEmpty ? '' : ' · ${crop.detection.hint}'}',
        );

        yield buildProgress(
          stage: MultiScanStage.identifying,
          message: 'Identifying product $itemNumber of $totalDetected',
          value: _identificationProgress(i, totalDetected),
          completedItems: i,
          currentItem: itemNumber,
          remaining: _estimateRemaining(
            recognitionDurations,
            totalDetected - i,
          ),
          currentCropBytes: crop.bytes,
          currentHint: crop.detection.hint,
        );

        try {
          final recognition = await ThingAiService.recognizeDetectedThing(
            imageBytes: crop.bytes,
            hint: crop.detection.hint,
            itemIndex: itemNumber,
            totalItems: totalDetected,
          );

          candidates.add(
            ScannedThingCandidate(
              recognition: recognition,
              cropBytes: crop.bytes,
              itemIndex: itemNumber,
              totalItems: totalDetected,
            ),
          );

          log(
            'Product $itemNumber identified: '
            '${recognition.name.isEmpty ? crop.detection.hint : recognition.name}',
          );
        } catch (_) {
          failedItems++;
          log('Product $itemNumber could not be identified; continuing');
        } finally {
          itemStopwatch.stop();
          recognitionDurations.add(itemStopwatch.elapsed);
        }

        yield buildProgress(
          stage: MultiScanStage.identifying,
          message:
              '$itemNumber of $totalDetected processed · '
              '${candidates.length} identified',
          value: _identificationProgress(itemNumber, totalDetected),
          completedItems: itemNumber,
          currentItem: itemNumber,
          remaining: _estimateRemaining(
            recognitionDurations,
            totalDetected - itemNumber,
          ),
          currentCropBytes: crop.bytes,
          currentHint: crop.detection.hint,
        );
      }

      if (candidates.isEmpty) {
        throw StateError(
          'Keepi found $totalDetected products but could not identify any of them.',
        );
      }

      stopwatch.stop();
      log('Scan complete: ${candidates.length} products identified');

      yield MultiScanProgress(
        stage: MultiScanStage.completed,
        message: 'Identified ${candidates.length} of $totalDetected products',
        progress: 1,
        totalDetected: totalDetected,
        completedItems: totalDetected,
        currentItem: totalDetected,
        items: List<ScannedThingCandidate>.unmodifiable(candidates),
        elapsed: stopwatch.elapsed,
        estimatedRemaining: Duration.zero,
        failedItems: failedItems,
        logs: List<String>.unmodifiable(logs),
      );
    } catch (error) {
      stopwatch.stop();
      log('Scan stopped');

      yield MultiScanProgress(
        stage: MultiScanStage.failed,
        message: 'Scan failed',
        progress: 1,
        totalDetected: totalDetected,
        completedItems: 0,
        currentItem: 0,
        items: List<ScannedThingCandidate>.unmodifiable(candidates),
        elapsed: stopwatch.elapsed,
        failedItems: failedItems,
        logs: List<String>.unmodifiable(logs),
        errorMessage: error.toString(),
      );
    }
  }

  List<ThingDetection> _prepareDetections(
    List<ThingDetection> rawDetections,
  ) {
    final sorted = rawDetections
        .where((detection) => detection.hasValidBox)
        .toList()
      ..sort((a, b) {
        final yCompare = a.yMin.compareTo(b.yMin);
        if ((a.yMin - b.yMin).abs() < 40) {
          return a.xMin.compareTo(b.xMin);
        }
        return yCompare;
      });

    final result = <ThingDetection>[];

    for (final detection in sorted) {
      final duplicateIndex = result.indexWhere(
        (existing) => _intersectionOverUnion(existing, detection) >= 0.72,
      );

      if (duplicateIndex == -1) {
        result.add(detection);
      } else if (detection.confidence > result[duplicateIndex].confidence) {
        result[duplicateIndex] = detection;
      }
    }

    return result.take(60).toList();
  }

  _DetectedCrop _cropDetection({
    required img.Image source,
    required ThingDetection detection,
    required int itemIndex,
    required int totalItems,
  }) {
    int xFromNormalized(int value) =>
        ((value / 1000) * source.width).round();

    int yFromNormalized(int value) =>
        ((value / 1000) * source.height).round();

    final rawLeft = xFromNormalized(detection.xMin);
    final rawTop = yFromNormalized(detection.yMin);
    final rawRight = xFromNormalized(detection.xMax);
    final rawBottom = yFromNormalized(detection.yMax);

    final rawWidth = math.max(1, rawRight - rawLeft);
    final rawHeight = math.max(1, rawBottom - rawTop);

    final padX = math.max(10, (rawWidth * cropPaddingRatio).round());
    final padY = math.max(8, (rawHeight * cropPaddingRatio).round());

    final left = math.max(0, rawLeft - padX);
    final top = math.max(0, rawTop - padY);
    final right = math.min(source.width, rawRight + padX);
    final bottom = math.min(source.height, rawBottom + padY);

    final cropped = img.copyCrop(
      source,
      x: left,
      y: top,
      width: math.max(1, right - left),
      height: math.max(1, bottom - top),
    );

    return _DetectedCrop(
      detection: detection,
      bytes: Uint8List.fromList(
        img.encodeJpg(cropped, quality: jpegQuality),
      ),
      itemIndex: itemIndex,
      totalItems: totalItems,
    );
  }

  double _identificationProgress(
    int completedItems,
    int totalItems,
  ) {
    const start = 0.20;
    const span = 0.78;

    if (totalItems <= 0) {
      return start;
    }

    return start + (completedItems / totalItems) * span;
  }

  Duration? _estimateRemaining(
    List<Duration> completedDurations,
    int itemsRemaining,
  ) {
    if (completedDurations.isEmpty || itemsRemaining <= 0) {
      return null;
    }

    final totalMilliseconds = completedDurations.fold<int>(
      0,
      (sum, duration) => sum + duration.inMilliseconds,
    );

    final averageMilliseconds =
        totalMilliseconds / completedDurations.length;

    return Duration(
      milliseconds: (averageMilliseconds * itemsRemaining).round(),
    );
  }

  double _intersectionOverUnion(
    ThingDetection a,
    ThingDetection b,
  ) {
    final left = math.max(a.xMin, b.xMin);
    final top = math.max(a.yMin, b.yMin);
    final right = math.min(a.xMax, b.xMax);
    final bottom = math.min(a.yMax, b.yMax);

    if (right <= left || bottom <= top) {
      return 0;
    }

    final intersection = (right - left) * (bottom - top);
    final areaA = (a.xMax - a.xMin) * (a.yMax - a.yMin);
    final areaB = (b.xMax - b.xMin) * (b.yMax - b.yMin);
    final union = areaA + areaB - intersection;

    if (union <= 0) {
      return 0;
    }

    return intersection / union;
  }
}

class _DetectedCrop {
  const _DetectedCrop({
    required this.detection,
    required this.bytes,
    required this.itemIndex,
    required this.totalItems,
  });

  final ThingDetection detection;
  final Uint8List bytes;
  final int itemIndex;
  final int totalItems;
}
