#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SDK=${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}
BT="$SDK/build-tools/34.0.0"
ANDROID_JAR="$SDK/platforms/android-34/android.jar"
OUT="$ROOT/build"
rm -rf "$OUT"
mkdir -p "$OUT/gen" "$OUT/obj" "$OUT/dex" "$OUT/apk/assets"
cp "$ROOT"/../index.html "$ROOT"/../config.js "$ROOT"/../logo-mis-rutas.svg "$OUT/apk/assets/"
cp "$ROOT"/../manifest.webmanifest "$ROOT"/../sw.js "$OUT/apk/assets/"
"$BT/aapt" package -f -M "$ROOT/AndroidManifest.xml" -I "$ANDROID_JAR" -F "$OUT/unsigned.apk" -A "$OUT/apk/assets"
javac -source 8 -target 8 -bootclasspath "$ANDROID_JAR" -d "$OUT/obj" "$ROOT/src/app/misrutas/MainActivity.java"
"$BT/d8" --min-api 23 --lib "$ANDROID_JAR" --output "$OUT/dex" "$OUT"/obj/app/misrutas/*.class
cp "$OUT/unsigned.apk" "$OUT/unaligned.apk"
cd "$OUT/dex"
jar uf "$OUT/unaligned.apk" classes.dex
"$BT/zipalign" -f 4 "$OUT/unaligned.apk" "$OUT/aligned.apk"
if [ ! -f "$ROOT/debug.keystore" ]; then
  keytool -genkeypair -keystore "$ROOT/debug.keystore" -storepass android -alias androiddebugkey -keypass android -dname "CN=Mis Rutas Debug,O=Mis Rutas,C=ES" -keyalg RSA -keysize 2048 -validity 10000 >/dev/null 2>&1
fi
"$BT/apksigner" sign --ks "$ROOT/debug.keystore" --ks-pass pass:android --key-pass pass:android --out "$ROOT/Mis-Rutas-debug.apk" "$OUT/aligned.apk"
"$BT/apksigner" verify "$ROOT/Mis-Rutas-debug.apk"
echo "APK creado: $ROOT/Mis-Rutas-debug.apk"
