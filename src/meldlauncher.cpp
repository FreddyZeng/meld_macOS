// SPDX-FileCopyrightText: 2023 René de Hesselle <dehesselle@web.de>
//
// SPDX-License-Identifier: GPL-2.0-or-later

#include <CoreFoundation/CoreFoundation.h>
#include <Python/Python.h>

#include <mach-o/dyld.h>

#include <string>
#include <sstream>
#include <vector>
#include <iostream>

std::string get_bundle_id()
{
  char result[256];

  CFBundleRef bundle = CFBundleGetMainBundle();
  CFStringRef bundle_id = CFBundleGetIdentifier(bundle);
  CFStringGetCString(bundle_id, result, 256, kCFStringEncodingUTF8);

  return result;
}

std::string get_executable_path()
{
  uint32_t size = PATH_MAX;
  char path[size];

  if (_NSGetExecutablePath(path, &size) == 0)
  {
    auto path_canonical = std::unique_ptr<char[]>(new char[size]);
    return std::string(realpath(path, path_canonical.get()));
  }

  return std::string();
}

std::string get_locale()
{
  char result[32];

  CFLocaleRef locale = CFLocaleCopyCurrent();
  CFStringRef value =
      (CFStringRef)CFLocaleGetValue(locale, kCFLocaleIdentifier);
  CFStringGetCString(value, result, 32, kCFStringEncodingUTF8);
  CFRelease(locale);

  return result;
}

std::string get_program_dir()
{
  if (auto executable_path = get_executable_path(); not executable_path.empty())
  {
    return executable_path.substr(0, executable_path.rfind("/"));
  }

  return std::string();
}

bool is_multiprocessing(const std::vector<std::string> &args)
{
  if (args.size() >= 3 and
      args[1].compare("-c") == 0 and
      args[2].find("from multiprocessing") != std::string::npos)
  {
    return true;
  }

  return false;
}

bool is_symlinked()
{
  uint32_t size = PATH_MAX;
  char path[size];
  char path_canonical[size];

  if (_NSGetExecutablePath(path, &size) == 0)
  {
    realpath(path, path_canonical);

    if (strcmp(path, path_canonical) != 0)
    {
      std::cout << "path           = " << path << std::endl
                << "path_canonical = " << path_canonical << std::endl
                << std::endl;
      return true;
    }
  }
  return false;
}

void setenv(const std::string &name, const std::string &value)
{
  setenv(name.c_str(), value.c_str(), 1);
}

static void setup_environment()
{
  auto bundle_id = get_bundle_id();
  auto cache_dir = std::string(getenv("HOME")) + "/Library/Caches/" + bundle_id;
  auto settings_dir = std::string(getenv("HOME")) +
                      "/Library/Application Support/" + bundle_id;
  //
  auto bundle_program_dir = get_program_dir();
  auto bundle_contents_dir = bundle_program_dir + "/..";
  auto bundle_resources_dir = bundle_contents_dir + "/Resources";
  auto bundle_frameworks_dir = bundle_contents_dir + "/Frameworks";

  // XDG
  // https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
  setenv("XDG_CACHE_HOME", cache_dir);
  setenv("XDG_CONFIG_HOME", settings_dir);
  setenv("XDG_DATA_DIRS", bundle_resources_dir + "/share");
  setenv("XDG_DATA_HOME", settings_dir + "/share");
  setenv("XDG_RUNTIME_DIR", "/tmp"); // we don't have anything better
  setenv("XDG_STATE_HHOME", settings_dir + "/state");

  // GTK
  // https://developer.gnome.org/gtk3/stable/gtk-running.html
  setenv("GTK_EXE_PREFIX", bundle_frameworks_dir);
  setenv("GTK_DATA_PREFIX", bundle_resources_dir);

  // GdkPixbuf
  // https://docs.gtk.org/gdk-pixbuf
  setenv("GDK_PIXBUF_MODULE_FILE", bundle_resources_dir + "/etc/loaders.cache");

  // Input Method modules
  setenv("GTK_IM_MODULE_FILE", bundle_resources_dir + "/etc/immodules.cache");

  // FontConfig
  setenv("FONTCONFIG_PATH", bundle_resources_dir + "/etc/fonts");

  // GObject Introspection Repository
  setenv("GI_TYPELIB_PATH", bundle_resources_dir + "/lib/girepository-1.0");

  // Python site-packages
  setenv(
      "PYTHONPATH",
      (std::stringstream()
       << bundle_resources_dir << "/lib"
       << "/python" << PY_MAJOR_VERSION << "." << PY_MINOR_VERSION
       << "/site-packages"
       << ":"
       << bundle_frameworks_dir
       << "/Python.framework/Versions/Current/lib"
       << "/python" << PY_MAJOR_VERSION << "." << PY_MINOR_VERSION
       << "/site-packages")
          .str());

  // Python cache files (*.pyc)
  setenv("PYTHONPYCACHEPREFIX", cache_dir);

  // set GUI language
  // https://www.gnu.org/software/gettext/manual/html_node/Locale-Environment-Variables.html
  if (getenv("LANG") == nullptr)
  {
    setenv("LANG", get_locale() + ".UTF-8");
  }
}

int main(int argc, char *argv[])
{
  if (is_symlinked())
  {
    // While it is possible to get Meld somewhat working when symlinked
    // by manipulating 'argv[0]' with code like
    //
    //      char canonical_path[PATH_MAX];
    //      strcpy(canonical_path, get_executable_path().c_str());
    //      argv[0] = canonical_path;
    //
    // there are side effects. Some are visible (wrong window size, missing
    // icon in the dock), but who knows what else is getting messed up by this.
    // I haven't found any other app (including Apple's own apps) that supports
    // this. The main binary in an application bundle is simply not meant to be
    // symlinked to.
    std::cout
        << "You appear to be using a symlink to the Meld executable." << std::endl
        << "This is not supported, please see instructions:" << std::endl
        << std::endl
        << "   https://gitlab.com/dehesselle/meld_macos#usage" << std::endl;
    return 1;
  }

  //----------------------------------------------------------------------------

  int rc = 0;

  setup_environment();

  if (auto arguments = std::vector<std::string>(argv, argv + argc);
      is_multiprocessing(arguments))
  {
    Py_Initialize();
    rc = Py_BytesMain(argc, argv);
  }
#ifdef PYTHONSHELL
  else if (argc > 1 and std::string(argv[1]) == "pythonshell")
  {
    Py_Initialize();
    // drop the "pythonshell" argument
    for (size_t i = 2; i < argc; ++i)
    {
      argv[i - 1] = argv[i];
    }
    --argc;
    rc = Py_BytesMain(argc, argv);
  }
#endif
  else
  {
    arguments.insert(arguments.begin() + 1, argv[0]);
    std::vector<const char *> new_argv(arguments.size());
    std::transform(arguments.begin(), arguments.end(), new_argv.begin(),
                   [](std::string &str)
                   { return str.c_str(); });

    PyStatus status;
    PyConfig config;
    PyConfig_InitPythonConfig(&config);
    status = PyConfig_SetBytesArgv(&config, new_argv.size(),
                                   const_cast<char **>(new_argv.data()));
    if (not PyStatus_Exception(status))
    {
      status = Py_InitializeFromConfig(&config);
      if (not PyStatus_Exception(status))
      {
        std::string site_packages_dir =
            (std::stringstream()
             << get_program_dir() << "/../Resources/lib/"
             << "python" << PY_MAJOR_VERSION << "." << PY_MINOR_VERSION
             << "/site-packages")
                .str();
        PyWideStringList_Append(&config.module_search_paths,
                                (const wchar_t *)site_packages_dir.c_str());

        std::string filename = site_packages_dir + "/meld/meld";
        FILE *program_file = fopen(filename.c_str(), "r");
        rc = PyRun_SimpleFile(program_file, filename.c_str());
        fclose(program_file);

        if (PyStatus_Exception(status))
        {
          Py_ExitStatusException(status);
        }
      }
    }
    PyConfig_Clear(&config);
  }

  Py_Finalize();
  return rc;
}
