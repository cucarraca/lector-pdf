import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../models/pdf_book.dart';
import '../providers/app_provider.dart';
import '../services/log_service.dart';
import '../widgets/reader_controls.dart';
import '../widgets/bookmarks_drawer.dart';
import 'logs_screen.dart';

class PdfReaderScreen extends StatefulWidget {
  final PdfBook book;

  const PdfReaderScreen({super.key, required this.book});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final LogService _logger = LogService();
  
  int _currentPage = 1;
  String _currentPageText = '';
  bool _isLoadingText = false;
  bool _isPaused = false;
  bool _isReading = false; // NUEVO: Evitar múltiples lecturas simultáneas
  
  // Para la selección de texto en el overlay
  int _selectedStartIndex = 0;
  
  // Para el cursor animado
  Timer? _cursorTimer;
  Timer? _cursorBlinkTimer;
  bool _cursorBlinkOn = true;
  int _currentCharIndex = 0;

  @override
  void initState() {
    super.initState();
    _pdfViewerController.jumpToPage(widget.book.currentPage + 1);
    _currentPage = widget.book.currentPage + 1;
    _loadCurrentPageText();
  }

  Future<void> _loadCurrentPageText() async {
    if (_isLoadingText) return;
    
    setState(() => _isLoadingText = true);
    
    final provider = Provider.of<AppProvider>(context, listen: false);
    final text = await provider.pdfService.extractTextFromPage(
      widget.book.filePath,
      _currentPage - 1,
    );
    
    if (mounted) {
      setState(() {
        _currentPageText = text;
        _isLoadingText = false;
        _currentCharIndex = 0;
        _selectedStartIndex = 0;
      });
    }
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    setState(() {
      _currentPage = details.newPageNumber;
    });
    
    final provider = Provider.of<AppProvider>(context, listen: false);
    provider.updateProgress(widget.book.id, _currentPage - 1, widget.book.totalPages);
    
    // NO recargar texto si estamos reproduciendo (evita interrupciones)
    if (!provider.isPlaying) {
      _loadCurrentPageText();
    }
  }

  void _onTextTap(TapDownDetails details, BoxConstraints constraints) {
    if (_currentPageText.isEmpty) return;
    
    // Si está reproduciendo, pausar LIMPIAMENTE sin efectos secundarios
    final provider = Provider.of<AppProvider>(context, listen: false);
    final wasPlaying = provider.isPlaying;
    
    if (wasPlaying) {
      _stopCursorAnimation();
      provider.pause();
    }
    
    // Calcular posición aproximada en el texto basándose en dónde se tocó
    final tapY = details.localPosition.dy;
    final totalHeight = constraints.maxHeight;
    
    // Estimación simple: posición vertical determina qué parte del texto
    final relativePosition = tapY / totalHeight;
    final estimatedIndex = (relativePosition * _currentPageText.length).clamp(0, _currentPageText.length - 1).toInt();
    
    setState(() {
      _selectedStartIndex = estimatedIndex;
      _currentCharIndex = estimatedIndex;
      _isPaused = wasPlaying; // Mantener estado de pausa solo si estaba reproduciendo
    });
    
    _logger.log('Reader: Cursor colocado en posición $estimatedIndex (${(relativePosition * 100).toInt()}%)', level: LogLevel.info);
    
    // Mostrar feedback visual suave
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Cursor en ${(relativePosition * 100).toInt()}% del texto'),
        duration: const Duration(milliseconds: 600),
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8),
      ),
    );
  }

  void _startCursorAnimation() {
    // Iniciar parpadeo visible del cursor
    _cursorBlinkTimer?.cancel();
    _cursorBlinkOn = true;
    _cursorBlinkTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) {
        setState(() { _cursorBlinkOn = !_cursorBlinkOn; });
      }
    });
    _stopCursorAnimation();
    
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    // Usar el índice seleccionado
    if (_selectedStartIndex >= 0 && _selectedStartIndex < _currentPageText.length) {
      _currentCharIndex = _selectedStartIndex;
    } else {
      _currentCharIndex = 0;
    }
    
    // Calcular velocidad basada en TTS
    final speed = provider.ttsService.speechRate;
    final charsPerSecond = (16.0 * speed);
    final millisPerChar = (1000 / charsPerSecond).round();
    
    _cursorTimer = Timer.periodic(Duration(milliseconds: millisPerChar), (timer) {
      if (_currentCharIndex < _currentPageText.length && mounted) {
        final isStillPlaying = Provider.of<AppProvider>(context, listen: false).isPlaying;
        
        if (!isStillPlaying) {
          _stopCursorAnimation();
          return;
        }
        
        setState(() {
          _currentCharIndex++;
        });
      } else {
        _stopCursorAnimation();
      }
    });
  }
  
  void _stopCursorAnimation() {
    _cursorTimer?.cancel();
    _cursorTimer = null;
    _cursorBlinkTimer?.cancel();
  }

  Future<void> _readCurrentPage() async {
    // Evitar múltiples llamadas simultáneas
    if (_isReading) {
      _logger.log('Reader: ⚠️ Ya hay una lectura en progreso, ignorando', level: LogLevel.warning);
      debugPrint('⚠️ Reader: Ya hay una lectura en progreso, ignorando');
      return;
    }
    
    _isReading = true;
    
    try {
      _logger.log('Reader: 📖 _readCurrentPage() iniciado - página $_currentPage', level: LogLevel.info);
      debugPrint('📖 Reader: _readCurrentPage() iniciado - página $_currentPage');
      _logger.log('Reader: Texto disponible: ${_currentPageText.length} caracteres', level: LogLevel.info);
      debugPrint('📖 Reader: Texto disponible: ${_currentPageText.length} caracteres');
      debugPrint('📖 Reader: StartIndex: $_selectedStartIndex');
      
      if (_currentPageText.isEmpty) {
        _logger.log('Reader: ⚠️ Texto vacío, no se puede leer', level: LogLevel.warning);
        debugPrint('⚠️ Reader: Texto vacío, no se puede leer');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay texto para leer en esta página')),
          );
        }
        return;
      }

      final provider = Provider.of<AppProvider>(context, listen: false);
      
      // Leer desde la posición seleccionada
      final startIndex = _selectedStartIndex.clamp(0, _currentPageText.length);
      final textToRead = _currentPageText.substring(startIndex);
      
      debugPrint('📖 Reader: Texto a leer: ${textToRead.length} caracteres desde posición $startIndex');
      
      // Iniciar animación del cursor
      _startCursorAnimation();
      
      _logger.log('Reader: Llamando a provider.speak()...', level: LogLevel.info);
      debugPrint('📖 Reader: Llamando a provider.speak()...');
      await provider.speak(textToRead);
      _logger.log('Reader: ✅ provider.speak() completado', level: LogLevel.success);
      debugPrint('📖 Reader: provider.speak() completado');
      
      // Detener animación cuando termine
      _stopCursorAnimation();
      
      debugPrint('📖 Reader: Verificando si debe continuar a siguiente página');
      debugPrint('📖 Reader: StartIndex era 0: ${startIndex == 0}');
      debugPrint('📖 Reader: Página actual: $_currentPage, total: ${widget.book.totalPages}');
      debugPrint('📖 Reader: Mounted: $mounted');
      
      // Avance automático de página SOLO si:
      // 1) Se empezó a leer desde el inicio de la página (startIndex == 0)
      // 2) NO está en pausa (_isPaused == false)
      // 3) Se llegó (o prácticamente llegó) al final del texto (_currentCharIndex >= length - 2)
      // 4) Hay más páginas y el widget sigue montado
      if (startIndex == 0 && !_isPaused && _currentCharIndex >= _currentPageText.length - 2 && _currentPage < widget.book.totalPages && mounted) {
        final isStillPlaying = Provider.of<AppProvider>(context, listen: false).isPlaying;
        debugPrint('📖 Reader: isStillPlaying después de speak: $isStillPlaying');
        
        if (!isStillPlaying) {
          _logger.log('Reader: ✅ Avanzando a siguiente página (fin de página alcanzado)', level: LogLevel.success);
          debugPrint('✅ Reader: Avanzando a siguiente página (fin de página alcanzado)');
          await _goToNextPageAndContinueReading();
        } else {
          debugPrint('⚠️ Reader: No avanza porque isPlaying=true (estado inesperado)');
        }
      } else {
        debugPrint('📖 Reader: NO avanza - startIndex: $startIndex, paused: $_isPaused, char: $_currentCharIndex/${_currentPageText.length}, página: $_currentPage/${widget.book.totalPages}');
      }
    } finally {
      _isReading = false;
    }
  }
  
  Future<void> _goToNextPageAndContinueReading() async {
    debugPrint('➡️ Reader: _goToNextPageAndContinueReading() iniciado');
    debugPrint('➡️ Reader: Página actual: $_currentPage, total: ${widget.book.totalPages}');
    
    if (_currentPage >= widget.book.totalPages) {
      debugPrint('⚠️ Reader: Ya en última página, no avanza');
      return;
    }
    
    // IMPORTANTE: Verificar que todavía se está reproduciendo
    final provider = Provider.of<AppProvider>(context, listen: false);
    if (!provider.isPlaying && !_isPaused) {
      debugPrint('⚠️ Reader: Reproducción detenida por usuario, cancelando avance automático');
      return;
    }
    
    final nextPage = _currentPage + 1;
    debugPrint('➡️ Reader: Saltando a página $nextPage');
    
    // Avanzar página con scroll automático SOLO si está reproduciendo
    _pdfViewerController.jumpToPage(nextPage);
    
    // Esperar a que se actualice la página
    debugPrint('⏳ Reader: Esperando 800ms para scroll del PDF...');
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Verificar de nuevo que no se pausó durante el delay
    if (_isPaused) {
      debugPrint('⚠️ Reader: Pausado durante scroll, cancelando lectura continua');
      return;
    }
    
    // La página se actualizó a través de onPageChanged que llama a _loadCurrentPageText
    // Esperar un poco más para que cargue el texto
    debugPrint('⏳ Reader: Esperando 500ms adicionales para carga de texto...');
    await Future.delayed(const Duration(milliseconds: 500));
    
    debugPrint('📄 Reader: Texto nuevo cargado: ${_currentPageText.length} caracteres');
    debugPrint('📄 Reader: Página después de saltar: $_currentPage');
    
    // Resetear posición de lectura al inicio de la nueva página
    setState(() {
      _selectedStartIndex = 0;
      _currentCharIndex = 0;
    });
    
    debugPrint('📄 Reader: Posiciones reseteadas a 0');
    
    // Continuar leyendo si todavía está en modo reproducción
    if (mounted) {
      debugPrint('📄 Reader: Verificando si continuar - isPlaying: ${provider.isPlaying}, isPaused: $_isPaused');
      debugPrint('📄 Reader: Texto disponible: ${_currentPageText.isNotEmpty}');
      
      if (!provider.isPlaying && !_isPaused && _currentPageText.isNotEmpty) {
        debugPrint('✅ Reader: Continuando lectura en página $_currentPage...');
        await _readCurrentPage();
      } else {
        debugPrint('⚠️ Reader: NO continúa - isPlaying: ${provider.isPlaying}, isPaused: $_isPaused, texto: ${_currentPageText.isNotEmpty}');
      }
    } else {
      debugPrint('⚠️ Reader: Widget no mounted, no continúa');
    }
  }

  void _handlePause() {
    _logger.log('Reader: ⏸️ _handlePause() llamado', level: LogLevel.info);
    debugPrint('⏸️ Reader: _handlePause() llamado');
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    // Detener animación del cursor PERO mantener cursor visible en última posición
    _stopCursorAnimation();
    
    // Guardar posición exacta para resume - cursor en última palabra pronunciada
    _logger.log('Reader: Guardando posición - página: $_currentPage, char: $_currentCharIndex', level: LogLevel.info);
    debugPrint('⏸️ Reader: Guardando posición - página: $_currentPage, char: $_currentCharIndex');
    provider.setPausedText(_currentPageText, _currentCharIndex);
    provider.pause();
    
    setState(() {
      _isPaused = true;
      // Mantener _currentCharIndex donde quedó (última palabra leída)
      // El cursor permanece visible mostrando esa posición
    });
    _logger.log('Reader: ✅ Pausado - cursor visible en posición $_currentCharIndex', level: LogLevel.success);
    debugPrint('⏸️ Reader: Pausado - cursor permanece visible en posición $_currentCharIndex');
  }
  
  Future<void> _handlePlayOrResume() async {
    _logger.log('Reader: ▶️ _handlePlayOrResume() llamado - isPaused: $_isPaused', level: LogLevel.info);
    debugPrint('▶️ Reader: _handlePlayOrResume() llamado - isPaused: $_isPaused');
    if (_isPaused) {
      // Reanudar desde donde se pausó
      _logger.log('Reader: Modo RESUME', level: LogLevel.info);
      debugPrint('▶️ Reader: Modo RESUME');
      await _handleResume();
    } else {
      // Iniciar lectura normal
      _logger.log('Reader: Modo PLAY normal', level: LogLevel.info);
      debugPrint('▶️ Reader: Modo PLAY normal');
      await _readCurrentPage();
    }
  }
  
  Future<void> _handleResume() async {
    _logger.log('Reader: ▶️ _handleResume() iniciado', level: LogLevel.info);
    debugPrint('▶️ Reader: _handleResume() iniciado');
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    setState(() {
      _isPaused = false;
    });
    
    _logger.log('Reader: Llamando a provider.resume()...', level: LogLevel.info);
    debugPrint('▶️ Reader: Llamando a provider.resume()...');
    
    // Continuar desde la posición guardada
    await provider.resume();
    
    debugPrint('▶️ Reader: provider.resume() completado');
    
    // Reanudar animación del cursor
    _startCursorAnimation();
  }

  Future<void> _translateAndRead() async {
    if (_currentPageText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay texto para traducir en esta página')),
      );
      return;
    }

    final provider = Provider.of<AppProvider>(context, listen: false);
    final startIndex = _selectedStartIndex.clamp(0, _currentPageText.length);
    final textToTranslate = _currentPageText.substring(startIndex);
    await provider.translateAndSpeak(textToTranslate);
  }

  Future<void> _addBookmark() async {
    final controller = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo marcador'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Título del marcador',
            hintText: 'Ej: Capítulo importante',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      final provider = Provider.of<AppProvider>(context, listen: false);
      await provider.addBookmark(widget.book.id, _currentPage - 1, result);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marcador añadido')),
        );
      }
    }
  }

  void _showVoiceSelector() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final voices = provider.getAvailableVoices();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar voz'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: voices.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(voices[index]),
                onTap: () {
                  provider.setVoice(voices[index]);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(widget.book.title),
        actions: [
          // Botón de logs
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LogsScreen(),
                ),
              );
            },
            tooltip: 'Ver logs de debug',
          ),
          IconButton(
            icon: const Icon(Icons.bookmark),
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
            tooltip: 'Ver marcadores',
          ),
        ],
      ),
      endDrawer: BookmarksDrawer(
        book: widget.book,
        onBookmarkTap: (pageNumber) {
          _pdfViewerController.jumpToPage(pageNumber + 1);
          Navigator.pop(context);
        },
      ),
      body: Column(
        children: [
          // Contenido principal: PDF con overlay de texto
          Expanded(
            child: _buildPdfWithOverlay(),
          ),
          // Controles de reproducción
          ReaderControls(
            isPlaying: context.watch<AppProvider>().isPlaying,
            isTranslating: context.watch<AppProvider>().isTranslating,
            onPlay: _handlePlayOrResume,
            onPause: _handlePause,
            onTranslate: _translateAndRead,
            onAddBookmark: _addBookmark,
            onChangeVoice: _showVoiceSelector,
            currentPage: _currentPage,
            totalPages: widget.book.totalPages,
          ),
        ],
      ),
    );
  }

  Widget _buildPdfWithOverlay() {
    return Stack(
      children: [
        // Capa 1: El visor PDF
        SfPdfViewer.file(
          File(widget.book.filePath),
          controller: _pdfViewerController,
          onPageChanged: _onPageChanged,
        ),
        
        // Capa 2: Captura tap simple para colocar cursor SIN bloquear scroll/zoom
        if (_currentPageText.isNotEmpty)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Listener(
                  behavior: HitTestBehavior.deferToChild,
                  onPointerDown: (evt) {
                    if (evt.kind == PointerDeviceKind.touch) {
                      // Solo registrar tap corto: convertimos a TapDown manual aproximado
                      final details = TapDownDetails(
                        localPosition: evt.localPosition,
                      );
                      _onTextTap(details, constraints);
                    }
                  },
                  child: IgnorePointer(
                    ignoring: true, // No consume gestos de scroll del visor PDF
                    child: Container(color: Colors.transparent),
                  ),
                );
              },
            ),
          ),
        
        // Cursor visible dibujado sobre el PDF
        if (_currentPageText.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _CursorPainter(
                  text: _currentPageText,
                  charIndex: _currentCharIndex.clamp(0, _currentPageText.length - 1),
                  visible: _cursorBlinkOn || context.watch<AppProvider>().isPlaying == true,
                ),
              ),
            ),
          ),
        // Indicador de página
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: IgnorePointer( // <-- NUEVO: No bloquear gestos del PDF
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.picture_as_pdf,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Página $_currentPage de ${widget.book.totalPages}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        
        // Hint para el usuario (solo aparece si no está reproduciendo)
        if (!context.watch<AppProvider>().isPlaying && !_isPaused)
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: IgnorePointer( // <-- NUEVO: No bloquear gestos del PDF
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Toca el PDF para seleccionar desde dónde leer',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

class _CursorPainter extends CustomPainter {
  final String text;
  final int charIndex;
  final bool visible;
  _CursorPainter({required this.text, required this.charIndex, required this.visible});
  @override
  void paint(Canvas canvas, Size size) {
    if (!visible) return;
    if (text.isEmpty) return;
    // Aproximación: colocar cursor vertical según proporción del índice dentro del texto
    final ratio = text.isEmpty ? 0.0 : (charIndex / text.length).clamp(0.0, 1.0);
    final y = ratio * size.height;
    final paint = Paint()
      ..color = const Color(0xFFE91E63)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(size.width * 0.02, y), Offset(size.width * 0.12, y), paint);
  }
  @override
  bool shouldRepaint(covariant _CursorPainter old) {
    return old.charIndex != charIndex || old.visible != visible || old.text != text;
  }
}

          ),
        
        // Indicador de carga
        if (_isLoadingText)
          const Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    _stopCursorAnimation();
    super.dispose();
  }
}
