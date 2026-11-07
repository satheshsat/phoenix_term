#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Automatically registers the application and icon into the user's desktop
// environment on first launch so that running from an extracted zip or folder
// properly associates with the dock, panel, and application launcher.
static void ensure_desktop_integration(const gchar* exe_path,
                                       const gchar* icon_path) {
  if (exe_path == nullptr || icon_path == nullptr) {
    return;
  }

  const gchar* home = g_get_home_dir();
  if (home == nullptr) {
    return;
  }

  g_autofree gchar* apps_dir =
      g_build_filename(home, ".local", "share", "applications", nullptr);
  g_autofree gchar* icons_dir = g_build_filename(
      home, ".local", "share", "icons", "hicolor", "1024x1024", "apps", nullptr);
  g_autofree gchar* pixmaps_dir =
      g_build_filename(home, ".local", "share", "pixmaps", nullptr);

  g_mkdir_with_parents(apps_dir, 0755);
  g_mkdir_with_parents(icons_dir, 0755);
  g_mkdir_with_parents(pixmaps_dir, 0755);

  g_autofree gchar* target_icon =
      g_build_filename(icons_dir, "satcs.phoenix.terminal.png", nullptr);
  g_autofree gchar* target_pixmap =
      g_build_filename(pixmaps_dir, "satcs.phoenix.terminal.png", nullptr);

  g_autoptr(GFile) src_icon_file = g_file_new_for_path(icon_path);
  g_autoptr(GFile) dst_icon_file = g_file_new_for_path(target_icon);
  g_autoptr(GFile) dst_pixmap_file = g_file_new_for_path(target_pixmap);

  g_file_copy(src_icon_file, dst_icon_file, G_FILE_COPY_OVERWRITE, nullptr,
              nullptr, nullptr, nullptr);
  g_file_copy(src_icon_file, dst_pixmap_file, G_FILE_COPY_OVERWRITE, nullptr,
              nullptr, nullptr, nullptr);

  g_autofree gchar* target_desktop =
      g_build_filename(apps_dir, "satcs.phoenix.terminal.desktop", nullptr);
  g_autofree gchar* desktop_content = g_strdup_printf(
      "[Desktop Entry]\n"
      "Version=1.0\n"
      "Type=Application\n"
      "Name=Phoenix Terminal\n"
      "GenericName=Terminal Client\n"
      "Comment=The Modern Terminal for Devops & Sysadmins\n"
      "Exec=\"%s\" %%U\n"
      "Icon=%s\n"
      "Terminal=false\n"
      "Categories=Utility;System;TerminalEmulator;\n"
      "StartupWMClass=%s\n",
      exe_path, target_icon, APPLICATION_ID);

  g_file_set_contents(target_desktop, desktop_content, -1, nullptr);
}

// Sets the application icon on the GTK window across all standard resolutions.
static void set_window_icon(GtkWindow* window) {
  g_autoptr(GError) error = nullptr;
  g_autofree gchar* exe_path = g_file_read_link("/proc/self/exe", nullptr);
  g_autofree gchar* exe_dir =
      exe_path != nullptr ? g_path_get_dirname(exe_path) : nullptr;

  const gchar* relative_paths[] = {
      "data/app_icon.png",
      "data/flutter_assets/assets/icon/app_icon.png",
      "app_icon.png",
      "satcs.phoenix.terminal.png",
      "runner/app_icon.png",
      "../../../../assets/icon/app_icon.png",
      "../../../../linux/runner/app_icon.png",
  };

  g_autofree gchar* found_icon_path = nullptr;
  if (exe_dir != nullptr) {
    for (size_t i = 0; i < G_N_ELEMENTS(relative_paths); ++i) {
      g_autofree gchar* candidate =
          g_build_filename(exe_dir, relative_paths[i], nullptr);
      if (g_file_test(candidate, G_FILE_TEST_EXISTS)) {
        found_icon_path = g_strdup(candidate);
        break;
      }
    }
  }

  if (found_icon_path != nullptr) {
    GdkPixbuf* base_pixbuf = gdk_pixbuf_new_from_file(found_icon_path, &error);
    if (base_pixbuf != nullptr) {
      // Build an icon list of standard resolutions for optimal rendering in
      // panel taskbars, Alt+Tab switchers, docks, and titlebars.
      const int target_sizes[] = {16, 24, 32, 48, 64, 128, 256, 512};
      GList* icon_list = nullptr;
      for (size_t i = 0; i < G_N_ELEMENTS(target_sizes); ++i) {
        GdkPixbuf* scaled = gdk_pixbuf_scale_simple(
            base_pixbuf, target_sizes[i], target_sizes[i], GDK_INTERP_BILINEAR);
        if (scaled != nullptr) {
          icon_list = g_list_append(icon_list, scaled);
        }
      }
      icon_list = g_list_append(icon_list, base_pixbuf);

      gtk_window_set_icon_list(window, icon_list);
      gtk_window_set_default_icon_list(icon_list);
      gtk_window_set_icon(window, base_pixbuf);

      g_list_free_full(icon_list, g_object_unref);
    } else if (error != nullptr) {
      g_clear_error(&error);
    }

    if (exe_path != nullptr) {
      ensure_desktop_integration(exe_path, found_icon_path);
    }
  }

  gtk_window_set_default_icon_name(APPLICATION_ID);
  gtk_window_set_icon_name(window, APPLICATION_ID);
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  set_window_icon(window);

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "Phoenix Terminal");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "Phoenix Terminal");
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
