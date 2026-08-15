#include <flutter_linux/flutter_linux.h>

#include "include/open_folder/open_folder_plugin.h"

// This file exposes some plugin internals for unit testing. See
// https://github.com/flutter/flutter/issues/88724 for current limitations
// in the unit-testable API.

// Handles the getPlatformVersion method call.
FlMethodResponse *get_platform_version();

// Handles the openFolder method call.
FlMethodResponse *open_folder(FlMethodCall* method_call);
