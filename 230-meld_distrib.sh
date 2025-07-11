#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: 2023 René de Hesselle <dehesselle@web.de>
#
# SPDX-License-Identifier: GPL-2.0-or-later

### description ################################################################

# Create a disk image for distribution.

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

#------------------------------------------------------------- create disk image

convert \
  -size 440x404 canvas:transparent \
  -font Monaco -pointsize 32 -fill black \
  -draw "text 90,55 'Meld $(meld_get_version_from_plist)'" \
  -draw "text 165,172 '>>>'" \
  -pointsize 18 \
  -draw "text 90,80 'build $MELD_BUILD'" \
  -fill red \
  -draw "text 40,275 'Unsigned development version!'" \
  -pointsize 14 \
  -draw "text 40,292 'xattr -r -d com.apple.quarantine Meld.app'" \
  "$SRC_DIR"/meld_dmg.png

cp "$SELF_DIR"/resources/meld_dmg.icns "$SRC_DIR"
dmgbuild_run "$SELF_DIR"/resources/meld_dmg.py "$MELD_APP_PLIST"
