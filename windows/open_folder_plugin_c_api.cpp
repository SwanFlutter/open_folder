#include "include/open_folder/open_folder_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "open_folder_plugin.h"

void OpenFolderPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  open_folder::OpenFolderPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
