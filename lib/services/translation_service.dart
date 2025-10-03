import 'package:flutter/foundation.dart';
import 'package:translator/translator.dart';

class TranslationService {
  final GoogleTranslator _translator = GoogleTranslator();

  Future<String> translateText(String text, String targetLanguage) async {
    try {
      if (text.isEmpty) return text;
      
      final translation = await _translator.translate(
        text,
        to: targetLanguage,
      );
      
      return translation.text;
    } catch (e) {
      debugPrint('Error al traducir: $e');
      return text;
    }
  }

  Future<String> detectLanguage(String text) async {
    try {
      if (text.isEmpty) return 'unknown';
      
      final translation = await _translator.translate(text, to: 'en');
      return translation.sourceLanguage.code;
    } catch (e) {
      debugPrint('Error al detectar idioma: $e');
      return 'unknown';
    }
  }

  Future<Map<String, String>> translateTextWithDetection(String text) async {
    try {
      if (text.isEmpty) {
        return {'original': text, 'translated': text, 'sourceLang': 'unknown'};
      }

      final translation = await _translator.translate(text, to: 'es');
      
      return {
        'original': text,
        'translated': translation.text,
        'sourceLang': translation.sourceLanguage.code,
      };
    } catch (e) {
      debugPrint('Error en traducción con detección: $e');
      return {'original': text, 'translated': text, 'sourceLang': 'unknown'};
    }
  }

  Future<bool> isSpanish(String text) async {
    try {
      final lang = await detectLanguage(text);
      return lang == 'es';
    } catch (e) {
      return true;
    }
  }
}
