import 'package:flutter/material.dart';

class ReaderControls extends StatelessWidget {
  final bool isPlaying;
  final bool isTranslating;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onTranslate;
  final VoidCallback onAddBookmark;
  final VoidCallback onChangeVoice;
  final int currentPage;
  final int totalPages;

  const ReaderControls({
    super.key,
    required this.isPlaying,
    required this.isTranslating,
    required this.onPlay,
    required this.onPause,
    required this.onTranslate,
    required this.onAddBookmark,
    required this.onChangeVoice,
    required this.currentPage,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Página $currentPage de $totalPages',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.bookmark_add),
                onPressed: onAddBookmark,
                tooltip: 'Añadir marcador',
                iconSize: 28,
              ),
              IconButton(
                icon: const Icon(Icons.record_voice_over),
                onPressed: onChangeVoice,
                tooltip: 'Cambiar voz',
                iconSize: 28,
              ),
              IconButton(
                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: isPlaying ? onPause : onPlay,
                tooltip: isPlaying ? 'Pausar' : 'Reproducir',
                iconSize: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
              IconButton(
                icon: isTranslating
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.translate),
                onPressed: isTranslating ? null : onTranslate,
                tooltip: 'Traducir al español',
                iconSize: 28,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
