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

  // Convert UTF-8 path to wide string
  auto utf8_to_wide = [](const std::string& utf8) -> std::wstring {
    if (utf8.empty()) return {};
    int len = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
    std::wstring wide(len, 0);
    MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, wide.data(), len);
    return wide;
  };

  std::wstring wide_path = utf8_to_wide(folder_path);

  // Check if folder exists
  DWORD attrs = GetFileAttributesW(wide_path.c_str());
  if (attrs == INVALID_FILE_ATTRIBUTES) {
    flutter::EncodableMap error_result;
    error_result[flutter::EncodableValue("type")] = flutter::EncodableValue("fileNotFound");
    error_result[flutter::EncodableValue("message")] = flutter::EncodableValue("Folder does not exist: " + folder_path);
    result->Success(flutter::EncodableValue(error_result));
    return;
  }

  if (!(attrs & FILE_ATTRIBUTE_DIRECTORY)) {
    flutter::EncodableMap error_result;
    error_result[flutter::EncodableValue("type")] = flutter::EncodableValue("error");
    error_result[flutter::EncodableValue("message")] = flutter::EncodableValue("Path is not a directory: " + folder_path);
    result->Success(flutter::EncodableValue(error_result));
    return;
  }

  // Open the folder in Windows Explorer.
  // explorer.exe often exits immediately (delegating to a running instance),
  // so ShellExecuteW may return SE_ERR_NOASSOC (31) or similar codes even on
  // success.  Use CreateProcess so we control launch, not exit code.
  std::wstring cmd = std::wstring(L"explorer.exe \"") + wide_path + L"\"";
  STARTUPINFOW si = {};
  si.cb = sizeof(si);
  PROCESS_INFORMATION pi = {};

  BOOL launched = CreateProcessW(
    nullptr,
    cmd.data(),
    nullptr, nullptr,
    FALSE,
    0,
    nullptr, nullptr,
    &si, &pi
  );

  if (launched) {
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    flutter::EncodableMap success_result;
    success_result[flutter::EncodableValue("type")] = flutter::EncodableValue("done");
    success_result[flutter::EncodableValue("message")] = flutter::EncodableValue("Folder opened in Explorer");
    result->Success(flutter::EncodableValue(success_result));
  } else {
    // Fallback: ShellExecuteW with "explore" verb
    HINSTANCE hr = ShellExecuteW(nullptr, L"explore", wide_path.c_str(),
                                  nullptr, nullptr, SW_SHOWNORMAL);
    if (reinterpret_cast<intptr_t>(hr) > 32) {
      flutter::EncodableMap success_result;
      success_result[flutter::EncodableValue("type")] = flutter::EncodableValue("done");
      success_result[flutter::EncodableValue("message")] = flutter::EncodableValue("Folder opened in Explorer");
      result->Success(flutter::EncodableValue(success_result));
    } else {
      flutter::EncodableMap error_result;
      error_result[flutter::EncodableValue("type")] = flutter::EncodableValue("error");
      error_result[flutter::EncodableValue("message")] = flutter::EncodableValue(
          "Failed to open folder: Exit code " + std::to_string(GetLastError()));
      result->Success(flutter::EncodableValue(error_result));
    }
  }
}

}  // namespace open_folder
