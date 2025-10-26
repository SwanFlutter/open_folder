// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:open_folder/open_folder.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('OpenFolder Plugin Tests', () {
    testWidgets('getPlatformVersion test', (WidgetTester tester) async {
      final OpenFolder plugin = OpenFolder();
      final String? version = await plugin.getPlatformVersion();
      // The version string depends on the host platform running the test, so
      // just assert that some non-empty string is returned.
      expect(version?.isNotEmpty, true);
    });

    testWidgets('openFolder with valid path test', (WidgetTester tester) async {
      // Test with Downloads folder (commonly available on all platforms)
      String testPath;

      if (Platform.isAndroid) {
        testPath = '/storage/emulated/0/Download';
      } else if (Platform.isIOS) {
        testPath = '/var/mobile/Containers/Data/Application';
      } else if (Platform.isWindows) {
        testPath = '${Platform.environment['USERPROFILE']!}\\Downloads';
      } else if (Platform.isMacOS) {
        testPath = '${Platform.environment['HOME']!}/Downloads';
      } else if (Platform.isLinux) {
        testPath = '${Platform.environment['HOME']!}/Downloads';
      } else {
        testPath = '/tmp'; // Fallback for other platforms
      }

      final result = await OpenFolder.openFolder(testPath);

      // Check that we get a valid result
      expect(result, isNotNull);
      expect(result.type, isNotNull);

      // The result should be either success or an error (not null)
      expect(
        [
          ResultType.done,
          ResultType.fileNotFound,
          ResultType.noAppToOpen,
          ResultType.permissionDenied,
          ResultType.error,
        ].contains(result.type),
        true,
      );
    });

    testWidgets('openFolder with invalid path test', (
      WidgetTester tester,
    ) async {
      const String invalidPath = '/this/path/does/not/exist/anywhere';

      final result = await OpenFolder.openFolder(invalidPath);

      // Should return fileNotFound error
      expect(result, isNotNull);
      expect(result.type, ResultType.fileNotFound);
      expect(result.message, contains('does not exist'));
    });

    testWidgets('openFolder with empty path test', (WidgetTester tester) async {
      const String emptyPath = '';

      final result = await OpenFolder.openFolder(emptyPath);

      // Should return error for empty path
      expect(result, isNotNull);
      expect(result.type, ResultType.error);
    });

    testWidgets('openFolder with file instead of folder test', (
      WidgetTester tester,
    ) async {
      // Create a temporary file for testing
      final tempDir = Directory.systemTemp;
      final testFile = File('${tempDir.path}/test_file.txt');

      try {
        await testFile.writeAsString('test content');

        final result = await OpenFolder.openFolder(testFile.path);

        // Should return error because it's a file, not a directory
        expect(result, isNotNull);
        expect(result.type, ResultType.error);
        expect(result.message, contains('not a directory'));
      } finally {
        // Clean up
        if (await testFile.exists()) {
          await testFile.delete();
        }
      }
    });

    testWidgets('openFolder with common system folders test', (
      WidgetTester tester,
    ) async {
      // Test with platform-specific common folders
      List<String> testPaths = [];

      if (Platform.isAndroid) {
        testPaths = [
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Documents',
          '/storage/emulated/0/Pictures',
          '/storage/emulated/0/DCIM',
        ];
      } else if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE']!;
        testPaths = [
          '$userProfile\\Downloads',
          '$userProfile\\Documents',
          '$userProfile\\Pictures',
        ];
      } else if (Platform.isMacOS || Platform.isLinux) {
        final home = Platform.environment['HOME']!;
        testPaths = ['$home/Downloads', '$home/Documents', '$home/Pictures'];
      }

      for (String path in testPaths) {
        final result = await OpenFolder.openFolder(path);

        // Each result should be valid (either success or a known error type)
        expect(result, isNotNull);
        expect(result.type, isNotNull);

        // Print result for debugging
        print(
          'Path: $path, Result: ${result.type}, Message: ${result.message}',
        );

        // Should not be null or unknown error
        expect(
          [
            ResultType.done,
            ResultType.fileNotFound,
            ResultType.noAppToOpen,
            ResultType.permissionDenied,
            ResultType.error,
          ].contains(result.type),
          true,
        );
      }
    });
  });
}
