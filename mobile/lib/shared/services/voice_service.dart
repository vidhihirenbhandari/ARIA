import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'api_client.dart';

enum VoiceState { idle, listening, processing, speaking }

class VoiceService {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final ApiClient _client;
  bool _isInitialized = false;

  VoiceService(this._client);

  Future<bool> initialize() async {
    _isInitialized = await _stt.initialize(
      onError: (error) => print('STT error: $error'),
    );
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    return _isInitialized;
  }

  Future<String?> listen() async {
    if (!_isInitialized) await initialize();
    String? result;
    await _stt.listen(
      onResult: (r) {
        if (r.finalResult) result = r.recognizedWords;
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: false,
    );
    // Wait for result
    await Future.delayed(const Duration(seconds: 5));
    await _stt.stop();
    return result;
  }

  Future<void> stopListening() async {
    await _stt.stop();
  }

  Future<void> speak(String text) async {
    await _tts.speak(text);
  }

  bool get isListening => _stt.isListening;
}

final voiceServiceProvider = Provider<VoiceService>((ref) {
  return VoiceService(ref.read(apiClientProvider));
});
