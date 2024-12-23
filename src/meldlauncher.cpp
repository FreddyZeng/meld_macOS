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

// https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/MacOSXDirectories/MacOSXDirectories.html
static const std::string BUNDLE_IDENTIFIER = "org.gnome.Meld";
static const std::string SETTINGS_DIR = std::string(getenv("HOME")) +
                                        "/Library/Application Support/" +
                                        BUNDLE_IDENTIFIER;

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

std::string get_program_dir()
{
  if (auto executable_path = get_executable_path(); not executable_path.empty())
  {
    return executable_path.substr(0, executable_path.rfind("/"));
  }

  return std::string();
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
  setenv(
      "PYTHONPATH",
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

  if (auto arguments = std::vector<std::string>(argv, argv + argc); is_multiprocessing(arguments))
  {
    Py_Initialize();
    rc = Py_BytesMain(argc, argv);
  }
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
        std::string filename = (std::stringstream()
                                << get_program_dir() << "/../Resources/lib/"
                                << "python" << PY_MAJOR_VERSION << "." << PY_MINOR_VERSION
                                << "/site-packages/meld/meld")
                                   .str();

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
