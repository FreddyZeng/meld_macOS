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

#------------------------------------------------------ source jhb configuration

source "$(dirname "${BASH_SOURCE[0]}")"/jhb/etc/jhb.conf.sh

#------------------------------------------- source common functions from bash_d

# bash_d is already available (it's part of jhb configuration)

bash_d_include error

### variables ##################################################################

SELF_DIR=$(dirname "$(greadlink -f "$0")")

### functions ##################################################################

# Nothing here.

### main #######################################################################

error_trace_enable

#------------------------------------------------------------- create disk image

convert \
  -size 440x404 xc:transparent \
  -font Monaco -pointsize 32 -fill black \
  -draw "text 20,60 'Meld $MELD_VER'" \
  -draw "text 20,100 'build $MELD_BUILD'" \
  -draw "text 165,172 '>>>'" \
  -draw "text 20,275 'unsigned PRE-RELEASE'" \
  "$SRC_DIR"/meld_dmg.png

dmgbuild_run "$SELF_DIR"/resources/meld_dmg.py "$MELD_APP_PLIST"
