import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

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
  Completer<void>? _speechCompleter;

  TtsService() {
    _initTts();
  }

  Future<void> _initTts() async {
    debugPrint('🔧 TTS: Inicializando servicio TTS');
    await _flutterTts.setLanguage("es-ES");
    await _flutterTts.setSpeechRate(_speechRate);
    await _flutterTts.setPitch(_pitch);
    
    _availableVoices = await _flutterTts.getVoices ?? [];
    debugPrint('🔧 TTS: ${_availableVoices.length} voces disponibles');
    
    if (_availableVoices.isNotEmpty) {
      for (var voice in _availableVoices) {
        if (voice['name'].toString().contains('es')) {
          _currentVoice = voice['name'];
          await _flutterTts.setVoice({"name": voice['name'], "locale": voice['locale']});
          debugPrint('🔧 TTS: Voz seleccionada: $_currentVoice');
          break;
        }
      }
    }

    _flutterTts.setStartHandler(() {
      debugPrint('▶️ TTS: Reproducción iniciada');
      _isPlaying = true;
      _isPaused = false;
    });

    _flutterTts.setCompletionHandler(() {
      debugPrint('✅ TTS: Reproducción completada');
      _isPlaying = false;
      _isPaused = false;
      _speechCompleter?.complete();
    });

    _flutterTts.setErrorHandler((msg) {
      debugPrint('❌ TTS: Error: $msg');
      _isPlaying = false;
      _isPaused = false;
      _speechCompleter?.completeError(msg);
    });
    
    _flutterTts.setCancelHandler(() {
      debugPrint('⏹️ TTS: Reproducción cancelada');
      _isPlaying = false;
      _isPaused = false;
      _speechCompleter?.complete();
    });
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) {
      debugPrint('⚠️ TTS: Texto vacío, no se puede reproducir');
      return;
    }
    
    debugPrint('🎤 TTS: Iniciando reproducción de ${text.length} caracteres');
    _pausedText = text;
    _pausedPosition = 0;
    _isPaused = false;
    
    // Crear un completer para esperar a que termine realmente
    _speechCompleter = Completer<void>();
    
    final result = await _flutterTts.speak(text);
    debugPrint('🎤 TTS: speak() retornó: $result');
    
    if (result == 1) {
      debugPrint('✅ TTS: Comando speak ejecutado exitosamente');
      _isPlaying = true;
      // Esperar a que complete realmente
      await _speechCompleter!.future;
      debugPrint('✅ TTS: Reproducción finalizada completamente');
    } else {
      debugPrint('❌ TTS: Error al ejecutar speak, código: $result');
    }
  }

  Future<void> pause() async {
    debugPrint('⏸️ TTS: Pausando reproducción');
    await _flutterTts.stop();
    _isPaused = true;
    _isPlaying = false;
    debugPrint('⏸️ TTS: Pausado - posición guardada: $_pausedPosition');
  }

  Future<void> resume() async {
    debugPrint('▶️ TTS: Reanudando desde posición $_pausedPosition');
    if (_isPaused && _pausedText.isNotEmpty) {
      _isPaused = false;
      
      // Crear nuevo completer
      _speechCompleter = Completer<void>();
      
      final textToSpeak = _pausedText.substring(_pausedPosition);
      debugPrint('▶️ TTS: Reproduciendo ${textToSpeak.length} caracteres restantes');
      
      final result = await _flutterTts.speak(textToSpeak);
      debugPrint('▶️ TTS: resume speak() retornó: $result');
      
      if (result == 1) {
        _isPlaying = true;
        await _speechCompleter!.future;
        debugPrint('✅ TTS: Resume completado');
      }
    } else {
      debugPrint('⚠️ TTS: No se puede resumir - isPaused: $_isPaused, texto vacío: ${_pausedText.isEmpty}');
    }
  }

  void setPausedText(String text, int position) {
    _pausedText = text;
    _pausedPosition = position;
    debugPrint('💾 TTS: Posición guardada: $position de ${text.length} caracteres');
  }

  Future<void> stop() async {
    debugPrint('⏹️ TTS: Deteniendo reproducción');
    await _flutterTts.stop();
    _isPlaying = false;
    _isPaused = false;
    _pausedText = '';
    _pausedPosition = 0;
    _speechCompleter?.complete();
    debugPrint('⏹️ TTS: Detenido completamente');
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
