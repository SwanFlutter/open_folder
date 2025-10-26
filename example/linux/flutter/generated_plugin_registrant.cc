//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <open_folder/open_folder_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) open_folder_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "OpenFolderPlugin");
  open_folder_plugin_register_with_registrar(open_folder_registrar);
}
