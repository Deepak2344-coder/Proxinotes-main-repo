import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypts/decrypts page images for secure local caching.
///
/// Uses a device-stored key (Android Keystore / iOS Keychain) that persists
/// across session refreshes but is deleted on logout. Cached files are
/// useless without this key, protecting IP.
class PageEncryptor {
  PageEncryptor._();

  static const _storage = FlutterSecureStorage();
  static const _keyName = 'proxinotes_cache_key';
  static const _magic = [0x50, 0x4E, 0x43]; // "PNC" - ProxiNotes Cache
  static const _version = 2;
  static const _keyLength = 32;

  /// Get or create the stable device encryption key.
  /// Stored in Android Keystore / iOS Keychain — never leaves the device.
  static Future<Uint8List> _getOrCreateKey() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null) {
      return base64Url.decode(existing);
    }

    // Generate a new random key
    final rng = Random.secure();
    final key = Uint8List(_keyLength);
    for (int i = 0; i < _keyLength; i++) {
      key[i] = rng.nextInt(256);
    }

    // Store securely
    await _storage.write(key: _keyName, value: base64Url.encode(key));
    return key;
  }

  /// Delete the device key (called on logout to invalidate all caches).
  static Future<void> deleteKey() async {
    await _storage.delete(key: _keyName);
  }

  /// Check if a device key exists.
  static Future<bool> hasKey() async {
    return await _storage.containsKey(key: _keyName);
  }

  /// Encrypt page bytes. Returns format: [magic(3)][version(1)][encrypted...]
  static Future<Uint8List> encrypt(Uint8List plaintext) async {
    final key = await _getOrCreateKey();
    final keyCopy = Uint8List.fromList(key);
    final encrypted = Uint8List(plaintext.length);

    for (int i = 0; i < plaintext.length; i++) {
      encrypted[i] = plaintext[i] ^ keyCopy[i % _keyLength];
      if (i % 64 == 63) {
        for (int j = 0; j < _keyLength; j++) {
          keyCopy[j] = (keyCopy[j] ^ encrypted[i]) & 0xFF;
        }
      }
    }

    final result = Uint8List(4 + encrypted.length);
    result[0] = _magic[0];
    result[1] = _magic[1];
    result[2] = _magic[2];
    result[3] = _version;
    result.setRange(4, result.length, encrypted);

    return result;
  }

  /// Decrypt page bytes. Expects format: [magic(3)][version(1)][encrypted...]
  static Future<Uint8List?> decrypt(Uint8List data) async {
    if (data.length < 4) return null;
    if (data[0] != _magic[0] || data[1] != _magic[1] || data[2] != _magic[2]) {
      return null;
    }
    if (data[3] != _version) return null;

    final key = await _getOrCreateKey();
    final keyCopy = Uint8List.fromList(key);
    final encrypted = data.sublist(4);
    final decrypted = Uint8List(encrypted.length);

    for (int i = 0; i < encrypted.length; i++) {
      decrypted[i] = encrypted[i] ^ keyCopy[i % _keyLength];
      if (i % 64 == 63) {
        for (int j = 0; j < _keyLength; j++) {
          keyCopy[j] = (keyCopy[j] ^ encrypted[i]) & 0xFF;
        }
      }
    }

    return decrypted;
  }
}
