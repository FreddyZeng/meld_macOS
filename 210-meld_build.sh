#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: 2023 René de Hesselle <dehesselle@web.de>
#
# SPDX-License-Identifier: GPL-2.0-or-later

### description ################################################################

# Install Meld to VER_DIR.

### shellcheck #################################################################

# Nothing here.

### dependencies ###############################################################

source "$(dirname "${BASH_SOURCE[0]}")"/jhb/etc/jhb.conf.sh

### variables ##################################################################

# Nothing here.

### functions ##################################################################

# Nothing here.

### main #######################################################################

error_trace_enable

#-------------------------------------------------------------------- build Meld

if [ "$CI_PROJECT_NAME" = "meld" ]; then
  patch -p 1 < "$ETC_DIR/modulesets/meld/patches/meld-app.patch"

  ln -s "$CI_PROJECT_DIR" "$SRC_DIR"/meld

  jhb run meson setup \
    --prefix "$VER_DIR" \
    "$BLD_DIR/meld" \
    "$CI_PROJECT_DIR"
  jhb run meson compile -C "$BLD_DIR/meld"
  jhb run meson install -C "$BLD_DIR/meld"
else
  jhb build meld
fi

# add build number to __version__ to AboutDialog and CLI help
gsed -i "s/__version__/__version__ + ' ($MELD_BUILD)'/g" \
  "$LIB_DIR"/python*/site-packages/meld/meldapp.py
