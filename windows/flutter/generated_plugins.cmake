#
# Generated file, do not edit.
#

list(APPEND FLUTTER_PLUGIN_LIST
  app_links
  bonsoir_windows
  connectivity_plus
  desktop_webview_window
  dynamic_color
  file_selector_windows
  flutter_inappwebview_windows
  flutter_new_pipe_extractor
  flutter_qjs
  flutter_secure_storage_windows
  flutter_timezone
  flutter_tts
  isar_community_flutter_libs
  local_auth_windows
  local_notifier
  m_extension_server
  media_kit_libs_windows_video
  media_kit_video
  permission_handler_windows
  screen_brightness_windows
  screen_retriever_windows
  share_plus
  speech_to_text_windows
  sqlite3_flutter_libs
  syncfusion_pdfviewer_windows
  tray_manager
  url_launcher_windows
  volume_controller
  window_manager
  window_to_front
)

list(APPEND FLUTTER_FFI_PLUGIN_LIST
  flutter_discord_rpc_fork
  metadata_god
  rust_lib_watchtower
  smtc_windows
)

set(PLUGIN_BUNDLED_LIBRARIES)

foreach(plugin ${FLUTTER_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${plugin}/windows plugins/${plugin})
  target_link_libraries(${BINARY_NAME} PRIVATE ${plugin}_plugin)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES $<TARGET_FILE:${plugin}_plugin>)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${plugin}_bundled_libraries})
endforeach(plugin)

foreach(ffi_plugin ${FLUTTER_FFI_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${ffi_plugin}/windows plugins/${ffi_plugin})
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${ffi_plugin}_bundled_libraries})
endforeach(ffi_plugin)
