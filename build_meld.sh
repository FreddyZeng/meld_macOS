#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: 2023 René de Hesselle <dehesselle@web.de>
#
# SPDX-License-Identifier: GPL-2.0-or-later

### description ################################################################

# Build Meld.

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

for script in "$SELF_DIR"/2??-*.sh; do
  $script
done
