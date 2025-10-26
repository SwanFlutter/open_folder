import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_folder/open_folder.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  final OpenFolder openFolder = OpenFolder();
  String _result = '';
  final _folderPathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    initPlatformState();
    // Set default folder path based on platform
    _setDefaultFolderPath();
  }

  void _setDefaultFolderPath() {
    String defaultPath = '';
    if (Platform.isWindows) {
      defaultPath = 'C:\\Users';
    } else if (Platform.isMacOS) {
      defaultPath = '/Users';
    } else if (Platform.isLinux) {
      defaultPath = '/home';
    } else if (Platform.isAndroid) {
      defaultPath = '/storage/emulated/0/Download';
    } else if (Platform.isIOS) {
      defaultPath = '/var/mobile/Documents';
    }
    _folderPathController.text = defaultPath;
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion =
          await openFolder.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  Future<void> _openFolder() async {
    final folderPath = _folderPathController.text.trim();
    if (folderPath.isEmpty) {
      setState(() {
        _result = 'Please enter a folder path';
      });
      return;
    }

    try {
      final result = await OpenFolder.openFolder(folderPath);
      if (result.isSuccess) {
        setState(() {
          _result = 'Folder opened successfully';
        });
      } else {
        setState(() {
          _result = 'Error: ${result.message}';
        });
      }
      setState(() {
        _result = 'Result: ${result.type}\nMessage: ${result.message}';
      });
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
      });
    }
  }

  @override
  void dispose() {
    _folderPathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Open Folder Plugin Demo',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Open Folder Plugin Demo'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Platform Information',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('Running on: $_platformVersion'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Open Folder',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _folderPathController,
                        decoration: const InputDecoration(
                          labelText: 'Folder Path',
                          hintText:
                              'Enter the path to the folder you want to open',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openFolder,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Open Folder'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_result.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Result',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _result,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              const Spacer(),
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Example Paths',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (Platform.isWindows) ...[
                        const Text('• C:\\Users'),
                        const Text('• C:\\Program Files'),
                        const Text('• C:\\Windows'),
                      ] else if (Platform.isMacOS) ...[
                        const Text('• /Users'),
                        const Text('• /Applications'),
                        const Text('• /System'),
                      ] else if (Platform.isLinux) ...[
                        const Text('• /home'),
                        const Text('• /usr'),
                        const Text('• /var'),
                      ] else if (Platform.isAndroid) ...[
                        const Text('• /storage/emulated/0/Download'),
                        const Text('• /storage/emulated/0/Documents'),
                        const Text('• /storage/emulated/0/Pictures'),
                      ] else if (Platform.isIOS) ...[
                        const Text('• /var/mobile/Documents'),
                        const Text('• /var/mobile/Library'),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
