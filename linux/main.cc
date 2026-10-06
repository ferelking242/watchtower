#include "my_application.h"

#include <stdio.h>
#include <string.h>

static gboolean is_cli_invocation(int argc, char** argv) {
  for (int i = 1; i < argc; i++) {
    if (strcmp(argv[i], "--cli") == 0) {
      return TRUE;
    }
  }
  return FALSE;
}

// Keep machine-readable CLI data on stdout. GLib's g_print is otherwise
// allowed to write startup diagnostics to stdout before Dart emits JSON.
static void cli_print_to_stderr(const gchar* message) {
  if (message == nullptr) {
    return;
  }
  fputs(message, stderr);
  fflush(stderr);
}

int main(int argc, char** argv) {
  if (is_cli_invocation(argc, argv)) {
    g_set_print_handler(cli_print_to_stderr);
  }
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
