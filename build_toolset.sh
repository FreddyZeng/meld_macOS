#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: 2021 René de Hesselle <dehesselle@web.de>
#
# SPDX-License-Identifier: GPL-2.0-or-later

### description ################################################################

# Build all dependencies for Meld.

### shellcheck #################################################################

# Nothing here.

### dependencies ###############################################################

# Nothing here.

### variables ##################################################################

SELF_DIR=$(dirname "${BASH_SOURCE[0]}")

### functions ##################################################################

# Nothing here.

### main #######################################################################

set -e

for script in "$SELF_DIR"/1??-*.sh; do
  $script
done
