import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/library_grid.dart';
import '../widgets/theme_selector.dart';
import '../services/log_service.dart';
import 'add_pdf_screen.dart';
import 'logs_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lector PDF'),
        actions: [
          // Botón de Logs con badge
          ValueListenableBuilder<int>(
            valueListenable: LogService().logCountNotifier,
            builder: (context, logCount, child) {
              return Stack(
                children: [
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
                  if (logCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          logCount > 99 ? '99+' : '$logCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.palette),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const ThemeSelector(),
              );
            },
            tooltip: 'Cambiar tema',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              _showSettings(context);
            },
            tooltip: 'Configuración',
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          if (provider.books.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.picture_as_pdf,
                    size: 100,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No hay PDFs en tu biblioteca',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Toca el botón + para añadir tu primer PDF',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }
          return const LibraryGrid();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPdfScreen()),
          );
        },
        child: const Icon(Icons.add),
        tooltip: 'Añadir PDF',
      ),
    );
  }

  void _showSettings(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configuración',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            Text('Tamaño de fuente: ${provider.fontSize.toStringAsFixed(0)}'),
            Slider(
              value: provider.fontSize,
              min: 12,
              max: 24,
              divisions: 12,
              label: provider.fontSize.toStringAsFixed(0),
              onChanged: (value) {
                provider.setFontSize(value);
              },
            ),
            const SizedBox(height: 10),
            Text('Velocidad de lectura: ${provider.speechRate.toStringAsFixed(2)}'),
            Slider(
              value: provider.speechRate,
              min: 0.1,
              max: 1.0,
              divisions: 9,
              label: provider.speechRate.toStringAsFixed(2),
              onChanged: (value) {
                provider.setSpeechRate(value);
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }
}
