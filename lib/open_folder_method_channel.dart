import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'open_folder_platform_interface.dart';
import 'src/tools/open_result.dart';

/// An implementation of [OpenFolderPlatform] that uses method channels.
class MethodChannelOpenFolder extends OpenFolderPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('open_folder');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<OpenResult> openFolder(String folderPath) async {
    // For desktop platforms, use native system commands
    if (!Platform.isIOS && !Platform.isAndroid) {
      return _openFolderDesktop(folderPath);
    }

    // For mobile platforms, use method channel
    try {
      final Map<String, String> arguments = {'folder_path': folderPath};

      final result = await methodChannel.invokeMethod<String>(
        'openFolder',
        arguments,
      );

      if (result != null) {
        final resultMap = json.decode(result) as Map<String, dynamic>;
        return OpenResult.fromJson(resultMap);
      } else {
        return const OpenResult(
          type: ResultType.error,
          message: 'Failed to open folder: No response from platform',
        );
      }
    } on PlatformException catch (e) {
      return OpenResult(
        type: ResultType.error,
        message: 'Failed to open folder: ${e.message}',
      );
    } catch (e) {
      return OpenResult(
        type: ResultType.error,
        message: 'Failed to open folder: $e',
      );
    }
  }

  Future<OpenResult> _openFolderDesktop(String folderPath) async {
    try {
      int result = -1;

      if (Platform.isMacOS) {
        // Use 'open' command on macOS
        final process = await Process.start('open', [folderPath]);
        result = await process.exitCode;
      } else if (Platform.isWindows) {
        // Use 'explorer' command on Windows
        final process = await Process.start('explorer', [folderPath]);
        result = await process.exitCode;
      } else if (Platform.isLinux) {
        // Try different file managers on Linux
        List<String> fileManagers = [
          'xdg-open',
          'nautilus',
          'dolphin',
          'thunar',
        ];

        for (String manager in fileManagers) {
          try {
            final process = await Process.start(manager, [folderPath]);
            result = await process.exitCode;
            if (result == 0) break;
          } catch (e) {
            continue; // Try next file manager
          }
        }
      } else {
        return const OpenResult(
          type: ResultType.error,
          message: 'Unsupported platform',
        );
      }

      return OpenResult(
        type: result == 0 ? ResultType.done : ResultType.error,
        message: result == 0
            ? 'Folder opened successfully'
            : 'Failed to open folder: Exit code $result',
      );
    } catch (e) {
      return OpenResult(
        type: ResultType.error,
        message: 'Failed to open folder: $e',
      );
    }
  }
}
