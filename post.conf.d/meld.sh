# SPDX-FileCopyrightText: 2021 René de Hesselle <dehesselle@web.de>
#
# SPDX-License-Identifier: GPL-2.0-or-later

### description ################################################################

# This file contains settings and functions related to packaging Meld.

### shellcheck #################################################################

# shellcheck shell=bash # no shebang as this file is intended to be sourced
# shellcheck disable=SC2034 # no exports desired

### dependencies ###############################################################

# Nothing here.

### variables ##################################################################

MELD_APPDIR=$ARTIFACT_DIR/Meld.app
MELD_APPCON_DIR=$MELD_APPDIR/Contents
MELD_APPRES_DIR=$MELD_APPCON_DIR/Resources
MELD_APPBIN_DIR=$MELD_APPRES_DIR/bin
MELD_APPETC_DIR=$MELD_APPRES_DIR/etc
MELD_APPLIB_DIR=$MELD_APPRES_DIR/lib
MELD_APPFRA_DIR=$MELD_APPCON_DIR/Frameworks
MELD_APPPLIST=$MELD_APPCON_DIR/Info.plist

MELD_VER=$(
  xmllint \
    --xpath "string(//moduleset/distutils[@id='meld']/branch/@version)" \
    "$ETC_DIR"/modulesets/meld/meld.modules
)

MELD_BUILD=${MELD_BUILD:-0}

#---------------------------------------- Python runtime to be bundled with Meld

MELD_PYTHON_VER_MAJOR=3
MELD_PYTHON_VER_MINOR=10
MELD_PYTHON_VER=$MELD_PYTHON_VER_MAJOR.$MELD_PYTHON_VER_MINOR
MELD_PYTHON_URL="https://gitlab.com/api/v4/projects/26780227/packages/generic/\
python_macos/v19/python_${MELD_PYTHON_VER/./}_$(uname -m).tar.xz"

#--------------------------------------- Python packages to be bundled with Meld

# https://pypi.org/project/numpy/
MELD_PYTHON_PKG_NUMPY="\
  https://files.pythonhosted.org/packages/e3/63/fd76159cb76c682171e3bf50ed0ee8704103035a9347684a2ec0914b84a1/numpy-1.26.1-cp310-cp310-macosx_11_0_arm64.whl\
  https://files.pythonhosted.org/packages/34/11/055802bf85abbb61988e6313e8b0a85167ee0795fc2c6141ee5b539e7b11/numpy-1.26.1-cp310-cp310-macosx_10_9_x86_64.whl\
"

# https://pypi.org/project/Pillow/
MELD_PYTHON_PKG_PILLOW=Pillow==10.1.0

# https://pypi.org/project/pycairo/
# https://pypi.org/project/PyGObject/
MELD_PYTHON_PKG_PYGOBJECT="\
  PyGObject==3.46.0\
  pycairo==1.25.0\
"

# https://pypi.org/project/pyenchant/
# https://pypi.org/project/pygtkspellcheck/
MELD_PYTHON_PKG_PYGTKSPELLCHECK="\
  pyenchant==3.2.2\
  pygtkspellcheck==5.0.0\
"

# https://pypi.org/project/xdot/
MELD_PYTHON_PKG_XDOT=xdot==1.3

### functions ##################################################################

function meld_pipinstall
{
  local packages=$1     # name of variable that resolves to list of packages
  local options=$2      # optional

  # turn package names into filenames of our wheels
  local wheels
  for package in $(eval echo \$"$packages"); do
    if [ "${package::8}" = "https://" ]; then
      if [[ $package != *$(uname -m).whl ]]; then
        continue # skip package for different architecture
      fi
      package=$(basename "$package")
    else
      package=$(eval echo "${package/==/-}"*.whl)
    fi

    # If present in TMP_DIR, use that. This is how the externally built
    # packages can be fed into this.
    if [ -f "$TMP_DIR/$package" ]; then
      wheels="$wheels $TMP_DIR/$package"
    else
      wheels="$wheels $PKG_DIR/$package"
    fi
  done

  local path_original=$PATH
  export PATH=$MELD_APPFRA_DIR/Python.framework/Versions/Current/bin:$PATH

  # shellcheck disable=SC2086 # we need word splitting here
  pip$MELD_PYTHON_VER_MAJOR install \
    --prefix "$MELD_APPRES_DIR" \
    $options \
    $wheels

  export PATH=$path_original

  local meld_pipinstall_func
  meld_pipinstall_func=meld_pipinstall_$(echo "${packages##*_}" |
    tr "[:upper:]" "[:lower:]")

  if declare -F "$meld_pipinstall_func" > /dev/null; then
    $meld_pipinstall_func
  fi
}

function meld_pipinstall_numpy
{
  local numpy_dir=$MELD_APPLIB_DIR/python$MELD_PYTHON_VER/site-packages/numpy

  find "$numpy_dir" '(' -name "*.so" -o -name "*.dylib" ')' \
    -exec codesign --remove-signature {} \;

  find "$numpy_dir" -name "*.a" -delete

  # remove libs intended for other architectures
  for lib in "$numpy_dir"/.dylibs/*.dylib; do
    if ! file "$lib" | grep "$(uname -m)"; then
      rm "$lib"
    fi
  done

  # remove CLI tools
  rm "$MELD_APPRES_DIR"/bin/f2py*
}

function meld_pipinstall_pillow
{
  lib_change_paths \
    @loader_path/../../.. \
    "$MELD_APPLIB_DIR" \
    "$MELD_APPLIB_DIR"/python$MELD_PYTHON_VER/site-packages/PIL/*.so
}

function meld_pipinstall_pygobject
{
  # GObject Introspection
  lib_change_paths \
    @loader_path/../../.. \
    "$MELD_APPLIB_DIR" \
    "$MELD_APPLIB_DIR"/python$MELD_PYTHON_VER/site-packages/gi/_gi*.so

  # Cairo
  lib_change_paths \
    @loader_path/../../.. \
    "$MELD_APPLIB_DIR" \
    "$MELD_APPLIB_DIR"/python$MELD_PYTHON_VER/site-packages/cairo/\
_cairo.cpython-${MELD_PYTHON_VER/./}-darwin.so
}

function meld_pipinstall_xdot
{
  ln -s dot "$MELD_APPBIN_DIR"/fdp
  rm "$MELD_APPBIN_DIR"/xdot
}

function meld_download_python
{
  curl -o "$PKG_DIR"/"$(basename "${MELD_PYTHON_URL%\?*}")" -L "$MELD_PYTHON_URL"
}

function meld_install_python
{
  local target_dir=$1

  target_dir=${target_dir:-$MELD_APPFRA_DIR}

  mkdir -p "$target_dir"
  tar -C "$target_dir" -xf "$PKG_DIR"/"$(basename "${MELD_PYTHON_URL%\?*}")"
  local python_lib=Python.framework/Versions/$MELD_PYTHON_VER/Python
  install_name_tool -id @executable_path/../Frameworks/$python_lib \
    "$target_dir"/$python_lib

  # create '.pth' file inside Framework to include our site-packages directory
  echo "../../../../../../../Resources/lib/python$MELD_PYTHON_VER/site-packages"\
    > "$target_dir"/Python.framework/Versions/Current/lib/\
python$MELD_PYTHON_VER/site-packages/meld.pth
}

function meld_build_wheels
{
  jhb run pip3 install wheel==0.41.2

  for package_set in ${!MELD_PYTHON_PKG_*}; do
    local packages
    for package in $(eval echo \$"$package_set"); do
      if [ "${package::8}" = "https://" ]; then
        if [[ $package != *$(uname -m).whl ]]; then
          continue # skip package for different architecture
        fi
        jhb run pip3 download "$package"
      else
        packages="$packages $package"
      fi
    done

    if [ -n "$packages" ]; then
      # shellcheck disable=SC2086 # we need word splitting here
      jhb run pip3 wheel \
        --no-binary :all: --only-binary numpy \
        $packages \
        -w "$PKG_DIR"
      packages=""
    fi
  done
}
