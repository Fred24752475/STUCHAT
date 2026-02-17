import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String _supabaseUrl = 'https://usvythgjalhgmjuvxqsa.supabase.co';
  static const String _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVzdnl0aGdqYWxoZ21qdXZ4cXNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEyODQwNzgsImV4cCI6MjA4Njg2MDA3OH0.uiRPWfDL2iDuYuZ7fcge6IwDmJumVA8BIXqirrH_Adg';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
    );
  }

  static Future<AuthResponse> signUpWithEmail(String email, String password) async {
    return await client.auth.signUp(
      email: email,
      password: password,
    );
  }

  static Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  static User? get currentUser => client.auth.currentUser;

  static Stream<User?> get authStateChanges => client.auth.onAuthStateChange.map(
        (event) => event.session?.user,
      );

  static Future<void> signInWithGoogle() async {
    await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.example.campus_connect://login-callback',
    );
  }

  static Future<void> signInWithApple() async {
    await client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: 'com.example.campus_connect://login-callback',
    );
  }

  static Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'com.example.campus_connect://reset-password',
    );
  }
}
