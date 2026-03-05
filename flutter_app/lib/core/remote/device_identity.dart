import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdentity {
  static const _keyDeviceId = 'deviceId';
  static const _keyPrivate = 'ed25519_private';
  static const _keyPublic = 'ed25519_public';

  final SharedPreferences _prefs;
  final Ed25519 _algo = Ed25519();

  DeviceIdentity._(this._prefs);

  static Future<DeviceIdentity> load() async {
    final prefs = await SharedPreferences.getInstance();
    final identity = DeviceIdentity._(prefs);
    await identity._ensureKeys();
    return identity;
  }

  String get deviceId {
    final existing = _prefs.getString(_keyDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final newId = const Uuid().v4();
    _prefs.setString(_keyDeviceId, newId);
    return newId;
  }

  /// Base64-encoded raw Ed25519 public key bytes.
  String get publicKeyBase64 => _prefs.getString(_keyPublic)!;

  String get publicKeyFingerprint {
    final bytes = base64Decode(publicKeyBase64);
    final hash = sha256.convert(bytes).bytes;
    final first8 = hash.take(8);
    return first8.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<String> signBase64(Uint8List data) async {
    final kp = await _keyPair();
    final sig = await _algo.sign(data, keyPair: kp);
    return base64Encode(sig.bytes);
  }

  Future<KeyPair> _keyPair() async {
    final priv = base64Decode(_prefs.getString(_keyPrivate)!);
    final pub = base64Decode(_prefs.getString(_keyPublic)!);
    final keyPairData = SimpleKeyPairData(
      priv,
      publicKey: SimplePublicKey(pub, type: KeyPairType.ed25519),
      type: KeyPairType.ed25519,
    );
    return keyPairData;
  }

  Future<void> _ensureKeys() async {
    final hasPriv = (_prefs.getString(_keyPrivate) ?? '').isNotEmpty;
    final hasPub = (_prefs.getString(_keyPublic) ?? '').isNotEmpty;
    if (hasPriv && hasPub) return;

    final kp = await _algo.newKeyPair();
    final priv = await kp.extractPrivateKeyBytes();
    final pub = await kp.extractPublicKey();
    _prefs.setString(_keyPrivate, base64Encode(priv));
    _prefs.setString(_keyPublic, base64Encode(pub.bytes));
  }
}

/// Minimal UUID generator (avoid pulling in the full model layer).
class Uuid {
  const Uuid();

  String v4() {
    final bytes = Uint8List(16);
    final rnd = SecureRandom();
    rnd.nextBytes(bytes);

    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;

    String hex(int v) => v.toRadixString(16).padLeft(2, '0');
    final b = bytes;
    return '${hex(b[0])}${hex(b[1])}${hex(b[2])}${hex(b[3])}-'
        '${hex(b[4])}${hex(b[5])}-'
        '${hex(b[6])}${hex(b[7])}-'
        '${hex(b[8])}${hex(b[9])}-'
        '${hex(b[10])}${hex(b[11])}${hex(b[12])}${hex(b[13])}${hex(b[14])}${hex(b[15])}';
  }
}

/// Cryptographically secure random bytes generator using `cryptography`.
class SecureRandom {
  final _rng = Cryptography.instance.random;

  void nextBytes(Uint8List bytes) {
    final generated = _rng.nextBytes(bytes.length);
    bytes.setAll(0, generated);
  }
}
