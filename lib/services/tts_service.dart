import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import './log_service.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  final LogService _logger = LogService();
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
    _logger.log('TTS: Inicializando servicio TTS', level: LogLevel.debug);
    debugPrint('🔧 TTS: Inicializando servicio TTS');
    await _flutterTts.setLanguage("es-ES");
    await _flutterTts.setSpeechRate(_speechRate);
    await _flutterTts.setPitch(_pitch);
    
    _availableVoices = await _flutterTts.getVoices ?? [];
    _logger.log('TTS: ${_availableVoices.length} voces disponibles', level: LogLevel.debug);
    debugPrint('🔧 TTS: ${_availableVoices.length} voces disponibles');
    
    if (_availableVoices.isNotEmpty) {
      for (var voice in _availableVoices) {
        if (voice['name'].toString().contains('es')) {
          _currentVoice = voice['name'];
          await _flutterTts.setVoice({"name": voice['name'], "locale": voice['locale']});
          _logger.log('TTS: Voz seleccionada: $_currentVoice', level: LogLevel.debug);
          debugPrint('🔧 TTS: Voz seleccionada: $_currentVoice');
          break;
        }
      }
    }

    _flutterTts.setStartHandler(() {
      _logger.log('TTS: ▶️ Reproducción iniciada', level: LogLevel.info);
      debugPrint('▶️ TTS: Reproducción iniciada');
      _isPlaying = true;
      _isPaused = false;
    });

    _flutterTts.setCompletionHandler(() {
      _logger.log('TTS: ✅ Reproducción completada', level: LogLevel.success);
      debugPrint('✅ TTS: Reproducción completada');
      _isPlaying = false;
      _isPaused = false;
      _speechCompleter?.complete();
    });

    _flutterTts.setErrorHandler((msg) {
      _logger.log('TTS: ❌ Error: $msg', level: LogLevel.error);
      debugPrint('❌ TTS: Error: $msg');
      _isPlaying = false;
      _isPaused = false;
      _speechCompleter?.completeError(msg);
    });
    
    _flutterTts.setCancelHandler(() {
      _logger.log('TTS: ⏹️ Reproducción cancelada', level: LogLevel.warning);
      debugPrint('⏹️ TTS: Reproducción cancelada');
      _isPlaying = false;
      _isPaused = false;
      _speechCompleter?.complete();
    });
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) {
      _logger.log('TTS: ⚠️ Texto vacío, no se puede reproducir', level: LogLevel.warning);
      debugPrint('⚠️ TTS: Texto vacío, no se puede reproducir');
      return;
    }
    
    // CRÍTICO: Asegurar que el motor esté completamente detenido
    _logger.log('TTS: 🧹 Limpiando estado previo...', level: LogLevel.debug);
    debugPrint('🧹 TTS: Limpiando estado previo...');
    await _flutterTts.stop();
    _isPlaying = false;
    _isPaused = false;
    _speechCompleter?.complete();
    _speechCompleter = null;
    
    // Delay más largo para estabilización
    await Future.delayed(const Duration(milliseconds: 500));
    
    _logger.log('TTS: 🎤 Iniciando reproducción de ${text.length} caracteres', level: LogLevel.info);
    debugPrint('🎤 TTS: Iniciando reproducción de ${text.length} caracteres');
    _pausedText = text;
    _pausedPosition = 0;
    _isPaused = false;
    
    // Crear un completer para esperar a que termine realmente
    _speechCompleter = Completer<void>();
    
    try {
      final result = await _flutterTts.speak(text);
      _logger.log('TTS: speak() retornó: $result', level: LogLevel.debug);
      debugPrint('🎤 TTS: speak() retornó: $result');
      
      if (result == 1) {
        _logger.log('TTS: ✅ Comando speak ejecutado exitosamente', level: LogLevel.success);
        debugPrint('✅ TTS: Comando speak ejecutado exitosamente');
        _isPlaying = true;
        // Esperar a que complete realmente
        await _speechCompleter!.future.timeout(
          Duration(seconds: (text.length / 10).ceil() + 30),
          onTimeout: () {
            _logger.log('TTS: ⏱️ Timeout en reproducción', level: LogLevel.warning);
            debugPrint('⏱️ TTS: Timeout en reproducción');
          },
        );
        _logger.log('TTS: ✅ Reproducción finalizada completamente', level: LogLevel.success);
        debugPrint('✅ TTS: Reproducción finalizada completamente');
      } else {
        _logger.log('TTS: ❌ Error al ejecutar speak, código: $result', level: LogLevel.error);
        debugPrint('❌ TTS: Error al ejecutar speak, código: $result');
        _speechCompleter?.complete();
      }
    } catch (e) {
      _logger.log('TTS: ⚠️ Excepción en speak: $e', level: LogLevel.error);
      debugPrint('⚠️ TTS: Excepción en speak: $e');
      _speechCompleter?.complete();
      _isPlaying = false;
    }
  }

  Future<void> pause() async {
    if (!_isPlaying) {
      _logger.log('TTS: ⚠️ No se puede pausar - no está reproduciendo', level: LogLevel.warning);
      debugPrint('⚠️ TTS: No se puede pausar - no está reproduciendo');
      return;
    }
    
    _logger.log('TTS: ⏸️ Pausando reproducción', level: LogLevel.info);
    debugPrint('⏸️ TTS: Pausando reproducción');
    
    try {
      await _flutterTts.stop();
      await Future.delayed(const Duration(milliseconds: 300));
      _isPaused = true;
      _isPlaying = false;
      _speechCompleter?.complete();
      _logger.log('TTS: ⏸️ Pausado - posición guardada: $_pausedPosition', level: LogLevel.info);
      debugPrint('⏸️ TTS: Pausado - posición guardada: $_pausedPosition');
    } catch (e) {
      _logger.log('TTS: ❌ Error al pausar: $e', level: LogLevel.error);
      debugPrint('❌ TTS: Error al pausar: $e');
    }
  }

  Future<void> resume() async {
    _logger.log('TTS: ▶️ Reanudando desde posición $_pausedPosition', level: LogLevel.info);
    debugPrint('▶️ TTS: Reanudando desde posición $_pausedPosition');
    
    if (!_isPaused) {
      _logger.log('TTS: ⚠️ No se puede resumir - no está pausado', level: LogLevel.warning);
      debugPrint('⚠️ TTS: No se puede resumir - no está pausado');
      return;
    }
    
    if (_pausedText.isEmpty) {
      _logger.log('TTS: ⚠️ No se puede resumir - texto vacío', level: LogLevel.warning);
      debugPrint('⚠️ TTS: No se puede resumir - texto vacío');
      return;
    }
    
    _isPaused = false;
    
    try {
      // CRÍTICO: Limpiar estado antes de resumir
      _logger.log('TTS: 🧹 Limpiando estado previo...', level: LogLevel.debug);
      debugPrint('🧹 TTS: Limpiando estado previo...');
      await _flutterTts.stop();
      _speechCompleter?.complete();
      _speechCompleter = null;
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Crear nuevo completer
      _speechCompleter = Completer<void>();
      
      final textToSpeak = _pausedText.substring(_pausedPosition);
      _logger.log('TTS: ▶️ Reproduciendo ${textToSpeak.length} caracteres restantes', level: LogLevel.info);
      debugPrint('▶️ TTS: Reproduciendo ${textToSpeak.length} caracteres restantes');
      
      final result = await _flutterTts.speak(textToSpeak);
      _logger.log('TTS: resume speak() retornó: $result', level: LogLevel.debug);
      debugPrint('▶️ TTS: resume speak() retornó: $result');
      
      if (result == 1) {
        _isPlaying = true;
        await _speechCompleter!.future.timeout(
          Duration(seconds: (textToSpeak.length / 10).ceil() + 30),
          onTimeout: () {
            _logger.log('TTS: ⏱️ Timeout en resume', level: LogLevel.warning);
            debugPrint('⏱️ TTS: Timeout en resume');
          },
        );
        _logger.log('TTS: ✅ Resume completado', level: LogLevel.success);
        debugPrint('✅ TTS: Resume completado');
      }
    } catch (e) {
      _logger.log('TTS: ⚠️ Excepción en resume: $e', level: LogLevel.error);
      debugPrint('⚠️ TTS: Excepción en resume: $e');
      _speechCompleter?.complete();
      _isPlaying = false;
    }
  }

  void setPausedText(String text, int position) {
    _pausedText = text;
    _pausedPosition = position;
    _logger.log('TTS: 💾 Posición guardada: $position de ${text.length} caracteres', level: LogLevel.debug);
    debugPrint('💾 TTS: Posición guardada: $position de ${text.length} caracteres');
  }

  Future<void> stop() async {
    _logger.log('TTS: ⏹️ Deteniendo reproducción', level: LogLevel.info);
    debugPrint('⏹️ TTS: Deteniendo reproducción');
    
    try {
      await _flutterTts.stop();
      await Future.delayed(const Duration(milliseconds: 300));
      _isPlaying = false;
      _isPaused = false;
      _pausedText = '';
      _pausedPosition = 0;
      _speechCompleter?.complete();
      _speechCompleter = null;
      _logger.log('TTS: ⏹️ Detenido completamente', level: LogLevel.info);
      debugPrint('⏹️ TTS: Detenido completamente');
    } catch (e) {
      _logger.log('TTS: ❌ Error al detener: $e', level: LogLevel.error);
      debugPrint('❌ TTS: Error al detener: $e');
    }
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
