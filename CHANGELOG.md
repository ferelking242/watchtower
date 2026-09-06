# Changelog

## 2026-06-15 — Python Bionic runtime (Méthode B)
- libpython.so (4KB) + libpython.zip.so (11MB) depuis youtubedl-android → jniLibs
- zeusdl.zip (3MB) → assets, extractible au runtime dans filesDir
- Exécution : nativeLibsDir/libpython.so + filesDir/zeusdl/__main__.py
- Plus de SIGSEGV (exit 139), plus de blocage SELinux execv
- Auto-update zeusdl.zip sans réinstaller l'APK

