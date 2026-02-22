import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'media_capture.dart';

typedef MediaDevicesEnumerator = Future<List<MediaDeviceInfo>> Function();

class WebRtcMediaCaptureService implements MediaCaptureService {
  WebRtcMediaCaptureService({MediaDevicesEnumerator? enumerateDevices})
      : _enumerateDevices = enumerateDevices ?? _defaultEnumerateDevices;

  final MediaDevicesEnumerator _enumerateDevices;

  @override
  Future<MediaCaptureCapabilities> getCapabilities() async {
    try {
      final devices = await _enumerateDevices();
      final hasAudio = devices.any((device) =>
          device.kind == 'audioinput' || device.kind == 'audio');
      final hasVideo = devices.any((device) =>
          device.kind == 'videoinput' || device.kind == 'video');

      return MediaCaptureCapabilities(
        hasAudio: hasAudio,
        hasVideo: hasVideo,
        hasCamera: hasVideo,
      );
    } catch (_) {
      return const MediaCaptureCapabilities(
        hasAudio: false,
        hasVideo: false,
        hasCamera: false,
      );
    }
  }

  static Future<List<MediaDeviceInfo>> _defaultEnumerateDevices() {
    return navigator.mediaDevices.enumerateDevices();
  }
}
