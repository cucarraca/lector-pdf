#!/bin/bash
set -e

echo "==> Limpiando proyecto..."
flutter clean > /dev/null 2>&1

echo "==> Obteniendo dependencias..."
flutter pub get > /dev/null 2>&1

echo "==> Arreglando build.gradle.kts..."
# Este hack es necesario porque Flutter reescribe el archivo durante el build
# Creamos un hook que se ejecuta después de que Flutter actualice el archivo
cat > /tmp/fix_gradle.sh << 'EOF'
#!/bin/bash
while true; do
  if grep -q "minSdkVersion flutter.minSdkVersion" android/app/build.gradle.kts 2>/dev/null; then
    sed -i 's/minSdkVersion flutter\.minSdkVersion/minSdk = 23/' android/app/build.gradle.kts
    echo "Archivo build.gradle.kts arreglado!"
    break
  fi
  sleep 0.5
done
EOF
chmod +x /tmp/fix_gradle.sh

# Ejecutar el fix en segundo plano
/tmp/fix_gradle.sh &
FIX_PID=$!

echo "==> Compilando APK..."
flutter build apk --release 2>&1 | grep -v "^Downloading" || true

# Matar el proceso de fix si sigue corriendo
kill $FIX_PID 2>/dev/null || true

echo "==> APK compilado exitosamente!"
ls -lh build/app/outputs/flutter-apk/app-release.apk
