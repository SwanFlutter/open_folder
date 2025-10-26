#include "open_folder_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>
#include <shellapi.h>
#include <shlobj.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>
#include <string>
#include <filesystem>

namespace open_folder {

// static
void OpenFolderPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "open_folder",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<OpenFolderPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

OpenFolderPlugin::OpenFolderPlugin() {}

OpenFolderPlugin::~OpenFolderPlugin() {}

void OpenFolderPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("getPlatformVersion") == 0) {
    std::ostringstream version_stream;
    version_stream << "Windows ";
    if (IsWindows10OrGreater()) {
      version_stream << "10+";
    } else if (IsWindows8OrGreater()) {
      version_stream << "8";
    } else if (IsWindows7OrGreater()) {
      version_stream << "7";
    }
    result->Success(flutter::EncodableValue(version_stream.str()));
  } else if (method_call.method_name().compare("openFolder") == 0) {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (arguments) {
      auto folder_path_it = arguments->find(flutter::EncodableValue("folder_path"));
      if (folder_path_it != arguments->end()) {
        const auto* folder_path = std::get_if<std::string>(&folder_path_it->second);
        if (folder_path) {
          OpenFolder(*folder_path, std::move(result));
          return;
        }
      }
    }
    
    // Error: folder_path not provided
    flutter::EncodableMap error_result;
    error_result[flutter::EncodableValue("type")] = flutter::EncodableValue("error");
    error_result[flutter::EncodableValue("message")] = flutter::EncodableValue("Folder path is required");
    result->Success(flutter::EncodableValue(error_result));
  } else {
    result->NotImplemented();
  }
}

void OpenFolderPlugin::OpenFolder(const std::string& folder_path,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  // Check if folder exists
  std::filesystem::path path(folder_path);
  if (!std::filesystem::exists(path)) {
    flutter::EncodableMap error_result;
    error_result[flutter::EncodableValue("type")] = flutter::EncodableValue("fileNotFound");
    error_result[flutter::EncodableValue("message")] = flutter::EncodableValue("Folder does not exist: " + folder_path);
    result->Success(flutter::EncodableValue(error_result));
    return;
  }

  // Check if it's a directory
  if (!std::filesystem::is_directory(path)) {
    flutter::EncodableMap error_result;
    error_result[flutter::EncodableValue("type")] = flutter::EncodableValue("error");
    error_result[flutter::EncodableValue("message")] = flutter::EncodableValue("Path is not a directory: " + folder_path);
    result->Success(flutter::EncodableValue(error_result));
    return;
  }

  // Convert to wide string for Windows API
  std::wstring wide_path = std::filesystem::path(folder_path).wstring();
  
  // Try to open folder in Windows Explorer
  HINSTANCE result_code = ShellExecuteW(
    NULL,                    // Parent window
    L"explore",              // Verb (explore opens in Explorer)
    wide_path.c_str(),       // File/folder to open
    NULL,                    // Parameters
    NULL,                    // Working directory
    SW_SHOWNORMAL            // Show command
  );

  // ShellExecute returns a value > 32 on success
  if (reinterpret_cast<intptr_t>(result_code) > 32) {
    flutter::EncodableMap success_result;
    success_result[flutter::EncodableValue("type")] = flutter::EncodableValue("done");
    success_result[flutter::EncodableValue("message")] = flutter::EncodableValue("Folder opened in Explorer");
    result->Success(flutter::EncodableValue(success_result));
  } else {
    // Try alternative approach using ShellExecute with "open"
    HINSTANCE alt_result = ShellExecuteW(
      NULL,
      L"open",
      wide_path.c_str(),
      NULL,
      NULL,
      SW_SHOWNORMAL
    );

    if (reinterpret_cast<intptr_t>(alt_result) > 32) {
      flutter::EncodableMap success_result;
      success_result[flutter::EncodableValue("type")] = flutter::EncodableValue("done");
      success_result[flutter::EncodableValue("message")] = flutter::EncodableValue("Folder opened");
      result->Success(flutter::EncodableValue(success_result));
    } else {
      // Last resort: try using system command
      std::string command = "explorer \"" + folder_path + "\"";
      int system_result = system(command.c_str());
      
      if (system_result == 0) {
        flutter::EncodableMap success_result;
        success_result[flutter::EncodableValue("type")] = flutter::EncodableValue("done");
        success_result[flutter::EncodableValue("message")] = flutter::EncodableValue("Folder opened using system command");
        result->Success(flutter::EncodableValue(success_result));
      } else {
        flutter::EncodableMap error_result;
        error_result[flutter::EncodableValue("type")] = flutter::EncodableValue("error");
        error_result[flutter::EncodableValue("message")] = flutter::EncodableValue("Failed to open folder");
        result->Success(flutter::EncodableValue(error_result));
      }
    }
  }
}

}  // namespace open_folder
