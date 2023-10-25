#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: 2021 René de Hesselle <dehesselle@web.de>
#
# SPDX-License-Identifier: GPL-2.0-or-later

### description ################################################################

# Create the Meld application bundle.

### shellcheck #################################################################

# Nothing here.

### dependencies ###############################################################

#------------------------------------------------------ source jhb configuration

source "$(dirname "${BASH_SOURCE[0]}")"/jhb/etc/jhb.conf.sh

#------------------------------------------- source common functions from bash_d

# bash_d is already available (it's part of jhb configuration)

bash_d_include error
bash_d_include lib

### variables ##################################################################

SELF_DIR=$(dirname "$(greadlink -f "$0")")

### functions ##################################################################

# Nothing here.

### main #######################################################################

error_trace_enable

#---------------------------------------------------------------- build launcher

# Turn "Meld main program" into a C header file.
(
  cd "$BIN_DIR" || exit 1
  xxd -i meld >"$SRC_DIR"/meld.h
)

# Build our C++ program to launch Python w/ Meld.
meld_install_python "$TMP_DIR"
(
  if [ "$(uname -m)" = "x86_64" ]; then
    # special treatment on Intel: Build (only) the main binary with a recent SDK
    # (needs to be >=11.x) and set the deployment target to achieve backward
    # compatibility.
    # https://gitlab.gnome.org/GNOME/gtk/-/issues/5305#note_1673947
    MACOSX_DEPLOYMENT_TARGET=$(
      /usr/libexec/PlistBuddy -c \
        "Print DefaultProperties:MACOSX_DEPLOYMENT_TARGET" \
        "$SDKROOT"/SDKSettings.plist
    )
    export MACOSX_DEPLOYMENT_TARGET
    unset SDKROOT
  fi

  g++ \
    -std=c++11 \
    -o "$BIN_DIR"/meldlauncher \
    -I"$SRC_DIR" \
    -I"$TMP_DIR"/Python.framework/Headers \
    -I"$SELF_DIR"/src \
    "$SELF_DIR"/src/meldlauncher.cpp \
    -framework CoreFoundation \
    -F "$TMP_DIR" \
    -framework Python
)

#----------------------------------------------------- create application bundle

(
  cd "$SELF_DIR" || exit 1
  export ARTIFACT_DIR # is referenced in meld.bundle
  gln -sfT "$SRC_DIR"/meld-* "$SRC_DIR"/meld # version-less dir in meld.bundle

  jhb run gtk-mac-bundler resources/meld.bundle
)

# remove everything but Meld from lib/pythonN.N
mkdir "$TMP_DIR"/site-packages
find "$MELD_APP_LIB_DIR/python$MELD_PYTHON_VER"/site-packages \
  -maxdepth 1 \
  -name "meld*" \
  -exec mv {} "$TMP_DIR"/site-packages \;
rm -rf "$MELD_APP_LIB_DIR/python$MELD_PYTHON_VER"
mkdir "$MELD_APP_LIB_DIR/python$MELD_PYTHON_VER"
mv "$TMP_DIR"/site-packages "$MELD_APP_LIB_DIR/python$MELD_PYTHON_VER"

# install Python.framework into bundle
meld_install_python
rm -rf "$MELD_APP_LIB_DIR"/python"$MELD_PYTHON_VER"/test

#------------------------------------------------------- install Python packages

meld_pipinstall MELD_PYTHON_PKG_PYGOBJECT

#--------------------------------------- patch library link paths: Resources/lib

lib_change_siblings "$MELD_APP_LIB_DIR"

#------------------------------------------------------------- update Info.plist

# enable HiDPI
/usr/libexec/PlistBuddy -c "Add NSHighResolutionCapable bool 'true'" \
  "$MELD_APP_PLIST"

# enable dark mode (menubar only, GTK theme is reponsible for the rest)
/usr/libexec/PlistBuddy -c "Add NSRequiresAquaSystemAppearance bool 'false'" \
  "$MELD_APP_PLIST"

# update minimum system version according to deployment target
if [ -z "$MACOSX_DEPLOYMENT_TARGET" ]; then
  MACOSX_DEPLOYMENT_TARGET=$SYS_SDK_VER
fi
/usr/libexec/PlistBuddy \
  -c "Set LSMinimumSystemVersion $MACOSX_DEPLOYMENT_TARGET" \
  "$MELD_APP_PLIST"

# set Meld version
/usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString '$MELD_VER'" \
  "$MELD_APP_PLIST"
/usr/libexec/PlistBuddy -c "Set CFBundleVersion '$MELD_BUILD'" "$MELD_APP_PLIST"

# set copyright
/usr/libexec/PlistBuddy -c "Set NSHumanReadableCopyright 'Copyright © \
2009-2022 Kai Willadsen'" "$MELD_APP_PLIST"

# set app category
/usr/libexec/PlistBuddy -c \
  "Add LSApplicationCategoryType string 'public.app-category.developer-tools'" \
  "$MELD_APP_PLIST"

# set folder access descriptions
/usr/libexec/PlistBuddy -c "Add NSDesktopFolderUsageDescription string \
'Meld needs your permission to access the Desktop folder.'" "$MELD_APP_PLIST"
/usr/libexec/PlistBuddy -c "Add NSDocumentsFolderUsageDescription string \
'Meld needs your permission to access the Documents folder.'" "$MELD_APP_PLIST"
/usr/libexec/PlistBuddy -c "Add NSDownloadsFolderUsageDescription string \
'Meld needs your permission to access the Downloads folder.'" "$MELD_APP_PLIST"
/usr/libexec/PlistBuddy -c "Add NSRemoveableVolumesUsageDescription string \
'Meld needs your permission to access removeable volumes.'" "$MELD_APP_PLIST"

# add supported languages
/usr/libexec/PlistBuddy -c "Add CFBundleLocalizations array" "$MELD_APP_PLIST"
for locale in "$SRC_DIR"/meld-*/*.po; do
  if [ "$locale" = "en_GB" ]; then
    locale="en"
  fi
  /usr/libexec/PlistBuddy -c "Add CFBundleLocalizations: string \
'$(basename -s .po $locale)'" "$MELD_APP_PLIST"
done

# add some metadata to make CI identifiable
if $CI; then
  for var in PROJECT_NAME PROJECT_URL COMMIT_BRANCH COMMIT_SHA \
    COMMIT_SHORT_SHA JOB_ID JOB_URL JOB_NAME PIPELINE_ID PIPELINE_URL; do
    # use awk to create camel case strings (e.g. PROJECT_NAME to ProjectName)
    /usr/libexec/PlistBuddy -c "Add CI$(
      echo $var | awk -F _ '{
        for (i=1; i<=NF; i++)
        printf "%s", toupper(substr($i,1,1)) tolower(substr($i,2))
      }'
    ) string $(eval echo \$CI_$var)" "$MELD_APP_PLIST"
  done
fi
