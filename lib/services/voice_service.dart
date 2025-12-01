import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  // 1. Khởi tạo & Nghe (Speech-to-Text)
  Future<bool> initSpeech() async {
    return await _speech.initialize();
  }

  void startListening(Function(String) onResult) async {
    if (!_speech.isAvailable) return;
    await _speech.listen(onResult: (val) => onResult(val.recognizedWords));
  }

  void stopListening() async {
    await _speech.stop();
  }

  // 2. Đọc văn bản (Text-to-Speech)
  Future<void> speak(String text) async {
    await _flutterTts.setLanguage("vi-VN"); // Thiết lập tiếng Việt
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
  }
}
