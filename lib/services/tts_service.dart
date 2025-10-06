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
  bool _shouldStop = false; // Nueva variable para control de parada
  
  // Máximo de caracteres por bloque para evitar error -8
  static const int _maxCharsPerBlock = 3000;

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

  // Divide el texto en bloques seguros para evitar error -8
  List<String> _splitTextIntoBlocks(String text) {
    final List<String> blocks = [];
    
    if (text.length <= _maxCharsPerBlock) {
      return [text];
    }
    
    int startIndex = 0;
    while (startIndex < text.length) {
      int endIndex = startIndex + _maxCharsPerBlock;
      
      // Si no es el último bloque, intentar cortar en un punto natural (punto, coma, espacio)
      if (endIndex < text.length) {
        // Buscar el último punto o salto de línea antes del límite
        int lastPeriod = text.lastIndexOf('. ', endIndex);
        int lastNewline = text.lastIndexOf('\n', endIndex);
        int cutPoint = lastPeriod > startIndex ? lastPeriod + 2 : lastNewline;
        
        if (cutPoint > startIndex && cutPoint < endIndex) {
          endIndex = cutPoint;
        } else {
          // Si no hay punto, buscar el último espacio
          int lastSpace = text.lastIndexOf(' ', endIndex);
          if (lastSpace > startIndex) {
            endIndex = lastSpace + 1;
          }
        }
      } else {
        endIndex = text.length;
      }
      
      blocks.add(text.substring(startIndex, endIndex));
      startIndex = endIndex;
    }
    
    return blocks;
  }
  
  Future<void> speak(String text) async {
    if (text.isEmpty) {
      _logger.log('TTS: ⚠️ Texto vacío, no se puede reproducir', level: LogLevel.warning);
      return;
    }
    
    // Limpiar estado
    _logger.log('TTS: 🧹 Limpiando estado...', level: LogLevel.debug);
    _shouldStop = false;
    await _cleanupState();
    
    _logger.log('TTS: 🎤 Iniciando reproducción de ${text.length} caracteres', level: LogLevel.info);
    _pausedText = text;
    _pausedPosition = 0;
    _isPaused = false;
    
    // Dividir el texto en bloques seguros
    final blocks = _splitTextIntoBlocks(text);
    _logger.log('TTS: 📦 Texto dividido en ${blocks.length} bloques', level: LogLevel.info);
    
    try {
      // Reproducir cada bloque secuencialmente
      for (int i = 0; i < blocks.length; i++) {
        if (_shouldStop) {
          _logger.log('TTS: ⏹️ Detenido por solicitud del usuario', level: LogLevel.warning);
          break;
        }
        
        _logger.log('TTS: 📢 Reproduciendo bloque ${i + 1}/${blocks.length} (${blocks[i].length} chars)', level: LogLevel.debug);
        await _speakSingleBlock(blocks[i]);
        
        // Pequeña pausa entre bloques para evitar problemas
        if (i < blocks.length - 1 && !_shouldStop) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      
      _logger.log('TTS: ✅ Reproducción completa finalizada', level: LogLevel.success);
      _isPlaying = false;
      _isPaused = false;
    } catch (e) {
      _logger.log('TTS: ❌ Error durante reproducción: $e', level: LogLevel.error);
      _isPlaying = false;
      _isPaused = false;
    }
  }
  
  Future<void> _speakSingleBlock(String text) async {
    if (_shouldStop) return;
    
    _speechCompleter = Completer<void>();
    
    try {
      final result = await _flutterTts.speak(text);
      
      if (result == 1) {
        _isPlaying = true;
        
        // Esperar a que termine con timeout
        try {
          await _speechCompleter!.future.timeout(
            Duration(seconds: (text.length / 5).ceil() + 20),
          );
        } on TimeoutException {
          _logger.log('TTS: ⏱️ Timeout en bloque', level: LogLevel.warning);
        }
      } else {
        _logger.log('TTS: ❌ Error en bloque, código: $result', level: LogLevel.error);
        if (!_speechCompleter!.isCompleted) {
          _speechCompleter!.complete();
        }
      }
    } catch (e) {
      _logger.log('TTS: ❌ Excepción en bloque: $e', level: LogLevel.error);
      if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
        _speechCompleter!.complete();
      }
    }
  }
  
  Future<void> _cleanupState() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      _logger.log('TTS: ⚠️ Error al detener: $e', level: LogLevel.warning);
    }
    
    _isPlaying = false;
    _isPaused = false;
    
    if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
      _speechCompleter!.complete();
    }
    _speechCompleter = null;
    
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> pause() async {
    if (!_isPlaying) {
      _logger.log('TTS: ⚠️ No se puede pausar - no está reproduciendo', level: LogLevel.warning);
      return;
    }
    
    _logger.log('TTS: ⏸️ Pausando reproducción', level: LogLevel.info);
    _shouldStop = true;
    
    try {
      await _flutterTts.stop();
      await Future.delayed(const Duration(milliseconds: 200));
      _isPaused = true;
      _isPlaying = false;
      
      if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
        _speechCompleter!.complete();
      }
      
      _logger.log('TTS: ⏸️ Pausado - posición guardada: $_pausedPosition', level: LogLevel.info);
    } catch (e) {
      _logger.log('TTS: ❌ Error al pausar: $e', level: LogLevel.error);
    }
  }

  Future<void> resume() async {
    _logger.log('TTS: ▶️ Reanudando desde posición $_pausedPosition', level: LogLevel.info);
    
    if (!_isPaused) {
      _logger.log('TTS: ⚠️ No se puede resumir - no está pausado', level: LogLevel.warning);
      return;
    }
    
    if (_pausedText.isEmpty) {
      _logger.log('TTS: ⚠️ No se puede resumir - texto vacío', level: LogLevel.warning);
      return;
    }
    
    _isPaused = false;
    _shouldStop = false;
    
    try {
      await _cleanupState();
      
      final textToSpeak = _pausedText.substring(_pausedPosition);
      _logger.log('TTS: ▶️ Reproduciendo ${textToSpeak.length} caracteres restantes', level: LogLevel.info);
      
      // Usar el mismo sistema de bloques para resume
      final blocks = _splitTextIntoBlocks(textToSpeak);
      _logger.log('TTS: 📦 Texto de resume dividido en ${blocks.length} bloques', level: LogLevel.debug);
      
      for (int i = 0; i < blocks.length; i++) {
        if (_shouldStop) {
          _logger.log('TTS: ⏹️ Resume detenido por solicitud', level: LogLevel.warning);
          break;
        }
        
        await _speakSingleBlock(blocks[i]);
        
        if (i < blocks.length - 1 && !_shouldStop) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      
      _logger.log('TTS: ✅ Resume completado', level: LogLevel.success);
    } catch (e) {
      _logger.log('TTS: ❌ Excepción en resume: $e', level: LogLevel.error);
      _isPlaying = false;
    }
  }

  void setPausedText(String text, int position) {
    _pausedText = text;
    _pausedPosition = position;
    _logger.log('TTS: 💾 Posición guardada: $position de ${text.length} caracteres', level: LogLevel.debug);
  }

  Future<void> stop() async {
    _logger.log('TTS: ⏹️ Deteniendo reproducción', level: LogLevel.info);
    _shouldStop = true;
    
    try {
      await _flutterTts.stop();
      await Future.delayed(const Duration(milliseconds: 200));
      _isPlaying = false;
      _isPaused = false;
      _pausedText = '';
      _pausedPosition = 0;
      
      if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
        _speechCompleter!.complete();
      }
      _speechCompleter = null;
      
      _logger.log('TTS: ⏹️ Detenido completamente', level: LogLevel.info);
    } catch (e) {
      _logger.log('TTS: ❌ Error al detener: $e', level: LogLevel.error);
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
