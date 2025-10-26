#include "include/open_folder/open_folder_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>
#include <glib.h>
#include <gio/gio.h>
#include <sys/stat.h>
#include <unistd.h>

#include <cstring>

#include "open_folder_plugin_private.h"

#define OPEN_FOLDER_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), open_folder_plugin_get_type(), \
                              OpenFolderPlugin))

struct _OpenFolderPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(OpenFolderPlugin, open_folder_plugin, g_object_get_type())

// Called when a method call is received from Flutter.
static void open_folder_plugin_handle_method_call(
    OpenFolderPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "getPlatformVersion") == 0) {
    response = get_platform_version();
  } else if (strcmp(method, "openFolder") == 0) {
    response = open_folder(method_call);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

FlMethodResponse* get_platform_version() {
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar *version = g_strdup_printf("Linux %s", uname_data.version);
  g_autoptr(FlValue) result = fl_value_new_string(version);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

FlMethodResponse* open_folder(FlMethodCall* method_call) {
  FlValue* args = fl_method_call_get_args(method_call);
  
  if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    g_autoptr(FlValue) error_result = fl_value_new_map();
    fl_value_set_string_take(error_result, "type", fl_value_new_string("error"));
    fl_value_set_string_take(error_result, "message", fl_value_new_string("Invalid arguments"));
    return FL_METHOD_RESPONSE(fl_method_success_response_new(error_result));
  }

  FlValue* folder_path_value = fl_value_lookup_string(args, "folder_path");
  if (folder_path_value == nullptr || fl_value_get_type(folder_path_value) != FL_VALUE_TYPE_STRING) {
    g_autoptr(FlValue) error_result = fl_value_new_map();
    fl_value_set_string_take(error_result, "type", fl_value_new_string("error"));
    fl_value_set_string_take(error_result, "message", fl_value_new_string("Folder path is required"));
    return FL_METHOD_RESPONSE(fl_method_success_response_new(error_result));
  }

  const gchar* folder_path = fl_value_get_string(folder_path_value);
  
  // Check if folder exists
  struct stat st;
  if (stat(folder_path, &st) != 0) {
    g_autoptr(FlValue) error_result = fl_value_new_map();
    fl_value_set_string_take(error_result, "type", fl_value_new_string("fileNotFound"));
    g_autofree gchar* error_msg = g_strdup_printf("Folder does not exist: %s", folder_path);
    fl_value_set_string_take(error_result, "message", fl_value_new_string(error_msg));
    return FL_METHOD_RESPONSE(fl_method_success_response_new(error_result));
  }

  // Check if it's a directory
  if (!S_ISDIR(st.st_mode)) {
    g_autoptr(FlValue) error_result = fl_value_new_map();
    fl_value_set_string_take(error_result, "type", fl_value_new_string("error"));
    g_autofree gchar* error_msg = g_strdup_printf("Path is not a directory: %s", folder_path);
    fl_value_set_string_take(error_result, "message", fl_value_new_string(error_msg));
    return FL_METHOD_RESPONSE(fl_method_success_response_new(error_result));
  }

  // Try to open folder using various file managers
  const gchar* commands[] = {
    "xdg-open",
    "nautilus",
    "dolphin",
    "thunar",
    "pcmanfm",
    "caja",
    nullptr
  };

  gboolean success = FALSE;
  for (int i = 0; commands[i] != nullptr && !success; i++) {
    g_autofree gchar* command = g_strdup_printf("%s \"%s\"", commands[i], folder_path);
    
    // Check if command exists
    g_autofree gchar* which_command = g_strdup_printf("which %s", commands[i]);
    if (system(which_command) == 0) {
      // Command exists, try to execute it
      if (system(command) == 0) {
        success = TRUE;
      }
    }
  }

  if (success) {
    g_autoptr(FlValue) success_result = fl_value_new_map();
    fl_value_set_string_take(success_result, "type", fl_value_new_string("done"));
    fl_value_set_string_take(success_result, "message", fl_value_new_string("Folder opened"));
    return FL_METHOD_RESPONSE(fl_method_success_response_new(success_result));
  } else {
    g_autoptr(FlValue) error_result = fl_value_new_map();
    fl_value_set_string_take(error_result, "type", fl_value_new_string("error"));
    fl_value_set_string_take(error_result, "message", fl_value_new_string("Failed to open folder - no suitable file manager found"));
    return FL_METHOD_RESPONSE(fl_method_success_response_new(error_result));
  }
}

static void open_folder_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(open_folder_plugin_parent_class)->dispose(object);
}

static void open_folder_plugin_class_init(OpenFolderPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = open_folder_plugin_dispose;
}

static void open_folder_plugin_init(OpenFolderPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  OpenFolderPlugin* plugin = OPEN_FOLDER_PLUGIN(user_data);
  open_folder_plugin_handle_method_call(plugin, method_call);
}

void open_folder_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  OpenFolderPlugin* plugin = OPEN_FOLDER_PLUGIN(
      g_object_new(open_folder_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "open_folder",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
