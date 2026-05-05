# Splitway — Autenticación + Mejoras UI/UX

## Resumen

Agregar autenticación con Supabase Auth (Google + Email/Contraseña) a la app Splitway, junto con un drawer lateral para perfil/sync/ajustes y mejoras en el flujo de sincronización. La autenticación solo es obligatoria para acciones de escritura (crear ruta, grabar sesión); el usuario puede explorar la app sin cuenta.

## Decisiones de diseño

| Aspecto | Decisión |
|---------|----------|
| Auth obligatorio para | Solo escritura: crear ruta, grabar sesión, sincronizar |
| Métodos de login | Google OAuth + Email/Contraseña |
| Pantalla de login | Fullscreen con gradiente azul (#1565C0 → #0D47A1) y branding |
| Drawer lateral | Dark minimal (fondo #0D1B2A), avatar compacto con iniciales arriba-izquierda, nombre a la derecha, botón sync verde con gradiente |
| Sincronización | Automática cada 5 min + botón manual en drawer |

## Arquitectura

### AuthService (ChangeNotifier)

Envuelve `Supabase.instance.client.auth`. Responsabilidades:

- Exponer `User? currentUser`, `bool isLoggedIn`
- `signInWithGoogle()` — OAuth flow con `supabase_flutter`
- `signInWithEmail(email, password)` — login con credenciales
- `signUpWithEmail(email, password)` — registro nuevo usuario
- `signOut()` — cierra sesión, limpia estado
- Escucha `onAuthStateChange` para reaccionar a login/logout/token refresh
- Notifica listeners en cada cambio de estado

### Flujo de protección de acciones

1. Usuario toca "Nueva ruta" o "Comenzar sesión"
2. Se comprueba `authService.isLoggedIn`
3. Si NO logueado → navega a `LoginScreen` con parámetro `redirectAction`
4. Tras login exitoso → redirect automático a la pantalla/acción original
5. Si elige "Continuar sin cuenta" → vuelve a pantalla anterior sin hacer la acción

### SyncService (actualización)

- Solo se activa cuando hay usuario autenticado (`currentUser != null`)
- Timer periódico cada 5 minutos (configurable)
- Se pausa si no hay conexión a internet
- Reintenta automáticamente al recuperar conexión
- Estados: `idle`, `syncing`, `success`, `error`, `offline`
- El drawer refleja el estado con indicador de color

### Integración con AppRouter

- `LoginScreen` se registra como ruta `/login` con parámetro opcional `redirect`
- No hay guard global — la protección es por acción, no por pantalla
- El drawer se abre desde cualquier pantalla vía icono en AppBar

## Pantallas

### LoginScreen

Pantalla fullscreen con gradiente azul (#1565C0 → #0D47A1).

**Layout (de arriba a abajo):**
1. Logo Splitway (emoji bandera + texto) centrado con tagline "Cronómetro inteligente para rutas"
2. Contenedor translúcido (rgba blanco 0.15) con bordes redondeados:
   - Botón "Continuar con Google" — fondo blanco, texto oscuro, icono G
   - Separador "— o —" en texto translúcido
   - Campo Email — fondo translúcido, placeholder claro
   - Campo Contraseña — fondo translúcido, placeholder claro
   - Botón "Iniciar sesión" — fondo blanco, texto azul, bold
3. Toggle "¿No tienes cuenta? Regístrate" — cambia a modo registro (añade campo confirmar contraseña)
4. Botón "Continuar sin cuenta" — texto pequeño, translúcido, en la parte inferior

**Validación y errores:**
- Email: formato inválido → error inline rojo bajo el campo
- Contraseña: mínimo 6 caracteres → error inline
- Credenciales incorrectas → error inline bajo el botón de login
- Error de red → SnackBar con "Sin conexión. Inténtalo de nuevo."
- Google OAuth cancelado → no muestra error, vuelve al formulario

### Drawer lateral

Fondo oscuro (#0D1B2A), ancho ~280px, se abre desde icono hamburguesa o avatar en el AppBar.

**Estado: logueado**

```
┌─────────────────────────┐
│ [PM]  Pablo Martínez    │  ← avatar 36px con iniciales + nombre + email
│       pablo@email.com   │
├─────────────────────────┤
│ ● SINCRONIZADO · 14:32  │  ← punto verde 6px + texto gris
│ ┌─────────────────────┐ │
│ │  ↻ Sincronizar ahora│ │  ← botón verde gradiente (#2E7D32 → #43A047)
│ └─────────────────────┘ │
├─────────────────────────┤
│ ⚙️ Configuración        │
│ 📊 Estadísticas         │
│ ❓ Ayuda                │
├─────────────────────────┤
│ v0.3.0    Cerrar sesión │  ← versión gris + logout rojo
└─────────────────────────┘
```

**Estado: no logueado**

```
┌─────────────────────────┐
│ ┌─────────────────────┐ │
│ │   Iniciar sesión    │ │  ← botón azul prominente
│ └─────────────────────┘ │
├─────────────────────────┤
│ ❓ Ayuda                │
├─────────────────────────┤
│ v0.3.0                  │
└─────────────────────────┘
```

**Indicador de sync (colores del punto):**
- Verde (#4CAF50): sincronizado, todo al día
- Naranja (#FF9800): sin conexión o sync pendiente
- Rojo (#EF5350): error de sincronización
- Azul animado (#42A5F5): sincronizando en este momento

### Cambios en AppBar (todas las pantallas)

- Izquierda: icono hamburguesa (si no logueado) o avatar circular con iniciales (si logueado)
- Al tocar → abre el Drawer
- Sin otros cambios en las pantallas existentes

## Manejo de errores

| Escenario | Comportamiento |
|-----------|---------------|
| Login con credenciales incorrectas | Error inline rojo bajo botón login |
| Email ya registrado (signup) | Error inline "Este email ya está registrado" |
| Contraseña muy corta | Error inline "Mínimo 6 caracteres" |
| Google OAuth cancelado | Sin error, vuelve al formulario |
| Error de red en login | SnackBar "Sin conexión" |
| Sync falla | Punto rojo en drawer + SnackBar breve |
| Sin conexión (sync) | Punto naranja + texto "Sin conexión", sync se pausa |
| Reconexión | Sync se reanuda automáticamente |
| Token expirado | AuthService detecta via `onAuthStateChange`, intenta refresh. Si falla → signOut + SnackBar "Sesión expirada" |

## Dependencias

- `supabase_flutter: ^2.8.0` (ya instalado)
- `google_sign_in: ^6.2.0` (nuevo — necesario para OAuth nativo en Android)
- `connectivity_plus: ^6.0.0` (nuevo — detectar estado de red)

## Configuración necesaria en Supabase Dashboard

1. **Auth → Providers → Google**: activar, configurar OAuth Client ID y Secret de Google Cloud Console
2. **Auth → URL Configuration**: verificar redirect URLs para deep linking
3. **Android**: configurar SHA-1 fingerprint en Google Cloud Console para el OAuth client

## Redirect post-login

Cuando el usuario es redirigido a LoginScreen por intentar una acción protegida, se pasa un parámetro `redirect` (ej: `/editor?action=create` o `/session?routeId=abc`). Tras login exitoso, `go_router` navega a esa ruta. Si el usuario llega a LoginScreen directamente (desde el drawer), tras login se cierra el LoginScreen y vuelve a la pantalla anterior con `context.pop()`.

## Archivos a crear/modificar

### Nuevos
- `lib/src/services/auth/auth_service.dart` — AuthService ChangeNotifier
- `lib/src/features/auth/login_screen.dart` — pantalla de login
- `lib/src/features/auth/widgets/` — componentes reutilizables del login
- `lib/src/shared/widgets/app_drawer.dart` — drawer lateral dark minimal

### Modificar
- `lib/src/app.dart` — crear y proveer AuthService, conectar con SyncService
- `lib/src/routing/app_router.dart` — añadir ruta `/login`, pasar AuthService
- `lib/src/services/sync/sync_service.dart` — añadir timer periódico, estados offline/success, listener de conectividad
- `lib/src/features/home/home_shell.dart` — añadir Drawer + cambiar leading del AppBar
- `lib/src/features/editor/route_editor_screen.dart` — proteger "Nueva ruta" con auth check
- `lib/src/features/session/live_session_screen.dart` — proteger "Comenzar" con auth check
- `pubspec.yaml` — añadir `google_sign_in`, `connectivity_plus`
