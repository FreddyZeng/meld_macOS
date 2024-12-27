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

MELD_APP_DIR=$ART_DIR/Meld.app
MELD_APP_CON_DIR=$MELD_APP_DIR/Contents
MELD_APP_RES_DIR=$MELD_APP_CON_DIR/Resources
MELD_APP_BIN_DIR=$MELD_APP_RES_DIR/bin
MELD_APP_LIB_DIR=$MELD_APP_RES_DIR/lib
MELD_APP_FRA_DIR=$MELD_APP_CON_DIR/Frameworks
MELD_APP_PLIST=$MELD_APP_CON_DIR/Info.plist

MELD_BUILD=${MELD_BUILD:-0}

#---------------------------------------- Python runtime to be bundled with Meld

MELD_PYTHON_VER_MAJOR=3
MELD_PYTHON_VER_MINOR=10
MELD_PYTHON_VER=$MELD_PYTHON_VER_MAJOR.$MELD_PYTHON_VER_MINOR
MELD_PYTHON_URL="https://gitlab.com/api/v4/projects/26780227/packages/generic/\
python_macos/v21.1/python_${MELD_PYTHON_VER/./}_$(uname -m).tar.xz"

#--------------------------------------- Python packages to be bundled with Meld

# https://pypi.org/project/pycairo/
# https://pypi.org/project/PyGObject/
MELD_PYTHON_PKG_PYGOBJECT="\
  pygobject==3.50.0\
  pycairo==1.27.0\
"

### functions ##################################################################

function meld_get_version_from_plist
{
  /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
    "$MELD_APP_PLIST"
}

function meld_get_version_from_config
{
  grep __version__ "$SRC_DIR"/meld/meld/conf.py.in | awk -F '"' '{ print $2 }'
}

function meld_get_version_from_module
{
  xmllint \
    --xpath "string(//moduleset/meson[@id='meld']/branch/@version)" \
    "$ETC_DIR"/modulesets/meld/meld.modules \
    2>/dev/null
}

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
  export PATH=$MELD_APP_FRA_DIR/Python.framework/Versions/Current/bin:$PATH

  # shellcheck disable=SC2086 # we need word splitting here
  pip$MELD_PYTHON_VER_MAJOR install \
    --prefix "$MELD_APP_RES_DIR" \
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

function meld_pipinstall_pygobject
{
  # GObject Introspection
  lib_change_paths \
    @loader_path/../../.. \
    "$MELD_APP_LIB_DIR" \
    "$MELD_APP_LIB_DIR"/python$MELD_PYTHON_VER/site-packages/gi/_gi*.so

  # Cairo
  lib_change_paths \
    @loader_path/../../.. \
    "$MELD_APP_LIB_DIR" \
    "$MELD_APP_LIB_DIR"/python$MELD_PYTHON_VER/site-packages/cairo/\
_cairo.cpython-${MELD_PYTHON_VER/./}-darwin.so
}

function meld_download_python
{
  curl -o "$PKG_DIR"/"$(basename "$MELD_PYTHON_URL")" -L "$MELD_PYTHON_URL"
  # Exclude the above from cleanup procedure.
  basename "$MELD_PYTHON_URL" >> "$PKG_DIR"/.keep
}

function meld_install_python
{
  local target_dir=$1

  target_dir=${target_dir:-$MELD_APP_FRA_DIR}

  mkdir -p "$target_dir"
  tar -C "$target_dir" -xf "$PKG_DIR"/"$(basename "${MELD_PYTHON_URL%\?*}")"
  local python_lib=Python.framework/Versions/$MELD_PYTHON_VER/Python
  install_name_tool -id @executable_path/../Frameworks/$python_lib \
    "$target_dir"/$python_lib
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
        -w "$PKG_DIR" \
        $packages
      packages=""
    fi
  done

  # Exclude wheels from cleanup procedure.
  find "$PKG_DIR" -type f -name '*.whl' \
    -exec bash -c 'basename "$1" >> "${2:?}"/.keep' _ {} "$PKG_DIR" \;
}
