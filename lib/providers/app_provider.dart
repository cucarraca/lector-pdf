import 'package:flutter/material.dart';
import '../models/pdf_book.dart';
import '../models/app_theme.dart';
import '../services/storage_service.dart';
import '../services/tts_service.dart';
import '../services/translation_service.dart';
import '../services/pdf_service.dart';

class AppProvider with ChangeNotifier {
  final StorageService _storageService = StorageService();
  final TtsService _ttsService = TtsService();
  final TranslationService _translationService = TranslationService();
  final PdfService _pdfService = PdfService();

  List<PdfBook> _books = [];
  String _currentTheme = 'dracula';
  double _fontSize = 16.0;
  double _speechRate = 0.5;
  bool _isPlaying = false;
  String? _currentBookId;
  int _currentPage = 0;
  bool _isTranslating = false;

  List<PdfBook> get books => _books;
  String get currentTheme => _currentTheme;
  double get fontSize => _fontSize;
  double get speechRate => _speechRate;
  bool get isPlaying => _isPlaying;
  String? get currentBookId => _currentBookId;
  int get currentPage => _currentPage;
  TtsService get ttsService => _ttsService;
  TranslationService get translationService => _translationService;
  PdfService get pdfService => _pdfService;
  bool get isTranslating => _isTranslating;

  AppThemeData get themeData => AppThemes.getTheme(_currentTheme);

  Future<void> initialize() async {
    await loadBooks();
    await loadSettings();
  }

  Future<void> loadBooks() async {
    _books = await _storageService.loadBooks();
    _books.sort((a, b) => b.lastOpened.compareTo(a.lastOpened));
    notifyListeners();
  }

  Future<void> loadSettings() async {
    _currentTheme = await _storageService.loadTheme();
    _fontSize = await _storageService.loadFontSize();
    _speechRate = await _storageService.loadSpeechRate();
    await _ttsService.setRate(_speechRate);
    notifyListeners();
  }

  Future<void> addBook(PdfBook book) async {
    await _storageService.addBook(book);
    await loadBooks();
  }

  Future<void> updateBook(PdfBook book) async {
    await _storageService.updateBook(book);
    await loadBooks();
  }

  Future<void> removeBook(String bookId) async {
    await _storageService.removeBook(bookId);
    await loadBooks();
  }

  Future<void> setTheme(String themeName) async {
    _currentTheme = themeName;
    await _storageService.saveTheme(themeName);
    notifyListeners();
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size;
    await _storageService.saveFontSize(size);
    notifyListeners();
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate;
    await _storageService.saveSpeechRate(rate);
    await _ttsService.setRate(rate);
    notifyListeners();
  }

  void setCurrentBook(String bookId, int page) {
    _currentBookId = bookId;
    _currentPage = page;
    notifyListeners();
  }

  Future<void> speak(String text) async {
    debugPrint('📢 Provider: speak() llamado con ${text.length} caracteres');
    _isPlaying = true;
    notifyListeners();
    
    await _ttsService.speak(text);
    
    debugPrint('📢 Provider: speak() completado');
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> pause() async {
    debugPrint('📢 Provider: pause() llamado');
    await _ttsService.pause();
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> resume() async {
    debugPrint('📢 Provider: resume() llamado');
    await _ttsService.resume();
    _isPlaying = true;
    notifyListeners();
  }
  
  void setPausedText(String text, int position) {
    debugPrint('📢 Provider: setPausedText() - posición: $position');
    _ttsService.setPausedText(text, position);
  }

  Future<void> stop() async {
    debugPrint('📢 Provider: stop() llamado');
    await _ttsService.stop();
    _isPlaying = false;
    notifyListeners();
  }

  Future<String> translateAndSpeak(String text) async {
    _isTranslating = true;
    notifyListeners();

    try {
      final isSpanish = await _translationService.isSpanish(text);
      
      if (!isSpanish) {
        final translated = await _translationService.translateText(text, 'es');
        _isTranslating = false;
        notifyListeners();
        await speak(translated);
        return translated;
      } else {
        _isTranslating = false;
        notifyListeners();
        await speak(text);
        return text;
      }
    } catch (e) {
      _isTranslating = false;
      notifyListeners();
      await speak(text);
      return text;
    }
  }

  Future<void> addBookmark(String bookId, int pageNumber, String title) async {
    final book = _books.firstWhere((b) => b.id == bookId);
    final bookmark = Bookmark(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      pageNumber: pageNumber,
      title: title,
      createdAt: DateTime.now(),
    );
    
    final updatedBook = book.copyWith(
      bookmarks: [...book.bookmarks, bookmark],
    );
    
    await updateBook(updatedBook);
  }

  Future<void> removeBookmark(String bookId, String bookmarkId) async {
    final book = _books.firstWhere((b) => b.id == bookId);
    final updatedBookmarks = book.bookmarks.where((b) => b.id != bookmarkId).toList();
    
    final updatedBook = book.copyWith(bookmarks: updatedBookmarks);
    await updateBook(updatedBook);
  }

  Future<void> updateProgress(String bookId, int currentPage, int totalPages) async {
    final book = _books.firstWhere((b) => b.id == bookId);
    final progress = currentPage / totalPages;
    
    final updatedBook = book.copyWith(
      currentPage: currentPage,
      progress: progress,
      lastOpened: DateTime.now(),
    );
    
    await updateBook(updatedBook);
  }

  List<String> getAvailableVoices() {
    return _ttsService.getAvailableVoices();
  }

  Future<void> setVoice(String voiceName) async {
    await _ttsService.setVoice(voiceName);
    notifyListeners();
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }
}
