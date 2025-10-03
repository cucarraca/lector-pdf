import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/app_theme.dart';

class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seleccionar tema'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: AppThemes.themeNames.length,
          itemBuilder: (context, index) {
            final themeName = AppThemes.themeNames[index];
            final theme = AppThemes.getTheme(themeName);
            
            return Consumer<AppProvider>(
              builder: (context, provider, child) {
                final isSelected = provider.currentTheme == themeName;
                
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.themeData.colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                    ),
                  ),
                  title: Text(theme.name),
                  trailing: isSelected ? const Icon(Icons.check) : null,
                  onTap: () {
                    provider.setTheme(themeName);
                    Navigator.pop(context);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
