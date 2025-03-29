#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: 2023 René de Hesselle <dehesselle@web.de>
#
# SPDX-License-Identifier: GPL-2.0-or-later

### description ################################################################

# Build tools required for packaging the app.

### shellcheck #################################################################

# Nothing here.

### dependencies ###############################################################

source "$(dirname "${BASH_SOURCE[0]}")"/jhb/etc/jhb.conf.sh

### variables ##################################################################

ABCREATE_VER="0.4.1"
ABCREATE_URL=https://github.com/dehesselle/abcreate/releases/download/\
v$ABCREATE_VER/abcreate-$ABCREATE_VER-py3-none-any.whl

### functions ##################################################################

# Nothing here.

### main #######################################################################

if $CI; then # break in CI, otherwise we get interactive prompt by JHBuild
  error_trace_enable
fi

#-------------------------------------------- install application bundle creator

jhb run pip install $ABCREATE_URL

#------------------------------------------------------------- create disk image

jhb build imagemagick # used to create dmg background
