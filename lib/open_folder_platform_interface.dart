import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'open_folder_method_channel.dart';
import 'src/tools/open_result.dart';

abstract class OpenFolderPlatform extends PlatformInterface {
  /// Constructs a OpenFolderPlatform.
  OpenFolderPlatform() : super(token: _token);

  static final Object _token = Object();

  static OpenFolderPlatform _instance = MethodChannelOpenFolder();

  /// The default instance of [OpenFolderPlatform] to use.
  ///
  /// Defaults to [MethodChannelOpenFolder].
  static OpenFolderPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [OpenFolderPlatform] when
  /// they register themselves.
  static set instance(OpenFolderPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Opens a folder at the specified path
  ///
  /// [folderPath] - The path to the folder to open
  /// Returns [OpenResult] indicating success or failure
  Future<OpenResult> openFolder(String folderPath) {
    throw UnimplementedError('openFolder() has not been implemented.');
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
