import 'open_folder_platform_interface.dart';
import 'src/tools/open_result.dart';

/// Main class for opening folders across different platforms
class OpenFolder {
  /// Opens a folder at the specified path
  ///
  /// [folderPath] - The absolute path to the folder to open
  ///
  /// Returns [OpenResult] indicating whether the operation was successful
  ///
  /// Example:
  /// ```dart
  /// final result = await OpenFolder.openFolder('/path/to/folder');
  /// if (result.type == ResultType.done) {
  ///   print('Folder opened successfully');
  /// } else {
  ///   print('Failed to open folder: ${result.message}');
  /// }
  /// ```
  static Future<OpenResult> openFolder(String folderPath) {
    return OpenFolderPlatform.instance.openFolder(folderPath);
  }

  /// Gets the platform version (for debugging purposes)
  Future<String?> getPlatformVersion() {
    return OpenFolderPlatform.instance.getPlatformVersion();
  }

  /// Register the plugin with the Flutter engine
  /// This method is called by the Flutter framework during plugin registration
  static void registerWith() {
    // This method is intentionally empty as the actual registration
    // is handled by the platform-specific plugin implementations
  }
}
