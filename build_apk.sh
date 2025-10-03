#!/bin/bash
# Primero dejamos que Flutter haga su upgrade
flutter build apk --release 2>&1 | grep -q "Upgrading" && echo "Flutter upgraded the file"

# Ahora arreglamos el archivo
sed -i 's/minSdkVersion flutter\.minSdkVersion/minSdk = 21/' android/app/build.gradle.kts

# Y compilamos directamente con Gradle
cd android && ./gradlew assembleRelease
