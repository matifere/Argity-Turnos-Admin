import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateInfo {
  final String latestVersion;
  final String releaseNotes;
  final String downloadUrl;

  AppUpdateInfo({
    required this.latestVersion,
    required this.releaseNotes,
    required this.downloadUrl,
  });
}

class UpdateService {
  static const String updateUrl = 'https://argity.com/update.json';

  /// Revisa si hay una actualización disponible.
  /// Si hay, devuelve un objeto AppUpdateInfo. Si no, devuelve null.
  static Future<AppUpdateInfo?> checkForUpdates() async {
    // Las aplicaciones web no necesitan actualización manual
    if (kIsWeb) return null;

    try {
      // 1. Obtener información de la versión actual instalada
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // ej: '1.0.0'

      // 2. Hacer la petición GET al JSON alojado en tu web
      final response = await http.get(Uri.parse(updateUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Como ahora usarás tu propio servidor/página, leemos el JSON puro
        final actualData = data;

        final latestVersion = actualData['latest_version'] as String;
        final releaseNotes = actualData['release_notes'] as String?;
        final windowsUrl = actualData['windows_url'] as String?;
        final macUrl = actualData['mac_url'] as String?;

        // 3. Comparar las versiones
        if (_isNewerVersion(currentVersion, latestVersion)) {
          return AppUpdateInfo(
            latestVersion: latestVersion,
            releaseNotes:
                releaseNotes ?? 'Hay una nueva actualización disponible.',
            downloadUrl: (Platform.isWindows ? windowsUrl : macUrl) ?? '',
          );
        }
      } else {
        debugPrint(
            'No se pudo verificar actualizaciones: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error verificando actualizaciones: $e');
    }
    return null;
  }

  // Función simple para comparar versiones (ej: 1.0.0 vs 1.0.1)
  static bool _isNewerVersion(String currentVersion, String latestVersion) {
    List<int> currentParts = currentVersion.split('.').map(int.parse).toList();
    List<int> latestParts = latestVersion.split('.').map(int.parse).toList();

    for (int i = 0; i < currentParts.length; i++) {
      if (i >= latestParts.length) return false;
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return latestParts.length > currentParts.length;
  }
}
