import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for secure token storage with encryption
/// 
/// This service provides platform-specific secure storage for sensitive data
/// like Confluence tokens with additional encryption layer for enhanced security.
class SecureTokenStorage {
  static const String _keyPrefix = 'tee_zee_nator_';
  static const String _confluenceTokenKey = '${_keyPrefix}confluence_token';
  static const String _encryptionKeyKey = '${_keyPrefix}encryption_key';
  
  // Platform-specific secure storage configuration
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'tee_zee_nator_secure_prefs',
      preferencesKeyPrefix: _keyPrefix,
    ),
    iOptions: IOSOptions(
      groupId: 'group.com.teezee.nator',
      accountName: 'TeeZeeNator',
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    lOptions: LinuxOptions(),
    wOptions: WindowsOptions(
      useBackwardCompatibility: false,
    ),
    mOptions: MacOsOptions(
      groupId: 'group.com.teezee.nator',
      accountName: 'TeeZeeNator',
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Stores a Confluence token securely with encryption
  /// 
  /// [token] - The token to store
  /// Returns true if storage was successful
  static Future<bool> storeConfluenceToken(String token) async {
    try {
      if (token.isEmpty) {
        debugPrint('SecureTokenStorage: Cannot store empty token');
        return false;
      }

      // Get or create encryption key
      final encryptionKey = await _getOrCreateEncryptionKey();
      
      // Encrypt the token
      final encryptedToken = _encryptToken(token, encryptionKey);
      
      // Store encrypted token
      await _secureStorage.write(
        key: _confluenceTokenKey,
        value: encryptedToken,
      );
      
      debugPrint('SecureTokenStorage: Token stored successfully');
      return true;
      
    } catch (e) {
      debugPrint('SecureTokenStorage: Failed to store token: $e');
      return false;
    }
  }

  /// Retrieves and decrypts the stored Confluence token
  /// 
  /// Returns the decrypted token or null if not found/invalid
  static Future<String?> getConfluenceToken() async {
    try {
      // Get encrypted token
      final encryptedToken = await _secureStorage.read(key: _confluenceTokenKey);
      if (encryptedToken == null || encryptedToken.isEmpty) {
        debugPrint('SecureTokenStorage: No token found');
        return null;
      }

      // Get encryption key
      final encryptionKey = await _getOrCreateEncryptionKey();
      
      try {
        // Decrypt token
        final decryptedToken = _decryptToken(encryptedToken, encryptionKey);
        
        if (decryptedToken.isEmpty) {
          debugPrint('SecureTokenStorage: Token decryption resulted in empty string');
          return null;
        }
        
        debugPrint('SecureTokenStorage: Token retrieved successfully');
        return decryptedToken;
      } catch (decryptError) {
        // Handle specific decryption errors
        debugPrint('SecureTokenStorage: Token decryption failed: $decryptError');
        
        // Check if token appears to be in plain text format (not encrypted)
        if (_isValidTokenFormat(encryptedToken)) {
          debugPrint('SecureTokenStorage: Token appears to be in plain text format, returning as-is');
          return encryptedToken;
        }
        
        // If we can't decrypt and it's not valid plain text, return null
        return null;
      }
      
    } catch (e) {
      debugPrint('SecureTokenStorage: Failed to retrieve token: $e');
      return null;
    }
  }

  /// Removes the stored Confluence token
  /// 
  /// Returns true if removal was successful
  static Future<bool> removeConfluenceToken() async {
    try {
      await _secureStorage.delete(key: _confluenceTokenKey);
      debugPrint('SecureTokenStorage: Token removed successfully');
      return true;
    } catch (e) {
      debugPrint('SecureTokenStorage: Failed to remove token: $e');
      return false;
    }
  }

  /// Checks if a Confluence token is stored
  /// 
  /// Returns true if a token exists
  static Future<bool> hasConfluenceToken() async {
    try {
      final token = await _secureStorage.read(key: _confluenceTokenKey);
      return token != null && token.isNotEmpty;
    } catch (e) {
      debugPrint('SecureTokenStorage: Failed to check token existence: $e');
      return false;
    }
  }

  /// Validates that the stored token can be decrypted
  /// 
  /// Returns true if token exists and can be decrypted
  static Future<bool> validateStoredToken() async {
    try {
      final token = await getConfluenceToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      debugPrint('SecureTokenStorage: Token validation failed: $e');
      return false;
    }
  }

  /// Clears all stored secure data
  /// 
  /// This method removes all tokens and encryption keys
  static Future<void> clearAllSecureData() async {
    try {
      await _secureStorage.deleteAll();
      debugPrint('SecureTokenStorage: All secure data cleared');
    } catch (e) {
      debugPrint('SecureTokenStorage: Failed to clear secure data: $e');
    }
  }

  /// Gets or creates an encryption key for additional security
  static Future<String> _getOrCreateEncryptionKey() async {
    try {
      // Try to get existing key
      String? existingKey = await _secureStorage.read(key: _encryptionKeyKey);
      
      if (existingKey != null && existingKey.isNotEmpty) {
        return existingKey;
      }
      
      // Generate new key
      final key = _generateEncryptionKey();
      
      // Store the key
      await _secureStorage.write(key: _encryptionKeyKey, value: key);
      
      debugPrint('SecureTokenStorage: New encryption key generated');
      return key;
      
    } catch (e) {
      debugPrint('SecureTokenStorage: Failed to get/create encryption key: $e');
      // Fallback to a deterministic key based on device/app
      return _generateFallbackKey();
    }
  }

  /// Generates a random encryption key
  static String _generateEncryptionKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Encode(bytes);
  }

  /// Generates a fallback encryption key
  static String _generateFallbackKey() {
    // Create a deterministic but unique key based on app identifier
    const appIdentifier = 'TeeZeeNator_v1.1.0';
    final bytes = utf8.encode(appIdentifier);
    final digest = sha256.convert(bytes);
    return base64Encode(digest.bytes);
  }

  /// Encrypts a token using AES-like simple encryption
  /// 
  /// Note: This is a simple XOR-based encryption for demonstration.
  /// In production, consider using more robust encryption like AES.
  static String _encryptToken(String token, String key) {
    try {
      final tokenBytes = utf8.encode(token);
      final keyBytes = base64Decode(key);
      
      // Simple XOR encryption with key rotation
      final encryptedBytes = <int>[];
      for (int i = 0; i < tokenBytes.length; i++) {
        final keyIndex = i % keyBytes.length;
        encryptedBytes.add(tokenBytes[i] ^ keyBytes[keyIndex]);
      }
      
      // Add a simple checksum for integrity
      final checksum = _calculateChecksum(tokenBytes);
      encryptedBytes.addAll(checksum);
      
      return base64Encode(encryptedBytes);
    } catch (e) {
      debugPrint('SecureTokenStorage: Encryption failed: $e');
      throw Exception('Token encryption failed');
    }
  }

  /// Decrypts a token using the same algorithm as encryption
  static String _decryptToken(String encryptedToken, String key) {
    try {
      // Clean up the base64 string - remove any invalid characters
      String cleanToken = encryptedToken.replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), '');
      
      // Add padding if needed
      while (cleanToken.length % 4 != 0) {
        cleanToken += '=';
      }
      
      // Verify the token has valid base64 format after cleaning
      if (!RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(cleanToken)) {
        throw Exception('Invalid base64 characters in token');
      }
      
      final encryptedBytes = base64Decode(cleanToken);
      
      // Clean up the key string - remove any invalid characters
      String cleanKey = key.replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), '');
      
      // Add padding if needed
      while (cleanKey.length % 4 != 0) {
        cleanKey += '=';
      }
      
      // Verify the key has valid base64 format after cleaning
      if (!RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(cleanKey)) {
        throw Exception('Invalid base64 characters in encryption key');
      }
      
      final keyBytes = base64Decode(cleanKey);
      
      // Extract checksum (last 4 bytes)
      if (encryptedBytes.length < 4) {
        throw Exception('Invalid encrypted token format');
      }
      
      final dataBytes = encryptedBytes.sublist(0, encryptedBytes.length - 4);
      final storedChecksum = encryptedBytes.sublist(encryptedBytes.length - 4);
      
      // Decrypt data
      final decryptedBytes = <int>[];
      for (int i = 0; i < dataBytes.length; i++) {
        final keyIndex = i % keyBytes.length;
        decryptedBytes.add(dataBytes[i] ^ keyBytes[keyIndex]);
      }
      
      // Verify checksum
      final calculatedChecksum = _calculateChecksum(decryptedBytes);
      if (!_compareChecksums(storedChecksum, calculatedChecksum)) {
        throw Exception('Token integrity check failed');
      }
      
      return utf8.decode(decryptedBytes);
    } catch (e) {
      debugPrint('SecureTokenStorage: Decryption failed: $e');
      throw Exception('Token decryption failed');
    }
  }

  /// Calculates a simple checksum for integrity verification
  static List<int> _calculateChecksum(List<int> data) {
    var checksum = 0;
    for (final byte in data) {
      checksum = (checksum + byte) & 0xFFFFFFFF;
    }
    return [
      (checksum >> 24) & 0xFF,
      (checksum >> 16) & 0xFF,
      (checksum >> 8) & 0xFF,
      checksum & 0xFF,
    ];
  }

  /// Compares two checksums for equality
  static bool _compareChecksums(List<int> checksum1, List<int> checksum2) {
    if (checksum1.length != checksum2.length) return false;
    for (int i = 0; i < checksum1.length; i++) {
      if (checksum1[i] != checksum2[i]) return false;
    }
    return true;
  }

  /// Sanitizes input before storage to prevent injection attacks
  static String sanitizeTokenInput(String input) {
    if (input.isEmpty) return input;
    
    // Remove any null bytes, control characters, and potential injection patterns
    String sanitized = input
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '') // Remove control characters
        .replaceAll(RegExp(r'[<>"]'), '') // Remove potential HTML/SQL injection chars
        .replaceAll("'", '')
        .trim();
    
    // Validate token format (basic Confluence token validation)
    if (sanitized.isNotEmpty && !_isValidTokenFormat(sanitized)) {
      debugPrint('SecureTokenStorage: Invalid token format detected');
      return '';
    }
    
    return sanitized;
  }

  /// Validates basic token format
  static bool _isValidTokenFormat(String token) {
    // Basic validation for Confluence API tokens
    // Tokens are typically base64-encoded or alphanumeric with specific patterns
    if (token.length < 10 || token.length > 500) {
      return false;
    }
    
    // Check for valid characters (alphanumeric, +, /, =)
    final validTokenPattern = RegExp(r'^[A-Za-z0-9+/=_-]+$');
    return validTokenPattern.hasMatch(token);
  }

  /// Gets storage statistics for debugging
  static Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final hasToken = await hasConfluenceToken();
      final isValid = hasToken ? await validateStoredToken() : false;
      
      return {
        'hasToken': hasToken,
        'isValid': isValid,
        'platform': defaultTargetPlatform.name,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}