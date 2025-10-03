#!/bin/bash
set -e

echo "==> Limpiando proyecto..."
flutter clean

echo "==> Obteniendo dependencias..."
flutter pub get

echo "==> Arreglando build.gradle.kts..."
# Reemplazar antes de que Flutter lo sobrescriba
while true; do
    if [ -f "android/app/build.gradle.kts" ]; then
        if grep -q "minSdkVersion flutter.minSdkVersion" android/app/build.gradle.kts 2>/dev/null; then
            sed -i 's/minSdkVersion flutter\.minSdkVersion/minSdk = 23/' android/app/build.gradle.kts
            echo "✓ build.gradle.kts arreglado"
        fi
    fi
    sleep 0.3
done &
FIX_PID=$!

echo "==> Compilando APK solo para ARM64..."
flutter build apk --release --target-platform android-arm64 --split-per-abi

kill $FIX_PID 2>/dev/null || true

if [ -f "build/app/outputs/flutter-apk/app-arm64-v8a-release.apk" ]; then
    echo ""
    echo "================================================"
    echo "✓✓✓ ¡APK COMPILADO EXITOSAMENTE! ✓✓✓"
    echo "================================================"
    ls -lh build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
    echo ""
    echo "Copiando al directorio actual..."
    cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk ./lector-pdf-arm64.apk
    ls -lh ./lector-pdf-arm64.apk
    echo ""
    echo "¡Listo! El APK está en: ./lector-pdf-arm64.apk"
else
    echo "ERROR: No se pudo compilar el APK"
    exit 1
fi
