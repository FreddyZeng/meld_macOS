#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: 2023 René de Hesselle <dehesselle@web.de>
#
# SPDX-License-Identifier: GPL-2.0-or-later

### description ################################################################

# Build GTK3 libraries and their dependencies.

### shellcheck #################################################################

# Nothing here.

### dependencies ###############################################################

#------------------------------------------------------ source jhb configuration

source "$(dirname "${BASH_SOURCE[0]}")"/jhb/etc/jhb.conf.sh

### variables ##################################################################

SELF_DIR=$(dirname "$(greadlink -f "$0")")

### functions ##################################################################

# Nothing here.

### main #######################################################################

jhb configure "$SELF_DIR"/modulesets/meld.modules

jhb build meta-gtk-osx-gtk3
