import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

/// نتيجة عملية المصادقة
class AuthResult {
  final bool success;
  final String? errorMessage;
  final String? errorCode;
  final UserCredential? credential;

  AuthResult({
    required this.success,
    this.errorMessage,
    this.errorCode,
    this.credential,
  });

  factory AuthResult.success(UserCredential credential) => AuthResult(
    success: true,
    credential: credential,
  );

  factory AuthResult.error(String message, [String? code]) => AuthResult(
    success: false,
    errorMessage: message,
    errorCode: code,
  );

  factory AuthResult.cancelled() => AuthResult(
    success: false,
    errorMessage: 'تم إلغاء العملية',
    errorCode: 'cancelled',
  );
}

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// تسجيل الدخول بواسطة Google
  static Future<AuthResult> signInWithGoogle() async {
    try {
      // محاولة تسجيل الدخول
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        return AuthResult.cancelled();
      }

      debugPrint('✅ Google user: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // التحقق من وجود التوكنات
      if (googleAuth.accessToken == null && googleAuth.idToken == null) {
        debugPrint('❌ Missing tokens - accessToken: ${googleAuth.accessToken != null}, idToken: ${googleAuth.idToken != null}');
        return AuthResult.error(
          'فشل الحصول على بيانات المصادقة من Google. تأكد من إعدادات SHA-1 في Firebase.',
          'missing_tokens',
        );
      }
      
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      debugPrint('✅ Firebase sign in successful: ${userCredential.user?.email}');
      
      return AuthResult.success(userCredential);
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuthException: ${e.code} - ${e.message}');
      return AuthResult.error(_getFirebaseErrorMessage(e.code), e.code);
    } catch (e) {
      debugPrint('❌ Google sign in error: $e');
      
      // تحليل نوع الخطأ
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('network') || errorStr.contains('connection')) {
        return AuthResult.error('خطأ في الاتصال بالإنترنت', 'network_error');
      }
      if (errorStr.contains('sha') || errorStr.contains('certificate')) {
        return AuthResult.error(
          'خطأ في إعدادات التطبيق. يرجى التواصل مع الدعم الفني.',
          'sha_error',
        );
      }
      if (errorStr.contains('api') || errorStr.contains('developer')) {
        return AuthResult.error(
          'خطأ في إعدادات Google API. يرجى التواصل مع الدعم الفني.',
          'api_error',
        );
      }
      
      return AuthResult.error('فشل تسجيل الدخول: ${e.toString()}', 'unknown');
    }
  }

  /// تسجيل الدخول بالبريد الإلكتروني
  static Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return AuthResult.success(credential);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getFirebaseErrorMessage(e.code), e.code);
    } catch (e) {
      return AuthResult.error('فشل تسجيل الدخول: $e', 'unknown');
    }
  }

  /// إنشاء حساب جديد
  static Future<AuthResult> signUpWithEmail(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // إرسال بريد التحقق
      if (credential.user != null && !credential.user!.emailVerified) {
        try {
          await credential.user!.sendEmailVerification();
        } catch (_) {}
      }
      
      return AuthResult.success(credential);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getFirebaseErrorMessage(e.code), e.code);
    } catch (e) {
      return AuthResult.error('فشل إنشاء الحساب: $e', 'unknown');
    }
  }

  /// تسجيل الدخول كضيف
  static Future<AuthResult> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      return AuthResult.success(credential);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getFirebaseErrorMessage(e.code), e.code);
    } catch (e) {
      return AuthResult.error('فشل تسجيل الدخول كضيف: $e', 'unknown');
    }
  }

  /// إعادة تعيين كلمة المرور
  static Future<AuthResult> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getFirebaseErrorMessage(e.code), e.code);
    } catch (e) {
      return AuthResult.error('فشل إرسال رابط إعادة التعيين: $e', 'unknown');
    }
  }

  /// تسجيل الخروج
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  static bool get isSignedIn => _auth.currentUser != null;

  /// ترجمة رسائل خطأ Firebase
  static String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'البريد الإلكتروني غير مسجل';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة';
      case 'invalid-email':
        return 'البريد الإلكتروني غير صالح';
      case 'user-disabled':
        return 'تم تعطيل هذا الحساب';
      case 'email-already-in-use':
        return 'البريد الإلكتروني مستخدم بالفعل';
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً';
      case 'operation-not-allowed':
        return 'هذه العملية غير مسموحة';
      case 'too-many-requests':
        return 'محاولات كثيرة جداً. حاول لاحقاً';
      case 'network-request-failed':
        return 'خطأ في الاتصال بالإنترنت';
      case 'invalid-credential':
        return 'بيانات الاعتماد غير صالحة';
      case 'account-exists-with-different-credential':
        return 'يوجد حساب بهذا البريد مع طريقة تسجيل مختلفة';
      default:
        return 'حدث خطأ غير متوقع ($code)';
    }
  }
}