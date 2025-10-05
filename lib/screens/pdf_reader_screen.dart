import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../models/pdf_book.dart';
import '../providers/app_provider.dart';
import '../widgets/reader_controls.dart';
import '../widgets/bookmarks_drawer.dart';

enum ViewMode { pdf, text }

class PdfReaderScreen extends StatefulWidget {
  final PdfBook book;

  const PdfReaderScreen({super.key, required this.book});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _textEditingController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  final ScrollController _textScrollController = ScrollController();
  
  int _currentPage = 1;
  String _fullPdfText = ''; // Texto completo del PDF
  bool _isLoadingText = false;
  ViewMode _viewMode = ViewMode.pdf;
  double _loadingProgress = 0.0; // Progreso de carga 0.0 a 1.0
  
  // Para el cursor animado
  Timer? _cursorTimer;
  int _currentCharIndex = 0;

  @override
  void initState() {
    super.initState();
    _pdfViewerController.jumpToPage(widget.book.currentPage + 1);
    _currentPage = widget.book.currentPage + 1;
    _loadAllPdfText(); // Cargar TODO el texto del PDF
  }

  Future<void> _loadAllPdfText() async {
    if (_isLoadingText) return;
    
    setState(() {
      _isLoadingText = true;
      _loadingProgress = 0.0;
    });
    
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    try {
      // Obtener total de páginas
      final totalPages = widget.book.totalPages;
      final StringBuffer fullText = StringBuffer();
      
      // Cargar página por página con progreso
      for (int i = 0; i < totalPages; i++) {
        final pageText = await provider.pdfService.extractTextFromPage(
          widget.book.filePath,
          i,
        );
        
        fullText.write(pageText);
        if (i < totalPages - 1) {
          fullText.write('\n\n--- Página ${i + 2} ---\n\n'); // Separador entre páginas
        }
        
        // Actualizar progreso
        if (mounted) {
          setState(() {
            _loadingProgress = (i + 1) / totalPages;
          });
        }
      }
      
      if (mounted) {
        setState(() {
          _fullPdfText = fullText.toString();
          _textEditingController.text = _fullPdfText;
          _isLoadingText = false;
          _loadingProgress = 1.0;
          // Colocar el cursor al inicio
          _currentCharIndex = 0;
          _textEditingController.selection = TextSelection.fromPosition(
            const TextPosition(offset: 0),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingText = false;
          _loadingProgress = 0.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar el texto: $e')),
        );
      }
    }
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    setState(() {
      _currentPage = details.newPageNumber;
    });
    
    final provider = Provider.of<AppProvider>(context, listen: false);
    provider.updateProgress(widget.book.id, _currentPage - 1, widget.book.totalPages);
    
    // Ya NO recargamos el texto porque tenemos todo el PDF cargado
  }

  void _startCursorAnimation() {
    _stopCursorAnimation();
    
    final provider = Provider.of<AppProvider>(context, listen: false);
    final cursorPosition = _textEditingController.selection.baseOffset;
    
    if (cursorPosition < 0 || cursorPosition >= _fullPdfText.length) {
      _currentCharIndex = 0;
    } else {
      _currentCharIndex = cursorPosition;
    }
    
    // Asegurar que el TextField mantenga el foco y el cursor sea visible
    if (!_textFocusNode.hasFocus) {
      _textFocusNode.requestFocus();
    }
    
    // Calcular velocidad aproximada de lectura basada en la velocidad del TTS
    final speed = provider.ttsService.speechRate;
    // A velocidad 0.5 (~100 palabras/min) = ~8 caracteres/seg
    // A velocidad 1.0 (~200 palabras/min) = ~16 caracteres/seg
    final charsPerSecond = (16.0 * speed);
    final millisPerChar = (1000 / charsPerSecond).round();
    
    _cursorTimer = Timer.periodic(Duration(milliseconds: millisPerChar), (timer) {
      if (_currentCharIndex < _fullPdfText.length && mounted) {
        // Verificar si todavía estamos reproduciendo
        final isStillPlaying = Provider.of<AppProvider>(context, listen: false).isPlaying;
        
        if (!isStillPlaying) {
          _stopCursorAnimation();
          return;
        }
        
        setState(() {
          _currentCharIndex++;
          _textEditingController.selection = TextSelection.fromPosition(
            TextPosition(offset: _currentCharIndex),
          );
          
          // Auto-scroll para seguir el cursor
          if (_textScrollController.hasClients) {
            final lineHeight = 16 * 1.6; // fontSize * height
            final scrollPosition = (_currentCharIndex / _fullPdfText.length) * 
                                   (_fullPdfText.length * lineHeight / 50);
            _textScrollController.animateTo(
              scrollPosition,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      } else {
        _stopCursorAnimation();
      }
    });
  }
  
  void _stopCursorAnimation() {
    _cursorTimer?.cancel();
    _cursorTimer = null;
  }

  Future<void> _readCurrentPage() async {
    if (_fullPdfText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay texto para leer. Espera a que termine de cargar.')),
      );
      return;
    }

    final provider = Provider.of<AppProvider>(context, listen: false);
    
    // Obtener posición del cursor
    final cursorPosition = _textEditingController.selection.baseOffset;
    final startIndex = cursorPosition >= 0 && cursorPosition < _fullPdfText.length 
        ? cursorPosition 
        : 0;
    
    // Leer desde la posición del cursor
    final textToRead = _fullPdfText.substring(startIndex);
    
    // Iniciar animación del cursor
    _startCursorAnimation();
    
    await provider.speak(textToRead);
    
    // Detener animación cuando termine
    _stopCursorAnimation();
  }

  void _handleStop() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    _stopCursorAnimation();
    provider.stop();
    
    // El cursor queda donde estaba (no se resetea)
    // Asegurarnos de que el estado se actualice
    if (mounted) {
      setState(() {});
    }
  }

  void _handlePause() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    provider.pause();
    _stopCursorAnimation();
  }

  Future<void> _translateAndRead() async {
    if (_fullPdfText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay texto para traducir. Espera a que termine de cargar.')),
      );
      return;
    }

    final provider = Provider.of<AppProvider>(context, listen: false);
    
    // Obtener posición del cursor
    final cursorPosition = _textEditingController.selection.baseOffset;
    final startIndex = cursorPosition >= 0 && cursorPosition < _fullPdfText.length 
        ? cursorPosition 
        : 0;
    
    // Traducir y leer desde la posición del cursor
    final textToTranslate = _fullPdfText.substring(startIndex);
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

    if (result != null && result.isNotEmpty) {
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
          // Botones de cambio de modo
          SegmentedButton<ViewMode>(
            segments: const [
              ButtonSegment<ViewMode>(
                value: ViewMode.pdf,
                label: Text('PDF'),
                icon: Icon(Icons.picture_as_pdf, size: 18),
              ),
              ButtonSegment<ViewMode>(
                value: ViewMode.text,
                label: Text('Texto'),
                icon: Icon(Icons.text_fields, size: 18),
              ),
            ],
            selected: {_viewMode},
            onSelectionChanged: (Set<ViewMode> newSelection) {
              setState(() {
                _viewMode = newSelection.first;
                if (_viewMode == ViewMode.text) {
                  // Dar foco al texto cuando cambiamos a modo texto
                  Future.delayed(const Duration(milliseconds: 100), () {
                    _textFocusNode.requestFocus();
                  });
                }
              });
            },
            style: ButtonStyle(
              padding: MaterialStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
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
          // Contenido principal según el modo seleccionado
          Expanded(
            child: _viewMode == ViewMode.pdf ? _buildPdfView() : _buildTextView(),
          ),
          // Controles de reproducción
          ReaderControls(
            isPlaying: context.watch<AppProvider>().isPlaying,
            isTranslating: context.watch<AppProvider>().isTranslating,
            onPlay: _readCurrentPage,
            onPause: _handlePause,
            onStop: _handleStop,
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

  Widget _buildPdfView() {
    return Stack(
      children: [
        SfPdfViewer.file(
          File(widget.book.filePath),
          controller: _pdfViewerController,
          onPageChanged: _onPageChanged,
        ),
        // Indicador de página
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
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
        // Hint para cambiar a modo texto
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.white,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Toca "Texto" arriba para seleccionar desde dónde leer',
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
      ],
    );
  }

  Widget _buildTextView() {
    return Container(
      color: Theme.of(context).cardColor,
      child: _isLoadingText
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando texto del PDF...',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(_loadingProgress * 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 200,
                    child: LinearProgressIndicator(
                      value: _loadingProgress,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : _fullPdfText.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.text_fields,
                          size: 48,
                          color: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.color
                              ?.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No se pudo extraer texto del PDF',
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.text_snippet, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Texto Completo del PDF',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          Text(
                            '${_fullPdfText.length} caracteres',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    // Campo de texto con cursor
                    Expanded(
                      child: Scrollbar(
                        controller: _textScrollController,
                        thumbVisibility: true,
                        child: GestureDetector(
                          onTapDown: (details) {
                            // Solicitar foco sin mostrar teclado
                            _textFocusNode.requestFocus();
                          },
                          child: SingleChildScrollView(
                            controller: _textScrollController,
                            padding: const EdgeInsets.all(16),
                            child: TextField(
                              controller: _textEditingController,
                              focusNode: _textFocusNode,
                              maxLines: null,
                              readOnly: false,
                              showCursor: true,
                              enableInteractiveSelection: true,
                              cursorColor: Theme.of(context).colorScheme.primary,
                              cursorWidth: 2.0,
                              cursorHeight: 24.0,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                height: 1.6,
                                fontSize: 16,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Coloca el cursor donde quieras empezar...',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Footer con hint
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        border: Border(
                          top: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.touch_app, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Toca el texto para colocar el cursor y presiona Play',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    _textEditingController.dispose();
    _textFocusNode.dispose();
    _textScrollController.dispose();
    _stopCursorAnimation();
    super.dispose();
  }
}
