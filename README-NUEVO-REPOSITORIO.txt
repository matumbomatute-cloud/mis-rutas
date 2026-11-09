MIS RUTAS — PAQUETE PARA UN REPOSITORIO NUEVO
==============================================

Esta carpeta contiene el proyecto web y el proyecto Android de Mis Rutas.
La versión incluye bienvenida y acceso, perfil con foto, cambio/recuperación de
contraseña, cuatro mapas, rutas importadas en GPX/TCX, estadísticas, logros y
categorías personalizadas (Entreno, Carrera, Natación, etc.).

CREAR UN REPOSITORIO NUEVO EN GITHUB
-----------------------------------
1. Descomprime este ZIP en una carpeta.
2. En GitHub pulsa el + de arriba a la derecha y elige New repository.
3. Pon un nombre, por ejemplo mis-rutas-pruebas, y déjalo vacío (sin README).
4. Pulsa Create repository. GitHub mostrará instrucciones para subir una carpeta.
   Para hacerlo sin comandos, entra en Add file > Upload files, arrastra los archivos
   descomprimidos (index.html, config.js, etc.) y pulsa Commit changes.
5. Para mostrarlo como web, abre Settings > Pages y configura Deploy from a branch,
   rama main y carpeta /(root). GitHub te enseñará la dirección pública.
6. En Supabase > Authentication > URL Configuration, añade esa dirección a
   Redirect URLs para que funcionen los enlaces de confirmar correo y recuperar clave.
   Para restablecer la clave desde la APK, añade también misrutas://recovery a Redirect URLs.

SUPABASE
--------
config.js conecta a la instancia Supabase que ya se usó para la versión funcional.
La clave incluida es publicable y está diseñada para usarse en navegador. Si quieres
un espacio de prueba separado, crea otro proyecto Supabase, ejecuta supabase.sql en
SQL Editor y sustituye SUPABASE_URL y SUPABASE_ANON_KEY en config.js. No pegues nunca
una clave secret ni service_role en este archivo.

CATEGORÍAS PERSONALIZADAS
-------------------------
En el menú lateral pulsa «+ Agregar nueva opción» y escribe, por ejemplo, Entreno,
Carrera o Natación. Las categorías quedan guardadas en el navegador del dispositivo.
También viajan dentro de Exportar copia/Restaurar copia.

APK PARA ANDROID
----------------
El archivo android-wrapper/Mis-Rutas-debug.apk se puede copiar al teléfono e instalar.
Android puede pedir permiso para instalar aplicaciones desde el navegador o desde
Archivos. Es una versión de depuración firmada para instalar manualmente, no para
publicar en Google Play. Necesita internet para mapas, inicio de sesión y sincronización.

El proyecto fuente y el script para reconstruirlo están en android-wrapper. En un Mac
con Android SDK instalado, abre Terminal en android-wrapper y ejecuta:
  ./build-apk.sh
El APK recompilado aparecerá como android-wrapper/Mis-Rutas-debug.apk.

DATOS
-----
Las rutas guardadas en modo invitado permanecen en el almacenamiento del navegador
del dispositivo. Inicia sesión para sincronizar con Supabase y usar la cuenta en otros
dispositivos. El APK almacena sus datos separados de Chrome y de la web.
