# 📱 Cómo Usar APK v11 con Logs de Debug

## 🎯 Objetivo de v11

Esta versión tiene **50+ puntos de logging** para descubrir exactamente qué está fallando con Play/Pause y el scroll automático.

═══════════════════════════════════════════════════════════════════════

## 🔧 PASO 1: Preparar el Dispositivo

### Habilitar Depuración USB:
1. Abre **Ajustes** en tu Samsung S22 Ultra
2. Ve a **Acerca del teléfono**
3. Toca **Número de compilación** 7 veces (se activa modo desarrollador)
4. Vuelve a **Ajustes** → **Opciones de desarrollo**
5. Activa **Depuración USB**

### Conectar por USB:
```bash
# Verificar conexión
adb devices
```

Debería aparecer tu dispositivo.

═══════════════════════════════════════════════════════════════════════

## 📥 PASO 2: Instalar APK v11

```bash
cd lector_pdf/descargas_apk
adb install -r lector-pdf-v11-debug-logs.apk
```

═══════════════════════════════════════════════════════════════════════

## 🔍 PASO 3: Capturar Logs Mientras Usas la App

### Opción A: Ver TODOS los logs en tiempo real
```bash
adb logcat | grep -E "TTS|Reader|Provider"
```

### Opción B: Guardar logs en archivo
```bash
adb logcat | grep -E "TTS|Reader|Provider" > logs_lector_pdf.txt
```

### Opción C: Solo errores
```bash
adb logcat | grep "❌"
```

### Opción D: Solo reproducción (Play/Pause)
```bash
adb logcat | grep -E "▶️|⏸️|⏹️"
```

### Opción E: Solo scroll automático
```bash
adb logcat | grep "➡️"
```

═══════════════════════════════════════════════════════════════════════

## 🧪 PASO 4: Reproducir los Problemas

### Prueba 1: Play/Pause
1. Abre un PDF en la app
2. Presiona **Play** ▶️
3. **Observa los logs** - deberías ver:
   ```
   ▶️ Reader: _handlePlayOrResume() llamado
   📖 Reader: _readCurrentPage() iniciado
   🎤 TTS: Iniciando reproducción...
   ```
4. Espera 10 segundos
5. Presiona **Pause** ⏸️
6. **Observa los logs** - deberías ver:
   ```
   ⏸️ Reader: _handlePause() llamado
   ⏸️ TTS: Pausando reproducción
   ```
7. Presiona **Play** ▶️ de nuevo
8. **Observa los logs** - deberías ver:
   ```
   ▶️ Reader: Modo RESUME
   ▶️ TTS: Reanudando desde posición X
   ```

### Prueba 2: Scroll Automático
1. Abre un PDF de 5+ páginas
2. Ve a página 1
3. Presiona **Play** ▶️
4. **Observa los logs** - deberías ver algo como:
   ```
   📖 Reader: _readCurrentPage() iniciado - página 1
   🎤 TTS: Iniciando reproducción de 523 caracteres
   ▶️ TTS: Reproducción iniciada
   ... [espera mientras lee] ...
   ✅ TTS: Reproducción completada
   📖 Reader: Verificando si debe continuar
   ✅ Reader: Avanzando a siguiente página...
   ➡️ Reader: Saltando a página 2
   ⏳ Reader: Esperando 800ms...
   📄 Reader: Texto nuevo cargado: 489 caracteres
   ✅ Reader: Continuando lectura en página 2...
   ```

═══════════════════════════════════════════════════════════════════════

## 📝 PASO 5: Compartir los Logs

### Copiar logs completos:
```bash
adb logcat -d | grep -E "TTS|Reader|Provider" > logs_completos.txt
```

Esto guarda TODO el log en `logs_completos.txt`.

### Enviarme el archivo:
Puedes pegarme el contenido del archivo o los últimos 100 líneas:
```bash
tail -100 logs_completos.txt
```

═══════════════════════════════════════════════════════════════════════

## 🔎 Qué Buscar en los Logs

### ✅ Comportamiento CORRECTO para Play/Pause:

**Al presionar Play:**
```
▶️ Reader: _handlePlayOrResume() llamado - isPaused: false
▶️ Reader: Modo PLAY normal
📖 Reader: _readCurrentPage() iniciado - página 1
📖 Reader: Texto disponible: 523 caracteres
🎤 TTS: Iniciando reproducción de 523 caracteres
▶️ TTS: Reproducción iniciada
```

**Al presionar Pause:**
```
⏸️ Reader: _handlePause() llamado
⏸️ Reader: Guardando posición - página: 1, char: 156
💾 TTS: Posición guardada: 156 de 523 caracteres
⏸️ TTS: Pausando reproducción
⏸️ Reader: Pausado - estado guardado
```

**Al presionar Play después de Pause (Resume):**
```
▶️ Reader: _handlePlayOrResume() llamado - isPaused: true
▶️ Reader: Modo RESUME
▶️ Reader: _handleResume() iniciado
📢 Provider: resume() llamado
▶️ TTS: Reanudando desde posición 156
▶️ TTS: Reproduciendo 367 caracteres restantes
▶️ TTS: Reproducción iniciada
```

---

### ✅ Comportamiento CORRECTO para Scroll Automático:

**Al terminar página 1:**
```
✅ TTS: Reproducción completada
📖 Reader: provider.speak() completado
📖 Reader: Verificando si debe continuar a siguiente página
📖 Reader: StartIndex era 0: true
📖 Reader: Página actual: 1, total: 5
📖 Reader: isStillPlaying después de speak: false  ← IMPORTANTE: debe ser false
✅ Reader: Avanzando a siguiente página...
➡️ Reader: _goToNextPageAndContinueReading() iniciado
➡️ Reader: Saltando a página 2
⏳ Reader: Esperando 800ms para scroll del PDF...
⏳ Reader: Esperando 500ms adicionales para carga de texto...
📄 Reader: Texto nuevo cargado: 489 caracteres  ← Debe tener texto
📄 Reader: Página después de saltar: 2
📄 Reader: Verificando si continuar - isPlaying: false  ← Debe ser false
✅ Reader: Continuando lectura en página 2...
📖 Reader: _readCurrentPage() iniciado - página 2
```

---

### ❌ Comportamiento INCORRECTO (lo que buscar):

**Problema 1: speak() termina inmediatamente**
```
🎤 TTS: Iniciando reproducción de 523 caracteres
📖 Reader: provider.speak() completado  ← ¡Aparece INMEDIATAMENTE!
```
→ Significa que no está esperando realmente al TTS

**Problema 2: isPlaying no se actualiza**
```
📖 Reader: isStillPlaying después de speak: true  ← ¡Debería ser false!
⚠️ Reader: No avanza porque isPlaying=true (extraño)
```
→ El estado no se actualiza correctamente

**Problema 3: Texto no carga**
```
📄 Reader: Texto nuevo cargado: 0 caracteres  ← ¡Sin texto!
⚠️ Reader: NO continúa - isPlaying: false, texto: false
```
→ La página nueva no cargó su texto

**Problema 4: Resume desde inicio**
```
⏸️ Reader: Guardando posición - página: 1, char: 0  ← ¡Debería ser > 0!
```
→ El cursor no se está moviendo

═══════════════════════════════════════════════════════════════════════

## 🎯 Emojis Usados en los Logs

- 🔧 = Inicialización
- ▶️ = Play/Resume
- ⏸️ = Pause
- ⏹️ = Stop
- 🎤 = TTS reproduciendo
- ✅ = Completado exitosamente
- ❌ = Error
- ⚠️ = Advertencia/Problema
- 📖 = Reader (lectura)
- 📢 = Provider
- 📄 = Nueva página
- ➡️ = Navegación entre páginas
- ⏳ = Esperando
- 💾 = Guardado

═══════════════════════════════════════════════════════════════════════

## 💡 Comandos Útiles

### Limpiar logs anteriores:
```bash
adb logcat -c
```

### Ver SOLO logs de la app (sin ruido):
```bash
adb logcat -s flutter
```

### Guardar y ver simultáneamente:
```bash
adb logcat | grep -E "TTS|Reader|Provider" | tee logs_en_vivo.txt
```

### Buscar una palabra específica en logs:
```bash
adb logcat | grep "palabra"
```

### Ver últimas 50 líneas de logs:
```bash
adb logcat -d | tail -50
```

═══════════════════════════════════════════════════════════════════════

## 📞 Qué Hacer con los Logs

Una vez que captures los logs mientras reproduces el problema:

1. **Envíame el archivo completo** o las últimas 200 líneas
2. **Describe exactamente qué hiciste:**
   - ¿Presionaste Play?
   - ¿Esperaste cuánto tiempo?
   - ¿Presionaste Pause?
   - ¿Qué pasó?
3. **Qué esperabas que pasara**
4. **Qué pasó realmente**

Con esos logs podré ver EXACTAMENTE dónde está el problema y arreglarlo.

═══════════════════════════════════════════════════════════════════════

**Versión:** v11.0 - Debug Logs
**Fecha:** 06/10/2025
**Objetivo:** Diagnosticar problemas con datos reales

═══════════════════════════════════════════════════════════════════════
