import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pdf_book.dart';
import '../providers/app_provider.dart';

class BookmarksDrawer extends StatefulWidget {
  final PdfBook book;
  final Function(int) onBookmarkTap;

  const BookmarksDrawer({
    super.key,
    required this.book,
    required this.onBookmarkTap,
  });

  @override
  State<BookmarksDrawer> createState() => _BookmarksDrawerState();
}

class _BookmarksDrawerState extends State<BookmarksDrawer> {
  @override
  Widget build(BuildContext context) {
    // Usar Consumer para escuchar cambios en el provider
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        // Obtener libro actualizado del provider
        final updatedBook = provider.books.firstWhere(
          (b) => b.id == widget.book.id,
          orElse: () => widget.book,
        );
        
        return Drawer(
          child: Column(
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.bookmarks, color: Colors.white, size: 40),
                    SizedBox(height: 10),
                    Text(
                      'Marcadores',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: updatedBook.bookmarks.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Text(
                            'No hay marcadores.\nToca el botón + en el lector para añadir uno.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: updatedBook.bookmarks.length,
                        itemBuilder: (context, index) {
                          final bookmark = updatedBook.bookmarks[index];
                          return ListTile(
                            leading: const Icon(Icons.bookmark),
                            title: Text(bookmark.title),
                            subtitle: Text('Página ${bookmark.pageNumber + 1}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                _confirmDelete(context, bookmark.id);
                              },
                            ),
                            onTap: () => widget.onBookmarkTap(bookmark.pageNumber),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String bookmarkId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar marcador'),
        content: const Text('¿Estás seguro de que quieres eliminar este marcador?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await Provider.of<AppProvider>(context, listen: false)
                  .removeBookmark(widget.book.id, bookmarkId);
              if (context.mounted) {
                Navigator.pop(context);
                // Refrescar drawer
                setState(() {});
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
