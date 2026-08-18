#!/bin/bash
# Script para compilar Flutter en Cloudflare Pages

# 1. Clonar el repositorio de Flutter (versión estable)
git clone https://github.com/flutter/flutter.git -b stable

# 2. Agregar Flutter al PATH temporalmente para la compilación
export PATH="$PATH:`pwd`/flutter/bin"

# 3. Habilitar soporte web
flutter config --enable-web

# 4. Crear archivo .env temporal para que la compilación de assets no falle
# Se tomarán las variables de entorno configuradas en Cloudflare Pages
cat <<EOF > .env
URL='${URL}'
ANON='${ANON}'
VAPID_PUBLIC_KEY='${VAPID_PUBLIC_KEY}'
MP_CLIENT_ID='${MP_CLIENT_ID}'
EOF

# 5. Compilar la aplicación para producción
flutter build web --release

# 6. Invalidar caché agresivamente inyectando timestamps en los archivos generados
TIMESTAMP=$(date +%s)
sed -i "s|src=\"flutter_bootstrap.js\"|src=\"flutter_bootstrap.js?v=$TIMESTAMP\"|g" build/web/index.html
sed -i "s|\"mainJsPath\":\"main.dart.js\"|\"mainJsPath\":\"main.dart.js?v=$TIMESTAMP\"|g" build/web/flutter_bootstrap.js

# 7. Reemplazar el flutter_service_worker.js por uno autodestructivo
# para limpiar el cache agresivo que haya quedado en los clientes.
cat > build/web/flutter_service_worker.js <<'EOF'
self.addEventListener('install', function () { self.skipWaiting(); });
self.addEventListener('activate', function (event) {
  event.waitUntil((async function () {
    try {
      var keys = await caches.keys();
      await Promise.all(keys.map(function (k) { return caches.delete(k); }));
    } catch (e) {}
    try { await self.clients.claim(); } catch (e) {}
    try {
      var wins = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
      wins.forEach(function (c) { try { c.navigate(c.url); } catch (e) {} });
    } catch (e) {}
    try { await self.registration.unregister(); } catch (e) {}
  })());
});
EOF
