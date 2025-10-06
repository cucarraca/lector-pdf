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
  bool _isReading = false;
  
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();

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
        _textController.text = text;
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

  void _onTextTap() {
    // Al hacer tap, el TextField maneja la posición del cursor automáticamente
    // Solo guardamos el índice cuando el usuario lo mueva
    _textFocusNode.requestFocus();
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
      
      // Obtener posición del cursor en el TextField
      final cursorPosition = _textController.selection.baseOffset;
      final startIndex = cursorPosition >= 0 ? cursorPosition : 0;
      final textToRead = _currentPageText.substring(startIndex);
      
      debugPrint('📖 Reader: Leyendo desde posición de cursor: $startIndex');
      debugPrint('📖 Reader: Texto a leer: ${textToRead.length} caracteres');
      
      await provider.speak(textToRead);
      _logger.log('Reader: ✅ provider.speak() completado', level: LogLevel.success);
      debugPrint('📖 Reader: provider.speak() completado');
      
      // Avance automático si empezó desde el inicio
      if (startIndex == 0 && !_isPaused && _currentPage < widget.book.totalPages && mounted) {
        final isStillPlaying = Provider.of<AppProvider>(context, listen: false).isPlaying;
        
        if (!isStillPlaying) {
          _logger.log('Reader: ✅ Avanzando a siguiente página', level: LogLevel.success);
          await _goToNextPageAndContinueReading();
        }
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
      _textController.selection = const TextSelection.collapsed(offset: 0);
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
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    // Obtener posición actual del cursor
    final cursorPosition = _textController.selection.baseOffset;
    
    _logger.log('Reader: Guardando posición - página: $_currentPage, cursor: $cursorPosition', level: LogLevel.info);
    
    provider.setPausedText(_currentPageText, cursorPosition >= 0 ? cursorPosition : 0);
    provider.pause();
    
    setState(() {
      _isPaused = true;
    });
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
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    setState(() {
      _isPaused = false;
    });
    
    await provider.resume();
  }

  Future<void> _translateAndRead() async {
    if (_currentPageText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay texto para traducir en esta página')),
      );
      return;
    }

    final provider = Provider.of<AppProvider>(context, listen: false);
    final cursorPosition = _textController.selection.baseOffset;
    final startIndex = cursorPosition >= 0 ? cursorPosition : 0;
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
        // Capa 1: El visor PDF (fondo)
        SfPdfViewer.file(
          File(widget.book.filePath),
          controller: _pdfViewerController,
          onPageChanged: _onPageChanged,
        ),
        
        // Capa 2: TextField con el texto extraído y cursor manejable
        if (_currentPageText.isNotEmpty)
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.95), // Fondo semi-opaco para ver el texto
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: TextField(
                  controller: _textController,
                  focusNode: _textFocusNode,
                  maxLines: null,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  readOnly: false, // Permitir mover el cursor
                  onTap: _onTextTap,
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
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }
}
