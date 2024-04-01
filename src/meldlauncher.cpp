// SPDX-FileCopyrightText: 2023 René de Hesselle <dehesselle@web.de>
//
// SPDX-License-Identifier: GPL-2.0-or-later

#include <CoreFoundation/CoreFoundation.h>
#include <Python/Python.h>

#include <mach-o/dyld.h>

#include <string>
#include <sstream>
#include <vector>
#include <algorithm>

// https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/MacOSXDirectories/MacOSXDirectories.html
static const std::string BUNDLE_IDENTIFIER = "org.gnome.Meld";
static const std::string SETTINGS_DIR = std::string(getenv("HOME")) +
                                        "/Library/Application Support/" +
                                        BUNDLE_IDENTIFIER;

std::string get_program_dir()
{
  std::string result;

  uint32_t size = PATH_MAX + 1;
  char path[size];

  if (_NSGetExecutablePath(path, &size) == 0)
  {
    result.assign(path);
    realpath(result.c_str(), path); // resolve symlink
    result = result.assign(path).substr(0, result.rfind("/"));
  }

  return result;
}

void setenv(const std::string &name, const std::string &value)
{
  setenv(name.c_str(), value.c_str(), 1);
}

static void setup_environment()
{
  std::string program_dir = get_program_dir();
  std::string contents_dir;
  contents_dir.assign(program_dir).append("/.."); // <TheApp.app>/Contents
  auto resources_dir = contents_dir + "/Resources";
  auto etc_dir = resources_dir + "/etc";
  auto bin_dir = resources_dir + "/bin";
  auto lib_dir = resources_dir + "/lib";
  auto share_dir = resources_dir + "/share";

  const std::string cache_dir =
      std::string(getenv("HOME")) + "/Library/Caches/" + BUNDLE_IDENTIFIER;

  // XDG
  // https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
  setenv("XDG_DATA_HOME", SETTINGS_DIR + "/share");
  setenv("XDG_DATA_DIRS", share_dir);
  setenv("XDG_CONFIG_HOME", SETTINGS_DIR);
  setenv("XDG_CACHE_HOME", cache_dir);
  setenv("XDG_RUNTIME_DIR", "/tmp"); // fallback, we don't have anything better

  // GTK
  // https://developer.gnome.org/gtk3/stable/gtk-running.html
  setenv("GTK_EXE_PREFIX", resources_dir);
  setenv("GTK_DATA_PREFIX", resources_dir);

  // GdkPixbuf
  // https://docs.gtk.org/gdk-pixbuf
  setenv("GDK_PIXBUF_MODULE_FILE",
         lib_dir + "/gdk-pixbuf-2.0/2.10.0/loaders.cache");

  // fontconfig
  setenv("FONTCONFIG_PATH", etc_dir + "/fonts");

  // GIO
  setenv("GIO_MODULE_DIR", lib_dir + "/gio/modules");

  // GObject Introspection Repository
  setenv("GI_TYPELIB_PATH", lib_dir + "/girepository-1.0");

  // Python site-packages
  setenv("PYTHONPATH",
         (std::stringstream()
          << program_dir << "/../Resources/lib/python" << PY_MAJOR_VERSION
          << "." << PY_MINOR_VERSION << "/site-packages"
          << ":" << program_dir
          << "/../Frameworks/Python.framework/Versions/Current/lib/python"
          << PY_MAJOR_VERSION << "." << PY_MINOR_VERSION << "/site-packages")
             .str());

  // Python cache files (*.pyc)
  setenv("PYTHONPYCACHEPREFIX", cache_dir);

  // set PATH
  setenv("PATH", std::string(getenv("PATH")) + ":" + bin_dir);

  // set GUI language
  // https://www.gnu.org/software/gettext/manual/html_node/Locale-Environment-Variables.html
  if (getenv("LANG") == nullptr)
  {
    CFLocaleRef cflocale = CFLocaleCopyCurrent();
    CFStringRef value =
        (CFStringRef)CFLocaleGetValue(cflocale, kCFLocaleIdentifier);
    char locale[32];
    CFStringGetCString(value, locale, 32, kCFStringEncodingUTF8);
    CFRelease(cflocale);
    setenv("LANG", std::string(locale).append(".UTF-8"));
  }
}

int main(int argc, char *argv[])
{
  int rc = 0;

  // ---------------------------------------------------------------------- init

  // prepend an additional argv[0] value
  auto arguments = std::vector<std::string>(argv, argv + argc);
  arguments.insert(arguments.begin(), argv[0]);
  std::vector<const char *> new_argv(arguments.size());
  std::transform(arguments.begin(), arguments.end(), new_argv.begin(),
                 [](std::string &str)
                 { return str.c_str(); });

  setup_environment();

  PyStatus status;
  PyConfig config;
  PyConfig_InitPythonConfig(&config);

  status = PyConfig_SetBytesArgv(&config,
                                 new_argv.size(),
                                 const_cast<char **>(new_argv.data()));
  if (not PyStatus_Exception(status))
  {

    status = Py_InitializeFromConfig(&config);
    if (not PyStatus_Exception(status))
    {

      // ------------------------------------------------------------------- run

      std::string filename = (std::stringstream()
                              << get_program_dir() << "/../Resources/lib/"
                              << "python" << PY_MAJOR_VERSION << "." << PY_MINOR_VERSION
                              << "/site-packages/meld/meld")
                                 .str();

      FILE *program_file = fopen(filename.c_str(), "r");
      rc = PyRun_SimpleFile(program_file, filename.c_str());
      fclose(program_file);
    }
  }

  // ------------------------------------------------------------------- cleanup

  if (PyStatus_Exception(status))
  {
    Py_ExitStatusException(status);
  }

  PyConfig_Clear(&config);
  Py_Finalize();

  return rc;
}
