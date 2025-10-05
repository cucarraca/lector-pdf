import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlaying = false;
  bool _isPaused = false;
  double _speechRate = 0.5;
  double _pitch = 1.0;
  String _currentVoice = '';
  List<dynamic> _availableVoices = [];
  String _pausedText = '';
  int _pausedPosition = 0;

  TtsService() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("es-ES");
    await _flutterTts.setSpeechRate(_speechRate);
    await _flutterTts.setPitch(_pitch);
    
    _availableVoices = await _flutterTts.getVoices ?? [];
    
    if (_availableVoices.isNotEmpty) {
      for (var voice in _availableVoices) {
        if (voice['name'].toString().contains('es')) {
          _currentVoice = voice['name'];
          await _flutterTts.setVoice({"name": voice['name'], "locale": voice['locale']});
          break;
        }
      }
    }

    _flutterTts.setStartHandler(() {
      _isPlaying = true;
      _isPaused = false;
    });

    _flutterTts.setCompletionHandler(() {
      _isPlaying = false;
      _isPaused = false;
    });

    _flutterTts.setErrorHandler((msg) {
      _isPlaying = false;
      _isPaused = false;
    });
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    _pausedText = text;
    _pausedPosition = 0;
    _isPaused = false;
    await _flutterTts.speak(text);
    _isPlaying = true;
  }

  Future<void> pause() async {
    await _flutterTts.stop();
    _isPaused = true;
    _isPlaying = false;
  }

  Future<void> resume() async {
    if (_isPaused && _pausedText.isNotEmpty) {
      _isPaused = false;
      await _flutterTts.speak(_pausedText.substring(_pausedPosition));
      _isPlaying = true;
    }
  }

  void setPausedText(String text, int position) {
    _pausedText = text;
    _pausedPosition = position;
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _isPlaying = false;
    _isPaused = false;
    _pausedText = '';
    _pausedPosition = 0;
  }

  Future<void> setRate(double rate) async {
    _speechRate = rate;
    await _flutterTts.setSpeechRate(rate);
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch;
    await _flutterTts.setPitch(pitch);
  }

  Future<void> setVoice(String voiceName) async {
    for (var voice in _availableVoices) {
      if (voice['name'] == voiceName) {
        _currentVoice = voiceName;
        await _flutterTts.setVoice({"name": voice['name'], "locale": voice['locale']});
        break;
      }
    }
  }

  Future<void> setLanguage(String language) async {
    await _flutterTts.setLanguage(language);
  }

  List<String> getAvailableVoices() {
    return _availableVoices
        .map((voice) => voice['name'].toString())
        .toList();
  }

  List<dynamic> getAvailableVoicesForLanguage(String languageCode) {
    return _availableVoices
        .where((voice) => voice['locale'].toString().startsWith(languageCode))
        .toList();
  }

  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  double get speechRate => _speechRate;
  double get pitch => _pitch;
  String get currentVoice => _currentVoice;

  Future<void> synthesizeToFile(String text, String path) async {
    await _flutterTts.synthesizeToFile(text, path);
  }

  void dispose() {
    _flutterTts.stop();
  }
}
