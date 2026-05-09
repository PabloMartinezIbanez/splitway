import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Wraps [SupabaseAuth] and exposes a simple API for sign-in / sign-out.
///
/// Listens to [onAuthStateChange] so the UI reacts to login, logout and
/// token-refresh events automatically.
class AuthService extends ChangeNotifier {
  AuthService({required SupabaseClient client}) : _client = client {
    _subscription = _client.auth.onAuthStateChange.listen(_onAuthEvent);
  }

  final SupabaseClient _client;
  late final StreamSubscription<AuthState> _subscription;

  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  /// True when the last sign-up succeeded but requires email confirmation.
  /// The UI should show a "check your inbox" dialog and stay on the screen.
  bool _pendingEmailConfirmation = false;
  bool get pendingEmailConfirmation => _pendingEmailConfirmation;

  void clearPendingConfirmation() {
    _pendingEmailConfirmation = false;
  }

  void _onAuthEvent(AuthState state) {
    debugPrint('AuthService: ${state.event}');
    _error = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Google OAuth
  // ---------------------------------------------------------------------------

  Future<bool> signInWithGoogle() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: _webClientId,
      );
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the sign-in flow.
        _loading = false;
        notifyListeners();
        return false;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        _error = 'No se pudo obtener el token de Google.';
        _loading = false;
        notifyListeners();
        return false;
      }

      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('signInWithGoogle error: $e');
      _error = _friendlyError(e);
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Email / Password
  // ---------------------------------------------------------------------------

  Future<bool> signInWithEmail(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      _loading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = _friendlyAuthError(e);
      _loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = _friendlyError(e);
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUpWithEmail(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );
      // Supabase creates the user but session is null when email confirmation
      // is required. This is a success path, not an error.
      if (response.session == null) {
        _pendingEmailConfirmation = true;
        _loading = false;
        notifyListeners();
        return false; // false = no session yet, UI should show confirmation dialog
      }
      _loading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = _friendlyAuthError(e);
      _loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = _friendlyError(e);
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Sign out
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('signOut error: $e');
    }
    notifyListeners();
  }

  /// Clears the current error message (e.g. when toggling sign-in / sign-up).
  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Google Web Client ID — must match the one configured in Supabase Dashboard
  /// Auth → Providers → Google. On Android the native client ID is pulled from
  /// google-services.json, but serverClientId is needed for the id-token flow.
  static const _webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  String _friendlyAuthError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials')) {
      return 'Email o contraseña incorrectos.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Confirma tu email antes de iniciar sesión.';
    }
    if (msg.contains('user already registered')) {
      return 'Este email ya está registrado.';
    }
    if (msg.contains('password') && msg.contains('at least')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    return e.message;
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('socket') || msg.contains('network') || msg.contains('connection')) {
      return 'Sin conexión. Inténtalo de nuevo.';
    }
    return 'Error inesperado. Inténtalo de nuevo.';
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
