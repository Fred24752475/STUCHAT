import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();
  static final _logger = Logger();
  static bool _useSecureStorage = !kIsWeb; // Don't use secure storage on web

  // Keys
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _userEmailKey = 'user_email';

  // Save auth data
  static Future<void> saveAuthData({
    required String token,
    required String userId,
    required String userName,
    required String userEmail,
  }) async {
    try {
      if (_useSecureStorage) {
        try {
          await Future.wait([
            _storage.write(key: _tokenKey, value: token),
            _storage.write(key: _userIdKey, value: userId),
            _storage.write(key: _userNameKey, value: userName),
            _storage.write(key: _userEmailKey, value: userEmail),
          ]);
          _logger.i('Auth data saved to secure storage');
        } catch (e) {
          _logger.w('Secure storage failed, falling back to SharedPreferences');
          _useSecureStorage = false;
          await _saveToSharedPrefs(token, userId, userName, userEmail);
        }
      } else {
        await _saveToSharedPrefs(token, userId, userName, userEmail);
      }
    } catch (e) {
      _logger.e('Error saving auth data: $e');
      rethrow;
    }
  }

  static Future<void> _saveToSharedPrefs(
    String token,
    String userId,
    String userName,
    String userEmail,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_tokenKey, token),
      prefs.setString(_userIdKey, userId),
      prefs.setString(_userNameKey, userName),
      prefs.setString(_userEmailKey, userEmail),
    ]);
    _logger.i('Auth data saved to SharedPreferences');
  }

  // Get token
  static Future<String?> getToken() async {
    try {
      if (_useSecureStorage) {
        try {
          return await _storage.read(key: _tokenKey);
        } catch (e) {
          _useSecureStorage = false;
          final prefs = await SharedPreferences.getInstance();
          return prefs.getString(_tokenKey);
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(_tokenKey);
      }
    } catch (e) {
      _logger.e('Error reading token: $e');
      return null;
    }
  }

  // Get user ID
  static Future<String?> getUserId() async {
    try {
      if (_useSecureStorage) {
        try {
          return await _storage.read(key: _userIdKey);
        } catch (e) {
          _useSecureStorage = false;
          final prefs = await SharedPreferences.getInstance();
          return prefs.getString(_userIdKey);
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(_userIdKey);
      }
    } catch (e) {
      _logger.e('Error reading user ID: $e');
      return null;
    }
  }

  // Get user name
  static Future<String?> getUserName() async {
    try {
      if (_useSecureStorage) {
        try {
          return await _storage.read(key: _userNameKey);
        } catch (e) {
          _useSecureStorage = false;
          final prefs = await SharedPreferences.getInstance();
          return prefs.getString(_userNameKey);
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(_userNameKey);
      }
    } catch (e) {
      _logger.e('Error reading user name: $e');
      return null;
    }
  }

  // Get user email
  static Future<String?> getUserEmail() async {
    try {
      if (_useSecureStorage) {
        try {
          return await _storage.read(key: _userEmailKey);
        } catch (e) {
          _useSecureStorage = false;
          final prefs = await SharedPreferences.getInstance();
          return prefs.getString(_userEmailKey);
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(_userEmailKey);
      }
    } catch (e) {
      _logger.e('Error reading user email: $e');
      return null;
    }
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Clear all auth data
  static Future<void> clearAuthData() async {
    try {
      if (_useSecureStorage) {
        try {
          await _storage.deleteAll();
        } catch (e) {
          _useSecureStorage = false;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_tokenKey),
        prefs.remove(_userIdKey),
        prefs.remove(_userNameKey),
        prefs.remove(_userEmailKey),
      ]);

      _logger.i('Auth data cleared');
    } catch (e) {
      _logger.e('Error clearing auth data: $e');
      rethrow;
    }
  }

  // Save offline messages
  static Future<void> saveOfflineMessage(Map<String, dynamic> message) async {
    try {
      final messages = await getOfflineMessages();
      messages.add(message);
      await _storage.write(
        key: 'offline_messages',
        value: messages.toString(),
      );
    } catch (e) {
      _logger.e('Error saving offline message: $e');
    }
  }

  // Get offline messages
  static Future<List<Map<String, dynamic>>> getOfflineMessages() async {
    try {
      final data = await _storage.read(key: 'offline_messages');
      if (data == null) return [];
      // Parse and return messages
      return [];
    } catch (e) {
      _logger.e('Error reading offline messages: $e');
      return [];
    }
  }

  // Clear offline messages
  static Future<void> clearOfflineMessages() async {
    try {
      await _storage.delete(key: 'offline_messages');
    } catch (e) {
      _logger.e('Error clearing offline messages: $e');
    }
  }
}
