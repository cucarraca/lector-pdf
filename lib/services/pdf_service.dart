import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';

class PdfService {
  Future<String> extractTextFromPdf(String pdfPath) async {
    try {
      final File file = File(pdfPath);
      final PdfDocument document = PdfDocument(inputBytes: await file.readAsBytes());
      
      String extractedText = '';
      
      for (int i = 0; i < document.pages.count; i++) {
        extractedText += PdfTextExtractor(document).extractText(startPageIndex: i, endPageIndex: i);
        extractedText += '\n';
      }
      
      document.dispose();
      return extractedText;
    } catch (e) {
      return '';
    }
  }

  Future<String> extractTextFromPage(String pdfPath, int pageIndex) async {
    try {
      final File file = File(pdfPath);
      final PdfDocument document = PdfDocument(inputBytes: await file.readAsBytes());
      
      if (pageIndex >= document.pages.count) {
        document.dispose();
        return '';
      }
      
      String text = PdfTextExtractor(document).extractText(
        startPageIndex: pageIndex,
        endPageIndex: pageIndex,
      );
      
      document.dispose();
      
      // Mejorar formato: normalizar saltos de línea y espacios
      text = _improveTextFormatting(text);
      
      return text;
    } catch (e) {
      debugPrint('Error al extraer texto de la página: $e');
      return '';
    }
  }
  
  // Mejorar el formato del texto extraído
  String _improveTextFormatting(String text) {
    if (text.isEmpty) return text;
    
    // Normalizar múltiples espacios a uno solo
    text = text.replaceAll(RegExp(r' +'), ' ');
    
    // Mantener saltos de línea simples, eliminar múltiples vacíos
    text = text.replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n');
    
    // Eliminar espacios al inicio/final de cada línea
    text = text.split('\n').map((line) => line.trim()).join('\n');
    
    // Eliminar líneas completamente vacías al inicio y final
    text = text.trim();
    
    return text;
  }
  
  // Detectar si el PDF tiene texto extraíble o es escaneado
  Future<bool> hasExtractableText(String pdfPath) async {
    try {
      final String firstPageText = await extractTextFromPage(pdfPath, 0);
      // Si la primera página tiene al menos 50 caracteres, asumimos que tiene texto
      return firstPageText.trim().length >= 50;
    } catch (e) {
      return false;
    }
  }

  Future<int> getPageCount(String pdfPath) async {
    try {
      final File file = File(pdfPath);
      final PdfDocument document = PdfDocument(inputBytes: await file.readAsBytes());
      final int pageCount = document.pages.count;
      document.dispose();
      return pageCount;
    } catch (e) {
      debugPrint('Error al obtener el número de páginas: $e');
      return 0;
    }
  }

  Future<String> exportTextToFile(String text, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName.txt');
      await file.writeAsString(text);
      return file.path;
    } catch (e) {
      debugPrint('Error al exportar texto: $e');
      return '';
    }
  }

  Future<List<String>> extractTextByPages(String pdfPath) async {
    try {
      final File file = File(pdfPath);
      final PdfDocument document = PdfDocument(inputBytes: await file.readAsBytes());
      
      List<String> pages = [];
      
      for (int i = 0; i < document.pages.count; i++) {
        final String pageText = PdfTextExtractor(document).extractText(
          startPageIndex: i,
          endPageIndex: i,
        );
        pages.add(pageText);
      }
      
      document.dispose();
      return pages;
    } catch (e) {
      debugPrint('Error al extraer páginas: $e');
      return [];
    }
  }

  String cleanText(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\n+'), '\n')
        .trim();
  }

  List<String> splitTextIntoSentences(String text) {
    final sentences = text.split(RegExp(r'[.!?]+'));
    return sentences
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
