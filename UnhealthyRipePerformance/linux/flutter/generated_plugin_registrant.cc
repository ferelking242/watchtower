//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <gtk/gtk_plugin.h>
#include <isar_community_flutter_libs/isar_flutter_libs_plugin.h>
#include <m_extension_server/m_extension_server_plugin.h>
#include <url_launcher_linux/url_launcher_plugin.h>
#include <window_to_front/window_to_front_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) gtk_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "GtkPlugin");
  gtk_plugin_register_with_registrar(gtk_registrar);
  g_autoptr(FlPluginRegistrar) isar_community_flutter_libs_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "IsarFlutterLibsPlugin");
  isar_flutter_libs_plugin_register_with_registrar(isar_community_flutter_libs_registrar);
  g_autoptr(FlPluginRegistrar) m_extension_server_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "MExtensionServerPlugin");
  m_extension_server_plugin_register_with_registrar(m_extension_server_registrar);
  g_autoptr(FlPluginRegistrar) url_launcher_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "UrlLauncherPlugin");
  url_launcher_plugin_register_with_registrar(url_launcher_linux_registrar);
  g_autoptr(FlPluginRegistrar) window_to_front_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "WindowToFrontPlugin");
  window_to_front_plugin_register_with_registrar(window_to_front_registrar);
}
