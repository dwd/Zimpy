class CallQualitySample {
  const CallQualitySample({
    required this.timestamp,
    this.rttMs,
    this.outboundKbps,
    this.inboundKbps,
    this.packetLoss,
    this.jitterMs,
    this.targetVideoBitrateBps,
  });

  final DateTime timestamp;
  final double? rttMs;
  final double? outboundKbps;
  final double? inboundKbps;
  final double? packetLoss;
  final double? jitterMs;
  final int? targetVideoBitrateBps;
}

class CallQualityController {
  const CallQualityController({
    this.minVideoBitrateBps = 150000,
    this.maxVideoBitrateBps = 2000000,
    this.stepBps = 200000,
    this.goodRttMs = 200,
    this.poorRttMs = 400,
    this.goodLoss = 0.02,
    this.poorLoss = 0.08,
  });

  final int minVideoBitrateBps;
  final int maxVideoBitrateBps;
  final int stepBps;
  final double goodRttMs;
  final double poorRttMs;
  final double goodLoss;
  final double poorLoss;

  int? nextTargetBitrate({
    required int? currentBps,
    required CallQualitySample sample,
  }) {
    final loss = sample.packetLoss;
    final rtt = sample.rttMs;
    if (loss == null && rtt == null) {
      return null;
    }
    final current = currentBps ?? maxVideoBitrateBps;
    final isPoor =
        (loss != null && loss >= poorLoss) || (rtt != null && rtt >= poorRttMs);
    if (isPoor) {
      return (current - stepBps).clamp(minVideoBitrateBps, maxVideoBitrateBps);
    }
    final isGood =
        (loss != null && loss <= goodLoss) && (rtt != null && rtt <= goodRttMs);
    if (isGood) {
      return (current + stepBps).clamp(minVideoBitrateBps, maxVideoBitrateBps);
    }
    return null;
  }
}
