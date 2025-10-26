Here is the English version of your `open_folder` plugin documentation:

---

# open_folder

A Flutter plugin to open folders on Android, iOS, macOS, Windows, and Linux platforms.

---

## Features
- ✅ Support for all major Flutter platforms
- ✅ Open folders in the system's default file manager
- ✅ Error handling and result management
- ✅ Simple and easy-to-use API

---

## Installation

### 1. Add dependency to pubspec.yaml

```yaml
dependencies:
  open_folder: ^0.0.1
```

### 2. Install the package

```bash
flutter pub get
```

## Usage

### Import the package

```dart
import 'package:open_folder/open_folder.dart';
```

### Basic Example

```dart
import 'package:flutter/material.dart';
import 'package:open_folder/open_folder.dart';

class FolderOpenerWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        final result = await OpenFolder.openFolder('/path/to/folder');
        
        if (result.isSuccess) {
          print('Folder opened successfully');
        } else {
          print('Error: ${result.message}');
        }
      },
      child: Text('Open Folder'),
    );
  }
}
```

### Complete Example

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_folder/open_folder.dart';

class FolderOpenerApp extends StatefulWidget {
  @override
  _FolderOpenerAppState createState() => _FolderOpenerAppState();
}

class _FolderOpenerAppState extends State<FolderOpenerApp> {
  final _controller = TextEditingController();
  String _result = '';

  @override
  void initState() {
    super.initState();
    _setDefaultPath();
  }

  void _setDefaultPath() {
    if (Platform.isWindows) {
      _controller.text = 'C:\\Users';
    } else if (Platform.isMacOS) {
      _controller.text = '/Users';
    } else if (Platform.isLinux) {
      _controller.text = '/home';
    } else if (Platform.isAndroid) {
      _controller.text = '/storage/emulated/0/Download';
    } else if (Platform.isIOS) {
      _controller.text = '/var/mobile/Documents';
    }
  }

  Future<void> _openFolder() async {
    final path = _controller.text.trim();
    if (path.isEmpty) return;

    final result = await OpenFolder.openFolder(path);
    
    setState(() {
      if (result.isSuccess) {
        _result = 'Folder opened successfully';
      } else {
        _result = 'Error: ${result.message}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Open Folder Example')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Folder Path',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _openFolder,
              child: Text('Open Folder'),
            ),
            SizedBox(height: 16),
            Text(_result),
          ],
        ),
      ),
    );
  }
}
```

---

## Platform Setup

### Android
No additional setup required. The plugin automatically adds necessary permissions.

**Added Permissions:**
- `READ_EXTERNAL_STORAGE`
- `WRITE_EXTERNAL_STORAGE`

### iOS
No additional setup required. The plugin uses the Files app.

### macOS
No additional setup required. The plugin uses Finder.

### Windows
No additional setup required. The plugin uses Windows Explorer.

### Linux
The plugin supports various Linux file managers:
- `xdg-open` (Default)
- `nautilus` (GNOME)
- `dolphin` (KDE)
- `thunar` (XFCE)
- `pcmanfm` (LXDE)
- `caja` (MATE)

---

## API Reference

### `OpenFolder.openFolder(String folderPath)`
Opens the specified folder.

**Parameters:**
- `folderPath`: Absolute path to the folder

**Returns:**
- `Future<OpenResult>`: Operation result

### `OpenResult`
Result class for folder opening operations.

**Properties:**
- `type`: Result type (`ResultType.done`, `ResultType.error`, `ResultType.cancelled`)
- `message`: Additional message (optional)
- `isSuccess`: Whether the operation was successful
- `isError`: Whether an error occurred
- `isCancelled`: Whether the operation was cancelled

---

## Path Examples
```dart
// Windows
await OpenFolder.openFolder('C:\\Users\\Username\\Documents');

// macOS/Linux
await OpenFolder.openFolder('/Users/username/Documents');

// Android
await OpenFolder.openFolder('/storage/emulated/0/Download');

// iOS
await OpenFolder.openFolder('/var/mobile/Documents');
```

---

## Common Issues

### Android
- Ensure the folder path is valid
- Android 11+ may have restrictions

### iOS
- Only folders accessible in the Files app can be opened
- System paths may be restricted

---

## License
This project is licensed under the MIT License.

---

## Contributing
To contribute to this project, please submit a Pull Request.