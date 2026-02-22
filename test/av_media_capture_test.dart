import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wimsy/av/media_capture.dart';
import 'package:wimsy/av/webrtc_media_capture.dart';

void main() {
  test('NoopMediaCaptureService reports no capabilities', () async {
    final service = NoopMediaCaptureService();

    final capabilities = await service.getCapabilities();

    expect(capabilities.hasAudio, isFalse);
    expect(capabilities.hasVideo, isFalse);
    expect(capabilities.hasCamera, isFalse);
  });

  test('WebRtcMediaCaptureService maps device kinds', () async {
    final service = WebRtcMediaCaptureService(
      enumerateDevices: () async => [
        MediaDeviceInfo(
          kind: 'audioinput',
          label: 'Mic',
          deviceId: 'mic-1',
        ),
        MediaDeviceInfo(
          kind: 'videoinput',
          label: 'Cam',
          deviceId: 'cam-1',
        ),
      ],
    );

    final capabilities = await service.getCapabilities();

    expect(capabilities.hasAudio, isTrue);
    expect(capabilities.hasVideo, isTrue);
    expect(capabilities.hasCamera, isTrue);
  });

  test('WebRtcMediaCaptureService handles enumeration failure', () async {
    final service = WebRtcMediaCaptureService(
      enumerateDevices: () async => throw Exception('boom'),
    );

    final capabilities = await service.getCapabilities();

    expect(capabilities.hasAudio, isFalse);
    expect(capabilities.hasVideo, isFalse);
    expect(capabilities.hasCamera, isFalse);
  });
}
