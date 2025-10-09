import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../models/pdf_book.dart';
import '../providers/app_provider.dart';
import '../widgets/reader_controls.dart';

class TextViewScreen extends StatefulWidget {
  final PdfBook book;
  final int initialPage;
  final List<String>? cachedPages; // Recibir páginas cacheadas
  
  const TextViewScreen({
    super.key,
    required this.book,
    this.initialPage = 1,
    this.cachedPages,
  });

  @override
  State<TextViewScreen> createState() => _TextViewScreenState();
}

class _TextViewScreenState extends State<TextViewScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  
  int _currentPage = 1;
  List<String> _allPagesText = [];
  bool _isLoading = true;
  bool _isPaused = false;
  
  // Para el indicador arrastrable
  double _indicatorY = 16.0;
  
  // Para seguir el progreso durante reproducción
  Timer? _progressTimer;
  int _startCursorPosition = 0;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    
    // Si ya hay páginas cacheadas, usarlas
    if (widget.cachedPages != null && widget.cachedPages!.isNotEmpty) {
      _allPagesText = widget.cachedPages!;
      _updateTextForCurrentPage();
      setState(() => _isLoading = false);
    } else {
      // Inicializar array con páginas vacías
      _allPagesText = List.filled(widget.book.totalPages, '');
      _loadCurrentPage();
    }
  }

  Future<void> _loadCurrentPage() async {
    // Si la página ya está cacheada, no recargar
    if (_allPagesText[_currentPage - 1].isNotEmpty) {
      _updateTextForCurrentPage();
      return;
    }
    
    setState(() => _isLoading = true);
    
    final provider = Provider.of<AppProvider>(context, listen: false);
    final text = await provider.pdfService.extractTextFromPage(
      widget.book.filePath,
      _currentPage - 1,
    );
    
    if (mounted) {
      _allPagesText[_currentPage - 1] = text;
      _updateTextForCurrentPage();
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAllPages() async {
    setState(() => _isLoading = true);
    
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    for (int i = 0; i < widget.book.totalPages; i++) {
      // Solo cargar si no está ya cacheada
      if (_allPagesText[i].isEmpty) {
        final text = await provider.pdfService.extractTextFromPage(
          widget.book.filePath,
          i,
        );
        _allPagesText[i] = text;
      }
    }
    
    if (mounted) {
      _updateTextForCurrentPage();
      setState(() => _isLoading = false);
    }
  }
  
  void _updateTextForCurrentPage() {
    if (_currentPage > 0 && _currentPage <= _allPagesText.length) {
      _textController.text = _allPagesText[_currentPage - 1];
      // Resetear cursor al inicio de la página
      _textController.selection = const TextSelection.collapsed(offset: 0);
    }
  }
  
  void _goToNextPage() {
    if (_currentPage < widget.book.totalPages) {
      setState(() {
        _currentPage++;
      });
      _loadCurrentPage(); // Cargar página si no está cacheada
      _scrollController.jumpTo(0); // Volver arriba
      
      final provider = Provider.of<AppProvider>(context, listen: false);
      provider.updateProgress(widget.book.id, _currentPage - 1, widget.book.totalPages);
    }
  }
  
  void _goToPreviousPage() {
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
      });
      _loadCurrentPage(); // Cargar página si no está cacheada
      _scrollController.jumpTo(0); // Volver arriba
      
      final provider = Provider.of<AppProvider>(context, listen: false);
      provider.updateProgress(widget.book.id, _currentPage - 1, widget.book.totalPages);
    }
  }
  
  void _handleMouseScroll(PointerScrollEvent event) {
    // Detectar scroll con rueda del ratón
    if (event.scrollDelta.dy > 0) {
      // Scroll hacia abajo -> siguiente página
      _goToNextPage();
    } else if (event.scrollDelta.dy < 0) {
      // Scroll hacia arriba -> página anterior
      _goToPreviousPage();
    }
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
        _goToNextPage();
        
        // Esperar a que se actualice
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Continuar leyendo si no se pausó
        if (!_isPaused && mounted) {
          await _readFromCursor();
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

  void _showGoToPageDialog() {
    final TextEditingController pageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Go to page'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1 - ${widget.book.totalPages}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pageController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Enter page number',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                final pageNumber = int.tryParse(value);
                if (pageNumber != null && 
                    pageNumber >= 1 && 
                    pageNumber <= widget.book.totalPages) {
                  Navigator.pop(context);
                  setState(() {
                    _currentPage = pageNumber;
                  });
                  _loadCurrentPage();
                  _scrollController.jumpTo(0);
                  
                  final provider = Provider.of<AppProvider>(context, listen: false);
                  provider.updateProgress(widget.book.id, _currentPage - 1, widget.book.totalPages);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              final pageNumber = int.tryParse(pageController.text);
              if (pageNumber != null && 
                  pageNumber >= 1 && 
                  pageNumber <= widget.book.totalPages) {
                Navigator.pop(context);
                setState(() {
                  _currentPage = pageNumber;
                });
                _loadCurrentPage();
                _scrollController.jumpTo(0);
                
                final provider = Provider.of<AppProvider>(context, listen: false);
                provider.updateProgress(widget.book.id, _currentPage - 1, widget.book.totalPages);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Devolver el cache al salir con el botón back
            Navigator.pop(context, _allPagesText);
          },
        ),
        actions: [
          // Botón de versión
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Versión Modificada'),
                    ],
                  ),
                  content: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lector PDF - Versión Mejorada',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text('✨ Navegación con indicador arrastrable'),
                      SizedBox(height: 8),
                      Text('🖱️ Scroll con rueda del ratón'),
                      SizedBox(height: 8),
                      Text('📄 Paginación real (1 página PDF = 1 página texto)'),
                      SizedBox(height: 8),
                      Text('✅ Carga lazy de páginas'),
                      SizedBox(height: 8),
                      Text('✅ Caché inteligente de páginas visitadas'),
                      SizedBox(height: 8),
                      Text('✅ Vista PDF completamente limpia'),
                      SizedBox(height: 16),
                      Text(
                        'Versión: v22-paginacion-real',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Compilado: Octubre 2025',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Info de versión',
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () {
              // Devolver las páginas cacheadas para no recargar
              Navigator.pop(context, _allPagesText);
            },
            tooltip: 'Volver a vista PDF',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Listener(
                  onPointerSignal: (pointerSignal) {
                    if (pointerSignal is PointerScrollEvent) {
                      _handleMouseScroll(pointerSignal);
                    }
                  },
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Indicador de página en texto
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Página $_currentPage de ${widget.book.totalPages}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          // Texto de la página
                          TextField(
                            controller: _textController,
                            focusNode: _textFocusNode,
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
                              _textFocusNode.requestFocus();
                            },
                          ),
                        ],
                      ),
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
                onTranslate: () {},
                onAddBookmark: () {},
                onChangeVoice: () {},
                currentPage: _currentPage,
                totalPages: widget.book.totalPages,
              ),
            ],
          ),
          // Indicador de página flotante (esquina superior derecha) - NAVEGACIÓN POR ARRASTRE
          Positioned(
            top: _indicatorY,
            right: 16,
            child: GestureDetector(
              onTap: _showGoToPageDialog,
              onVerticalDragUpdate: (details) {
                setState(() {
                  // Mover el indicador
                  _indicatorY += details.delta.dy;
                  
                  // Calcular área disponible para el desplazamiento
                  final screenHeight = MediaQuery.of(context).size.height;
                  final minY = 16.0;
                  final maxY = screenHeight - 200.0; // Dejar espacio para controles
                  final availableHeight = maxY - minY;
                  
                  // Limitar posición del indicador
                  _indicatorY = _indicatorY.clamp(minY, maxY);
                  
                  // Calcular página basada en posición vertical (proporcional)
                  final normalizedPosition = (_indicatorY - minY) / availableHeight;
                  final newPage = (normalizedPosition * (widget.book.totalPages - 1) + 1).round();
                  
                  // Cambiar página si es diferente
                  if (newPage != _currentPage && newPage >= 1 && newPage <= widget.book.totalPages) {
                    _currentPage = newPage;
                    _loadCurrentPage();
                    _scrollController.jumpTo(0);
                    
                    final provider = Provider.of<AppProvider>(context, listen: false);
                    provider.updateProgress(widget.book.id, _currentPage - 1, widget.book.totalPages);
                  }
                });
              },
              onVerticalDragEnd: (details) {
                // Al soltar, ajustar posición del indicador a la página actual
                setState(() {
                  final screenHeight = MediaQuery.of(context).size.height;
                  final minY = 16.0;
                  final maxY = screenHeight - 200.0;
                  final availableHeight = maxY - minY;
                  
                  // Calcular posición Y basada en la página actual
                  final pageProgress = (_currentPage - 1) / (widget.book.totalPages - 1);
                  _indicatorY = minY + (pageProgress * availableHeight);
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '$_currentPage',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
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
    _scrollController.dispose();
    super.dispose();
  }
}
