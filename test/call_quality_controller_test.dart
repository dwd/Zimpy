import 'package:flutter_test/flutter_test.dart';
import 'package:wimsy/av/call_quality.dart';

void main() {
  test('CallQualityController reduces bitrate on poor conditions', () {
    const controller = CallQualityController(
      minVideoBitrateBps: 100000,
      maxVideoBitrateBps: 500000,
      stepBps: 100000,
    );
    final sample = CallQualitySample(
      timestamp: DateTime.utc(2026, 1, 1),
      rttMs: 600,
      packetLoss: 0.2,
    );

    final next = controller.nextTargetBitrate(
      currentBps: 500000,
      sample: sample,
    );

    expect(next, 400000);
  });

  test('CallQualityController increases bitrate on good conditions', () {
    const controller = CallQualityController(
      minVideoBitrateBps: 100000,
      maxVideoBitrateBps: 500000,
      stepBps: 100000,
    );
    final sample = CallQualitySample(
      timestamp: DateTime.utc(2026, 1, 1),
      rttMs: 120,
      packetLoss: 0.0,
    );

    final next = controller.nextTargetBitrate(
      currentBps: 200000,
      sample: sample,
    );

    expect(next, 300000);
  });

  test('CallQualityController returns null when conditions are mixed', () {
    const controller = CallQualityController();
    final sample = CallQualitySample(
      timestamp: DateTime.utc(2026, 1, 1),
      rttMs: 250,
      packetLoss: 0.05,
    );

    final next = controller.nextTargetBitrate(
      currentBps: 200000,
      sample: sample,
    );

    expect(next, isNull);
  });
}
