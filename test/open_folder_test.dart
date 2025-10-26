import 'package:flutter_test/flutter_test.dart';
import 'package:open_folder/open_folder.dart';
import 'package:open_folder/open_folder_method_channel.dart';
import 'package:open_folder/open_folder_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockOpenFolderPlatform
    with MockPlatformInterfaceMixin
    implements OpenFolderPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<OpenResult> openFolder(String folderPath) {
    throw UnimplementedError();
  }
}

void main() {
  final OpenFolderPlatform initialPlatform = OpenFolderPlatform.instance;

  test('$MethodChannelOpenFolder is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelOpenFolder>());
  });

  test('getPlatformVersion', () async {
    OpenFolder openFolderPlugin = OpenFolder();
    MockOpenFolderPlatform fakePlatform = MockOpenFolderPlatform();
    OpenFolderPlatform.instance = fakePlatform;

    expect(await openFolderPlugin.getPlatformVersion(), '42');
  });
}
