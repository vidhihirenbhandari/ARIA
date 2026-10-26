import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/constants/app_config.dart';

class GoogleAuthService {
  static final GoogleSignIn _instance = GoogleSignIn(
    clientId: kIsWeb ? AppConfig.googleWebClientId : null,
    scopes: AppConfig.googleCalendarScopes,
  );

  GoogleSignIn get _signIn => _instance;

  Future<GoogleSignInAccount?> signIn() async {
    try {
      return await _signIn.signIn();
    } catch (e) {
      debugPrint('GoogleAuthService.signIn error: $e');
      return null;
    }
  }

  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      return await _signIn.signInSilently();
    } catch (_) {
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _signIn.signOut();
    } catch (_) {}
  }

  GoogleSignInAccount? get currentUser => _signIn.currentUser;

  Stream<GoogleSignInAccount?> get userChanges => _signIn.onCurrentUserChanged;
}
