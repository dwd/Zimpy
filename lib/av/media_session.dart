import 'package:flutter_webrtc/flutter_webrtc.dart';

abstract class MediaStreamHandle {
  String get id;
  Future<void> dispose();
}

typedef MediaStreamFactory = Future<MediaStreamHandle> Function({
  required bool audio,
  required bool video,
});

class WebRtcMediaStreamHandle implements MediaStreamHandle {
  WebRtcMediaStreamHandle(this._stream);

  final MediaStream _stream;

  MediaStream get stream => _stream;

  @override
  String get id => _stream.id;

  @override
  Future<void> dispose() async {
    await _stream.dispose();
  }
}

class WebRtcMediaSession {
  WebRtcMediaSession({MediaStreamFactory? createStream})
      : _createStream = createStream ?? _defaultCreateStream;

  final MediaStreamFactory _createStream;
  MediaStreamHandle? _activeStream;

  MediaStreamHandle? get activeStream => _activeStream;
  bool get isActive => _activeStream != null;

  Future<MediaStreamHandle> start({required bool audio, required bool video})
      async {
    if (_activeStream != null) {
      return _activeStream!;
    }
    final stream = await _createStream(audio: audio, video: video);
    _activeStream = stream;
    return stream;
  }

  Future<void> stop() async {
    final stream = _activeStream;
    if (stream == null) {
      return;
    }
    _activeStream = null;
    await stream.dispose();
  }

  static Future<MediaStreamHandle> _defaultCreateStream({
    required bool audio,
    required bool video,
  }) async {
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': audio,
      'video': video,
    });
    return WebRtcMediaStreamHandle(stream);
  }
}
