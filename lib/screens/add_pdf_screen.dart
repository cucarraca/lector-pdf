import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/pdf_book.dart';
import '../providers/app_provider.dart';

class AddPdfScreen extends StatefulWidget {
  const AddPdfScreen({super.key});

  @override
  State<AddPdfScreen> createState() => _AddPdfScreenState();
}

class _AddPdfScreenState extends State<AddPdfScreen> {
  bool _isLoading = false;

  Future<void> _pickPdf() async {
    try {
      setState(() => _isLoading = true);

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        final provider = Provider.of<AppProvider>(context, listen: false);
        
        final pageCount = await provider.pdfService.getPageCount(file.path!);
        
        final book = PdfBook(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: file.name.replaceAll('.pdf', ''),
          filePath: file.path!,
          totalPages: pageCount,
          lastOpened: DateTime.now(),
        );

        await provider.addBook(book);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF añadido correctamente')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al añadir PDF: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Añadir PDF'),
      ),
      body: Center(
        child: _isLoading
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Procesando PDF...'),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.upload_file,
                    size: 100,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _pickPdf,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Seleccionar PDF'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Selecciona un archivo PDF de tu dispositivo',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
