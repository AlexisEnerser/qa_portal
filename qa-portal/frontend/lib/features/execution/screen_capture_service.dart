import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Servicio de captura de pantalla usando Screen Capture API del navegador.
/// Solo funciona en Flutter Web (Chrome/Edge) en localhost o HTTPS.
class ScreenCaptureService {
  JSObject? _stream;
  JSObject? _video;
  bool _active = false;

  bool get isActive => _active;

  Future<bool> start() async {
    try {
      final navigator = globalContext['navigator']! as JSObject;
      final mediaDevices = navigator['mediaDevices']! as JSObject;

      final constraints = {'video': true}.jsify();
      final streamPromise =
          mediaDevices.callMethod<JSPromise>('getDisplayMedia'.toJS, constraints);
      _stream = (await streamPromise.toDart)! as JSObject;

      final document = globalContext['document']! as JSObject;
      _video = document.callMethod<JSObject>('createElement'.toJS, 'video'.toJS);
      _video!.setProperty('srcObject'.toJS, _stream!);
      _video!.setProperty('autoplay'.toJS, true.toJS);

      final playPromise = _video!.callMethod<JSPromise>('play'.toJS);
      await playPromise.toDart;

      // Wait for video to have dimensions
      await Future.delayed(const Duration(milliseconds: 500));

      _active = true;
      return true;
    } catch (e) {
      _active = false;
      return false;
    }
  }

  Future<Uint8List?> takeScreenshot() async {
    if (!_active || _video == null) return null;

    try {
      final document = globalContext['document']! as JSObject;
      final w = (_video!.getProperty<JSNumber>('videoWidth'.toJS)).toDartInt;
      final h = (_video!.getProperty<JSNumber>('videoHeight'.toJS)).toDartInt;
      if (w == 0 || h == 0) return null;

      final canvas =
          document.callMethod<JSObject>('createElement'.toJS, 'canvas'.toJS);
      canvas.setProperty('width'.toJS, w.toJS);
      canvas.setProperty('height'.toJS, h.toJS);

      final ctx = canvas.callMethod<JSObject>('getContext'.toJS, '2d'.toJS);
      // drawImage(video, 0, 0) — pass each arg separately
      ctx.callMethodVarArgs('drawImage'.toJS, [_video!, 0.toJS, 0.toJS]);

      final dataUrl = (canvas
              .callMethod<JSString>('toDataURL'.toJS, 'image/png'.toJS))
          .toDart;
      final base64Str = dataUrl.split(',').last;

      return base64Decode(base64Str);
    } catch (e) {
      return null;
    }
  }

  void stop() {
    try {
      if (_stream != null) {
        final tracks = _stream!.callMethod<JSArray>('getTracks'.toJS);
        final tracksList = tracks.toDart;
        for (final track in tracksList) {
          (track as JSObject).callMethodVarArgs('stop'.toJS, []);
        }
      }
    } catch (_) {}
    try {
      _video?.callMethodVarArgs('pause'.toJS, []);
    } catch (_) {}
    _video = null;
    _stream = null;
    _active = false;
  }
}
