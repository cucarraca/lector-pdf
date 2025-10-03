import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pdf_book.dart';

class StorageService {
  static const String _booksKey = 'pdf_books';
  static const String _themeKey = 'app_theme';
  static const String _fontSizeKey = 'font_size';
  static const String _speechRateKey = 'speech_rate';

  Future<void> saveBooks(List<PdfBook> books) async {
    final prefs = await SharedPreferences.getInstance();
    final booksJson = books.map((book) => book.toJson()).toList();
    await prefs.setString(_booksKey, jsonEncode(booksJson));
  }

  Future<List<PdfBook>> loadBooks() async {
    final prefs = await SharedPreferences.getInstance();
    final booksString = prefs.getString(_booksKey);
    
    if (booksString == null || booksString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> booksJson = jsonDecode(booksString);
      return booksJson.map((json) => PdfBook.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error al cargar libros: $e');
      return [];
    }
  }

  Future<void> saveTheme(String themeName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, themeName);
  }

  Future<String> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'dracula';
  }

  Future<void> saveFontSize(double fontSize) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, fontSize);
  }

  Future<double> loadFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_fontSizeKey) ?? 16.0;
  }

  Future<void> saveSpeechRate(double rate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_speechRateKey, rate);
  }

  Future<double> loadSpeechRate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_speechRateKey) ?? 0.5;
  }

  Future<void> addBook(PdfBook book) async {
    final books = await loadBooks();
    books.add(book);
    await saveBooks(books);
  }

  Future<void> updateBook(PdfBook book) async {
    final books = await loadBooks();
    final index = books.indexWhere((b) => b.id == book.id);
    if (index != -1) {
      books[index] = book;
      await saveBooks(books);
    }
  }

  Future<void> removeBook(String bookId) async {
    final books = await loadBooks();
    books.removeWhere((book) => book.id == bookId);
    await saveBooks(books);
  }

  Future<PdfBook?> getBook(String bookId) async {
    final books = await loadBooks();
    try {
      return books.firstWhere((book) => book.id == bookId);
    } catch (e) {
      return null;
    }
  }
}
