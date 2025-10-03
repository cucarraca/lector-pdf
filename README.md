# Lector PDF - Aplicación Flutter con TTS y Traducción

![Flutter](https://img.shields.io/badge/Flutter-3.9.0-blue)
![License](https://img.shields.io/badge/License-MIT-green)

Una aplicación completa de lectura de PDF con funcionalidades de texto a voz (TTS), traducción automática y gestión de biblioteca personal.

## 🚀 Características

### Versión 1.0 (Implementadas)

#### 📚 Gestión de PDFs
- **Selección de archivos PDF** desde el dispositivo
- **Visualización profesional** de documentos PDF
- **Biblioteca personalizada** con vista de estantería
- **Historial de lectura** automático
- **Progreso de lectura** guardado por cada libro

#### 🔊 Lectura en Voz Alta
- **Text-to-Speech (TTS)** integrado con múltiples voces
- **Lectura desde cursor** - comienza exactamente donde quieras
- **Control de reproducción**: Play, Pausa, Stop
- **Velocidad ajustable** de lectura
- **Selector de voces** disponibles en el dispositivo
- **Soporte offline** con motor TTS local

#### 🌍 Traducción Automática
- **Detección automática** de idioma del PDF
- **Traducción a español** con un toque
- **Lectura en español** del contenido traducido
- **Indicador visual** durante la traducción

#### 🎨 Personalización Visual
- **5 Temas oscuros** incluidos:
  - 🧛 Drácula (morado y rosa)
  - 🌲 Bosque (verde oscuro)
  - 🌙 Medianoche (azul oscuro)
  - 🎨 Monokai (clásico de programación)
  - 🕳️ Abismo (negro profundo)
- **Tamaño de fuente ajustable** (12-24px)
- **Contraste optimizado** para accesibilidad

#### 🔖 Marcadores y Navegación
- **Guardar marcadores** en cualquier página
- **Organización de marcadores** con títulos personalizados
- **Navegación rápida** entre marcadores
- **Eliminación fácil** de marcadores

#### ⚙️ Configuración
- **Ajuste de velocidad de lectura** (0.1x - 1.0x)
- **Personalización de fuente** para mejor legibilidad
- **Cambio de tema** en tiempo real
- **Persistencia** de configuraciones

## 📦 Instalación

### Prerrequisitos
- Flutter SDK 3.9.0 o superior
- Android Studio / VS Code
- Dispositivo Android o emulador

### Pasos

1. **Clonar el repositorio**
```bash
git clone https://github.com/tu-usuario/lector_pdf.git
cd lector_pdf
```

2. **Instalar dependencias**
```bash
flutter pub get
```

3. **Ejecutar la aplicación**
```bash
flutter run
```

4. **Compilar APK**
```bash
flutter build apk --release
```

El APK estará en: `build/app/outputs/flutter-apk/app-release.apk`

## 🏗️ Estructura del Proyecto

```
lib/
├── main.dart              # Punto de entrada
├── models/                # Modelos de datos
│   ├── pdf_book.dart     # Modelo de libro PDF
│   ├── pdf_book.g.dart   # Generado (JSON)
│   └── app_theme.dart    # Definición de temas
├── services/              # Servicios de negocio
│   ├── tts_service.dart          # Text-to-Speech
│   ├── translation_service.dart  # Traducción
│   ├── pdf_service.dart          # Procesamiento PDF
│   └── storage_service.dart      # Almacenamiento local
├── providers/             # Gestión de estado
│   └── app_provider.dart # Provider principal
├── screens/               # Pantallas
│   ├── home_screen.dart        # Biblioteca
│   ├── add_pdf_screen.dart     # Selector PDF
│   └── pdf_reader_screen.dart  # Lector PDF
└── widgets/               # Widgets reutilizables
    ├── library_grid.dart       # Grilla de libros
    ├── theme_selector.dart     # Selector de temas
    ├── reader_controls.dart    # Controles del lector
    └── bookmarks_drawer.dart   # Cajón de marcadores
```

## 🛠️ Tecnologías Utilizadas

### Dependencias Principales
- **syncfusion_flutter_pdfviewer**: Visualización de PDFs
- **syncfusion_flutter_pdf**: Extracción de texto
- **flutter_tts**: Text-to-Speech
- **translator**: Traducción automática
- **file_picker**: Selector de archivos
- **provider**: Gestión de estado
- **shared_preferences**: Almacenamiento local
- **path_provider**: Acceso a directorios

## 📱 Uso de la Aplicación

### 1. Añadir un PDF
- Toca el botón `+` en la pantalla principal
- Selecciona un archivo PDF de tu dispositivo
- El libro aparecerá automáticamente en tu biblioteca

### 2. Leer un PDF
- Toca cualquier libro de tu biblioteca
- Navega por las páginas con gestos
- Usa los controles inferiores para:
  - ▶️ **Reproducir**: Lee la página actual en voz alta
  - ⏸️ **Pausar**: Detiene temporalmente la lectura
  - ⏹️ **Detener**: Detiene completamente la lectura
  - 🗣️ **Cambiar voz**: Selecciona otra voz disponible
  - 🌍 **Traducir**: Traduce y lee en español
  - 🔖 **Añadir marcador**: Guarda la página actual

### 3. Gestionar Marcadores
- Abre el cajón lateral derecho (icono 🔖)
- Toca un marcador para ir directamente a esa página
- Elimina marcadores deslizando o tocando el icono de papelera

### 4. Personalizar Apariencia
- Toca el icono de paleta (🎨) en la barra superior
- Selecciona tu tema favorito
- Accede a Configuración (⚙️) para ajustar:
  - Tamaño de fuente
  - Velocidad de lectura

## 🚧 Mejoras Futuras (Roadmap)

### Próximas Versiones
- [ ] **Sincronización palabra por palabra** durante la lectura
- [ ] **Notas y comentarios** vinculados a fragmentos del PDF
- [ ] **Exportación a audio MP3** de páginas o capítulos
- [ ] **Integración con la nube** (Google Drive, Dropbox)
- [ ] **Estadísticas de lectura** (tiempo, páginas, velocidad)
- [ ] **Tabla de contenidos interactiva**
- [ ] **Modo de lectura nocturno mejorado**
- [ ] **Soporte para EPUB**
- [ ] **Audiolibros híbridos** (sincronización texto-audio)

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Por favor:
1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver `LICENSE` para más información.

## 👥 Autor

Desarrollado con ❤️ para la comunidad Flutter

## 🙏 Agradecimientos

- Syncfusion por sus excelentes librerías de PDF
- Comunidad Flutter por el soporte continuo
- Contribuidores y testers

---

**¿Disfrutas de esta aplicación? Dale una ⭐ en GitHub!**

