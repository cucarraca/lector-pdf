import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pdf_book.dart';
import '../providers/app_provider.dart';
import '../widgets/reader_controls.dart';

class TextViewScreen extends StatefulWidget {
  final PdfBook book;
  final int initialPage;
  
  const TextViewScreen({
    super.key,
    required this.book,
    this.initialPage = 1,
  });

  @override
  State<TextViewScreen> createState() => _TextViewScreenState();
}

class _TextViewScreenState extends State<TextViewScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  final PageController _pageController = PageController();
  
  int _currentPage = 1;
  List<String> _allPagesText = [];
  bool _isLoading = true;
  bool _isPaused = false;
  
  // Para seguir el progreso durante reproducción
  Timer? _progressTimer;
  int _startCursorPosition = 0;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _loadAllPages();
  }

  Future<void> _loadAllPages() async {
    setState(() => _isLoading = true);
    
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    for (int i = 0; i < widget.book.totalPages; i++) {
      final text = await provider.pdfService.extractTextFromPage(
        widget.book.filePath,
        i,
      );
      _allPagesText.add(text);
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (_allPagesText.isNotEmpty) {
          _textController.text = _allPagesText[_currentPage - 1];
        }
      });
      
      // Saltar a la página inicial
      if (_currentPage > 1) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _pageController.jumpToPage(_currentPage - 1);
        });
      }
    }
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page + 1;
      if (page < _allPagesText.length) {
        _textController.text = _allPagesText[page];
      }
    });
    
    final provider = Provider.of<AppProvider>(context, listen: false);
    provider.updateProgress(widget.book.id, page, widget.book.totalPages);
  }

  Future<void> _readFromCursor() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    // Obtener posición del cursor
    final cursorPosition = _textController.selection.baseOffset;
    final startIndex = cursorPosition >= 0 ? cursorPosition : 0;
    
    final currentText = _textController.text;
    if (currentText.isEmpty) return;
    
    final textToRead = currentText.substring(startIndex);
    
    // Iniciar tracking de progreso
    _startCursorPosition = startIndex;
    _startTime = DateTime.now();
    _startProgressTracking();
    
    await provider.speak(textToRead);
    
    // Detener tracking
    _stopProgressTracking();
    
    // LECTURA CONTINUA: Si terminó la página y empezó desde el inicio, avanzar
    if (startIndex == 0 && !_isPaused && _currentPage < widget.book.totalPages && mounted) {
      final isStillPlaying = Provider.of<AppProvider>(context, listen: false).isPlaying;
      
      if (!isStillPlaying) {
        // Avanzar a siguiente página y continuar leyendo
        _currentPage++;
        _pageController.jumpToPage(_currentPage - 1);
        
        // Esperar a que se actualice la página
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Resetear cursor al inicio de la nueva página
        if (mounted && _currentPage <= widget.book.totalPages) {
          _textController.text = _allPagesText[_currentPage - 1];
          _textController.selection = const TextSelection.collapsed(offset: 0);
          
          // Continuar leyendo si no se pausó
          if (!_isPaused) {
            await _readFromCursor();
          }
        }
      }
    }
  }
  
  void _startProgressTracking() {
    _progressTimer?.cancel();
    
    // Actualizar cursor cada 200ms para simular progreso
    _progressTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      // Calcular posición aproximada basada en tiempo
      final provider = Provider.of<AppProvider>(context, listen: false);
      if (!provider.isPlaying) {
        timer.cancel();
        return;
      }
      
      final elapsed = DateTime.now().difference(_startTime!).inMilliseconds;
      final speed = provider.ttsService.speechRate;
      final charsPerMs = (16.0 * speed) / 1000; // ~16 chars/sec
      final charsRead = (elapsed * charsPerMs).toInt();
      final newPosition = (_startCursorPosition + charsRead).clamp(0, _textController.text.length);
      
      if (mounted) {
        setState(() {
          _textController.selection = TextSelection.collapsed(offset: newPosition);
        });
      }
    });
  }
  
  void _stopProgressTracking() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  void _handlePause() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    // Detener tracking de progreso
    _stopProgressTracking();
    
    // El cursor ya está en la posición correcta gracias al tracking
    final cursorPosition = _textController.selection.baseOffset;
    
    provider.setPausedText(_textController.text, cursorPosition >= 0 ? cursorPosition : 0);
    provider.pause();
    setState(() => _isPaused = true);
  }

  Future<void> _handleResume() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    setState(() => _isPaused = false);
    await provider.resume();
  }

  Future<void> _handlePlayOrResume() async {
    if (_isPaused) {
      await _handleResume();
    } else {
      await _readFromCursor();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('${widget.book.title} (Texto)'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Extrayendo texto del PDF...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.book.title} (Texto)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Volver a vista PDF',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _allPagesText.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final isCurrentPage = index == _currentPage - 1;
                return Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    // IMPORTANTE: scroll vertical dentro de cada página
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: TextField(
                      controller: isCurrentPage 
                          ? _textController 
                          : TextEditingController(text: _allPagesText[index]),
                      focusNode: isCurrentPage ? _textFocusNode : null,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onTap: () {
                        if (isCurrentPage) {
                          _textFocusNode.requestFocus();
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          // Indicador de página
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: Colors.grey[200],
            child: Center(
              child: Text(
                'Página $_currentPage de ${widget.book.totalPages}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          // Controles
          ReaderControls(
            isPlaying: context.watch<AppProvider>().isPlaying,
            isTranslating: context.watch<AppProvider>().isTranslating,
            onPlay: _handlePlayOrResume,
            onPause: _handlePause,
            onTranslate: () {}, // No implementado en vista texto
            onAddBookmark: () {}, // No implementado en vista texto
            onChangeVoice: () {}, // No implementado en vista texto
            currentPage: _currentPage,
            totalPages: widget.book.totalPages,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _stopProgressTracking();
    _textController.dispose();
    _textFocusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }
}
