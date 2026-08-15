import Flutter
import UIKit

public class OpenFolderPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "open_folder", binaryMessenger: registrar.messenger())
    let instance = OpenFolderPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
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
    
    // On iOS, we can't directly open folders in the file system like on desktop
    // Instead, we'll try to open the Files app or show a document picker
    if #available(iOS 11.0, *) {
      // Try to open Files app with the folder
      if let filesURL = URL(string: "shareddocuments://\(folderURL.path)") {
        DispatchQueue.main.async {
          if UIApplication.shared.canOpenURL(filesURL) {
            UIApplication.shared.open(filesURL) { success in
              if success {
                let successResult = [
                  "type": "done",
                  "message": "Files app opened"
                ]
                result(self.jsonString(from: successResult))
              } else {
                self.openFolderAlternative(folderPath: folderPath, result: result)
              }
            }
          } else {
            self.openFolderAlternative(folderPath: folderPath, result: result)
          }
        }
      } else {
        openFolderAlternative(folderPath: folderPath, result: result)
      }
    } else {
      openFolderAlternative(folderPath: folderPath, result: result)
    }
  }
  
  private func openFolderAlternative(folderPath: String, result: @escaping FlutterResult) {
    // Alternative approach: show document picker or provide information
    DispatchQueue.main.async {
      if let topViewController = self.topViewController() {
        let alert = UIAlertController(
          title: "Folder Location",
          message: "Folder path: \(folderPath)\n\nOn iOS, folders cannot be opened directly. You can access this folder through the Files app.",
          preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
          let infoResult = [
            "type": "done",
            "message": "Folder path shown to user"
          ]
          result(self.jsonString(from: infoResult))
        })
        
        topViewController.present(alert, animated: true)
      } else {
        let errorResult = [
          "type": "error",
          "message": "Cannot display folder information on iOS"
        ]
        result(jsonString(from: errorResult))
      }
    }
  }
  
  private func topViewController() -> UIViewController? {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first else {
      return nil
    }
    
    var topViewController = window.rootViewController
    while let presentedViewController = topViewController?.presentedViewController {
      topViewController = presentedViewController
    }
    
    return topViewController
  }
  
  private func jsonString(from dictionary: [String: Any]) -> String {
    guard let jsonData = try? JSONSerialization.data(withJSONObject: dictionary),
          let jsonString = String(data: jsonData, encoding: .utf8) else {
      return "{\"type\":\"error\",\"message\":\"Failed to serialize result\"}"
    }
    return jsonString
  }
}
