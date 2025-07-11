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

source "$(dirname "${BASH_SOURCE[0]}")"/jhb/etc/jhb.conf.sh

### variables ##################################################################

SELF_DIR=$(dirname "$(greadlink -f "$0")")

### functions ##################################################################

# Nothing here.

### main #######################################################################

error_trace_enable

#---------------------------------------------------------------- build launcher

meld_install_python "$TMP_DIR"

g++ \
  -std=c++17 \
  -o "$BIN_DIR"/meldlauncher \
  -I"$TMP_DIR"/Python.framework/Headers \
  "$SELF_DIR"/src/meldlauncher.cpp \
  -framework CoreFoundation \
  -F"$TMP_DIR" \
  -framework Python \
  #-DPYTHONSHELL

#----------------------------------------------------- create application bundle

# abcreate can only access files inside the specified source directory ("-s")
cp "$SELF_DIR"/resources/meld_devel.icns "$TMP_DIR"/Meld.icns

abcreate create resources/applicationbundle.xml -s "$VER_DIR" -t "$ART_DIR"

#------------------------------------------------------- install Python packages

meld_pipinstall MELD_PYTHON_PKG_PYGOBJECT

#--------------------------------------------------------- configure GTK UI font

# Updating Pango beyond 1.55 has the side effect of breaking something else:
# it's either choosing a different UI font or breaking its kerning. We "fix"
# it by setting a font explicitly.

{
  echo -e ""
  cat "$SELF_DIR"/resources/gtk.css
} >> "$MELD_APP_RES_DIR"/share/themes/Mac/gtk-3.0/gtk-keys.css

#------------------------------------------------------------- update Info.plist

# enable HiDPI
/usr/libexec/PlistBuddy -c "Add NSHighResolutionCapable bool 'true'" \
  "$MELD_APP_PLIST"

# enable dark mode (menubar only, GTK theme is reponsible for the rest)
/usr/libexec/PlistBuddy -c "Add NSRequiresAquaSystemAppearance bool 'false'" \
  "$MELD_APP_PLIST"

# update minimum system version according to deployment target
# shellcheck disable=SC2031 # local environment change
if [ -z "$MACOSX_DEPLOYMENT_TARGET" ]; then
  MACOSX_DEPLOYMENT_TARGET=$SYS_SDK_VER
fi
/usr/libexec/PlistBuddy \
  -c "Set LSMinimumSystemVersion $MACOSX_DEPLOYMENT_TARGET" \
  "$MELD_APP_PLIST"

# set Meld version
/usr/libexec/PlistBuddy \
  -c "Set CFBundleShortVersionString '$(meld_get_version_from_config)'" \
  "$MELD_APP_PLIST"
/usr/libexec/PlistBuddy -c "Set CFBundleVersion '$MELD_BUILD'" "$MELD_APP_PLIST"

# set copyright
/usr/libexec/PlistBuddy -c "Set NSHumanReadableCopyright 'Copyright © \
2009-2025 Kai Willadsen'" "$MELD_APP_PLIST"

# set bundle identifier
/usr/libexec/PlistBuddy -c "Set CFBundleIdentifier 'org.gnome.Meld'" \
  "$MELD_APP_PLIST"

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
