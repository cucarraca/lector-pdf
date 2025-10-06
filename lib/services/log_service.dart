import 'package:flutter/material.dart';

/// Servicio centralizado para capturar y mostrar logs en la app
class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final List<LogEntry> _logs = [];
  final int maxLogs = 500; // Máximo de logs en memoria
  
  // Stream para notificar cambios en logs
  final ValueNotifier<int> logCountNotifier = ValueNotifier<int>(0);

  /// Agregar log
  void log(String message, {LogLevel level = LogLevel.info}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      message: message,
      level: level,
    );
    
    _logs.add(entry);
    
    // Limitar tamaño
    if (_logs.length > maxLogs) {
      _logs.removeAt(0);
    }
    
    // Notificar cambio
    logCountNotifier.value = _logs.length;
    
    // También imprimir en consola para debug
    print('${entry.emoji} ${entry.message}');
  }

  /// Obtener todos los logs
  List<LogEntry> getLogs() => List.unmodifiable(_logs);

  /// Limpiar logs
  void clear() {
    _logs.clear();
    logCountNotifier.value = 0;
  }

  /// Exportar logs como texto
  String exportAsText() {
    final buffer = StringBuffer();
    buffer.writeln('═══════════════════════════════════════════════════════');
    buffer.writeln('LOGS DEL LECTOR PDF');
    buffer.writeln('Fecha exportación: ${DateTime.now()}');
    buffer.writeln('Total de logs: ${_logs.length}');
    buffer.writeln('═══════════════════════════════════════════════════════\n');
    
    for (final log in _logs) {
      buffer.writeln('${log.timestampFormatted} ${log.emoji} ${log.message}');
    }
    
    return buffer.toString();
  }
}

enum LogLevel {
  debug,
  info,
  warning,
  error,
  success,
}

class LogEntry {
  final DateTime timestamp;
  final String message;
  final LogLevel level;

  LogEntry({
    required this.timestamp,
    required this.message,
    required this.level,
  });

  String get timestampFormatted {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}.'
        '${(timestamp.millisecond ~/ 100).toString()}';
  }

  String get emoji {
    switch (level) {
      case LogLevel.debug:
        return '🔧';
      case LogLevel.info:
        return '📋';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
      case LogLevel.success:
        return '✅';
    }
  }

  Color get color {
    switch (level) {
      case LogLevel.debug:
        return Colors.grey;
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
      case LogLevel.success:
        return Colors.green;
    }
  }
}
