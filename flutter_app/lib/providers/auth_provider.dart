import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/supabase_service.dart';
import '../services/storage_service.dart';
import '../services/logger_service.dart';

class AuthProvider with ChangeNotifier {
  User? _currentUser;
  bool _isAuthenticated = false;
  String? _token;
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  String? get token => _token;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _initAuthListener();
  }

  void _initAuthListener() {
    SupabaseService.authStateChanges.listen((user) {
      if (user != null) {
        _currentUser = User(
          id: user.id,
          name: user.userMetadata?['name'] ?? user.email?.split('@').first ?? 'User',
          email: user.email ?? '',
          course: user.userMetadata?['course'] ?? '',
          year: int.tryParse(user.userMetadata?['year']?.toString() ?? '0') ?? 0,
        );
        _isAuthenticated = true;
        _token = user.id;
      } else {
        _currentUser = null;
        _isAuthenticated = false;
        _token = null;
      }
      notifyListeners();
    });
  }

  Future<bool> tryAutoLogin() async {
    try {
      _isLoading = true;
      notifyListeners();

      final user = SupabaseService.currentUser;
      if (user != null) {
        _currentUser = User(
          id: user.id,
          name: user.userMetadata?['name'] ?? user.email?.split('@').first ?? 'User',
          email: user.email ?? '',
          course: user.userMetadata?['course'] ?? '',
          year: int.tryParse(user.userMetadata?['year']?.toString() ?? '0') ?? 0,
        );
        _isAuthenticated = true;
        _token = user.id;
        LoggerService.info('Auto-login successful for user: ${_currentUser!.email}');
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      LoggerService.error('Auto-login failed', e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> login(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await SupabaseService.signInWithEmail(email, password);
      
      if (response.user != null) {
        final user = response.user!;
        _currentUser = User(
          id: user.id,
          name: user.userMetadata?['name'] ?? email.split('@').first,
          email: user.email ?? email,
          course: user.userMetadata?['course'] ?? '',
          year: int.tryParse(user.userMetadata?['year']?.toString() ?? '0') ?? 0,
        );
        _isAuthenticated = true;
        _token = user.id;

        await StorageService.saveAuthData(
          token: _token!,
          userId: _currentUser!.id,
          userName: _currentUser!.name,
          userEmail: _currentUser!.email,
        );

        LoggerService.info('Login successful for: ${_currentUser!.email}');
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      LoggerService.error('Login failed', e);
      rethrow;
    }
  }

  Future<void> signup({
    required String name,
    required String email,
    required String password,
    required String course,
    required int year,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await SupabaseService.signUpWithEmail(email, password);
      
      if (response.user != null) {
        final user = response.user!;
        
        await SupabaseService.client.from('user_profiles').insert({
          'user_id': user.id,
          'id': user.id,
          'name': name,
          'email': email,
          'course': course,
          'year': year,
        });

        _currentUser = User(
          id: user.id,
          name: name,
          email: email,
          course: course,
          year: year,
        );
        _isAuthenticated = true;
        _token = user.id;

        await StorageService.saveAuthData(
          token: _token!,
          userId: _currentUser!.id,
          userName: _currentUser!.name,
          userEmail: _currentUser!.email,
        );

        LoggerService.info('Signup successful for: $email');
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      LoggerService.error('Signup failed', e);
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      _isLoading = true;
      notifyListeners();

      await SupabaseService.signInWithGoogle();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      LoggerService.error('Google sign-in failed', e);
      rethrow;
    }
  }

  Future<void> signInWithApple() async {
    try {
      _isLoading = true;
      notifyListeners();

      await SupabaseService.signInWithApple();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      LoggerService.error('Apple sign-in failed', e);
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await SupabaseService.signOut();
      await StorageService.clearAuthData();
      _currentUser = null;
      _isAuthenticated = false;
      _token = null;

      LoggerService.info('User logged out');
      notifyListeners();
    } catch (e) {
      LoggerService.error('Logout failed', e);
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      _isLoading = true;
      notifyListeners();

      await SupabaseService.resetPassword(email);

      _isLoading = false;
      notifyListeners();
      LoggerService.info('Password reset email sent to: $email');
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      LoggerService.error('Password reset failed', e);
      rethrow;
    }
  }
}
