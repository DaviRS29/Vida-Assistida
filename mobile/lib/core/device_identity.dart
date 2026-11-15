import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Identidade criptográfica do aparelho para o segundo fator.
///
/// Um par de chaves Ed25519 é gerado no primeiro acesso e a semente privada
/// fica no armazenamento seguro do sistema (Android Keystore / iOS Keychain;
/// no navegador, armazenamento cifrado). O servidor recebe só a chave pública.
class DeviceIdentity {
  DeviceIdentity({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _idKey = 'vida_device_id';
  static const _seedKey = 'vida_device_seed';
  final FlutterSecureStorage _storage;
  final _algorithm = Ed25519();

  /// Identificador do aparelho, se ele já possui chave registrada aqui.
  Future<String?> existingId() async {
    try {
      final id = await _storage.read(key: _idKey);
      final seed = await _storage.read(key: _seedKey);
      return id != null && seed != null ? id : null;
    } catch (_) {
      return null;
    }
  }

  /// Garante que exista um par de chaves e devolve os dados públicos.
  Future<DeviceInfo> ensure() async {
    var id = await existingId();
    var seedText = id == null ? null : await _storage.read(key: _seedKey);
    if (id == null || seedText == null) {
      final random = Random.secure();
      id = base64UrlEncode(
        List<int>.generate(18, (_) => random.nextInt(256)),
      ).replaceAll('=', '');
      seedText = base64Encode(
        List<int>.generate(32, (_) => random.nextInt(256)),
      );
      await _storage.write(key: _seedKey, value: seedText);
      await _storage.write(key: _idKey, value: id);
    }
    final keyPair = await _algorithm.newKeyPairFromSeed(base64Decode(seedText));
    final publicKey = await keyPair.extractPublicKey();
    return DeviceInfo(
      deviceId: id,
      deviceName: describePlatform(),
      publicKey: base64Encode(publicKey.bytes),
    );
  }

  /// Assina o desafio enviado pelo servidor com a chave privada do aparelho.
  Future<String> sign(String message) async {
    final seed = await _storage.read(key: _seedKey);
    if (seed == null) throw StateError('Chave do aparelho ausente.');
    final keyPair = await _algorithm.newKeyPairFromSeed(base64Decode(seed));
    final signature = await _algorithm.sign(
      utf8.encode(message),
      keyPair: keyPair,
    );
    return base64Encode(signature.bytes);
  }

  static String describePlatform() {
    if (kIsWeb) return 'Navegador';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Celular Android',
      TargetPlatform.iOS => 'iPhone',
      TargetPlatform.windows => 'Computador Windows',
      TargetPlatform.macOS => 'Computador Mac',
      TargetPlatform.linux => 'Computador Linux',
      TargetPlatform.fuchsia => 'Aparelho',
    };
  }
}

class DeviceInfo {
  const DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.publicKey,
  });

  final String deviceId;
  final String deviceName;
  final String publicKey;

  Map<String, String> toJson() => {
    'deviceId': deviceId,
    'deviceName': deviceName,
    'publicKey': publicKey,
  };
}
