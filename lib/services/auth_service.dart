import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn();
  static String? _userEmail;
  static String? _userName;
  static String? _loginMethod;

  static String? get userEmail => _userEmail;
  static String? get userName => _userName;
  static String? get loginMethod => _loginMethod;
  static bool get isB2C => _loginMethod == 'google';

  static Future<bool> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return false;
      _userEmail = account.email;
      _userName = account.displayName;
      _loginMethod = 'google';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', account.email);
      await prefs.setString('user_name', account.displayName ?? '');
      await prefs.setString('login_method', 'google');
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> signOut() async {
    if (_loginMethod == 'google') {
      await _googleSignIn.signOut();
    }
    _userEmail = null;
    _userName = null;
    _loginMethod = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_email');
    await prefs.remove('user_name');
    await prefs.remove('login_method');
  }

  static Future<bool> loadSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    _loginMethod = prefs.getString('login_method');
    if (_loginMethod == 'google') {
      _userEmail = prefs.getString('user_email');
      _userName = prefs.getString('user_name');
      return _userEmail != null;
    }
    return false;
  }
}
