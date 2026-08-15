import Cocoa
import FlutterMacOS

public class OpenFolderPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "open_folder", binaryMessenger: registrar.messenger)
    let instance = OpenFolderPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
    case "openFolder":
      if let args = call.arguments as? [String: Any],
         let folderPath = args["folder_path"] as? String {
        openFolder(folderPath: folderPath, result: result)
      } else {
        let errorResult = [
          "type": "error",
          "message": "Folder path is required"
        ]
        result(jsonString(from: errorResult))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func openFolder(folderPath: String, result: @escaping FlutterResult) {
    let fileManager = FileManager.default
    let folderURL = URL(fileURLWithPath: folderPath)
    
    // Check if folder exists
    guard fileManager.fileExists(atPath: folderPath) else {
      let errorResult = [
        "type": "fileNotFound",
        "message": "Folder does not exist: \(folderPath)"
      ]
      result(jsonString(from: errorResult))
      return
    }
    
    // Check if it's a directory
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: folderPath, isDirectory: &isDirectory),
          isDirectory.boolValue else {
      let errorResult = [
        "type": "error",
        "message": "Path is not a directory: \(folderPath)"
      ]
      result(jsonString(from: errorResult))
      return
    }
    
    // Open folder in Finder on macOS
    DispatchQueue.main.async {
      let success = NSWorkspace.shared.open(folderURL)
      
      if success {
        let successResult = [
          "type": "done",
          "message": "Folder opened in Finder"
        ]
        result(self.jsonString(from: successResult))
      } else {
        // Try alternative approach
        self.openFolderAlternative(folderPath: folderPath, result: result)
      }
    }
  }
  
  private func openFolderAlternative(folderPath: String, result: @escaping FlutterResult) {
    // Try using NSWorkspace to select the folder in Finder
    DispatchQueue.main.async {
      let folderURL = URL(fileURLWithPath: folderPath)
      let success = NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folderURL.path)
      
      if success {
        let successResult = [
          "type": "done",
          "message": "Folder selected in Finder"
        ]
        result(self.jsonString(from: successResult))
      } else {
        // Last resort: try using 'open' command
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [folderPath]
        
        do {
          try task.run()
          task.waitUntilExit()
          
          if task.terminationStatus == 0 {
            let successResult = [
              "type": "done",
              "message": "Folder opened using system command"
            ]
            result(self.jsonString(from: successResult))
          } else {
            let errorResult = [
              "type": "error",
              "message": "Failed to open folder: Process exited with code \(task.terminationStatus)"
            ]
            result(self.jsonString(from: errorResult))
          }
        } catch {
          let errorResult = [
            "type": "error",
            "message": "Failed to open folder: \(error.localizedDescription)"
          ]
          result(self.jsonString(from: errorResult))
        }
      }
    }
  }
  
  private func jsonString(from dictionary: [String: Any]) -> String {
    guard let jsonData = try? JSONSerialization.data(withJSONObject: dictionary),
          let jsonString = String(data: jsonData, encoding: .utf8) else {
      return "{\"type\":\"error\",\"message\":\"Failed to serialize result\"}"
    }
    return jsonString
  }
}
