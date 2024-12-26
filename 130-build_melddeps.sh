#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: 2023 René de Hesselle <dehesselle@web.de>
#
# SPDX-License-Identifier: GPL-2.0-or-later

### description ################################################################

# Build dependencies for Meld.

### shellcheck #################################################################

# Nothing here.

### dependencies ###############################################################

source "$(dirname "${BASH_SOURCE[0]}")"/jhb/etc/jhb.conf.sh

### variables ##################################################################

# Nothing here.

### functions ##################################################################

# Nothing here.

### main #######################################################################

if $CI; then # break in CI, otherwise we get interactive prompt by JHBuild
  error_trace_enable
fi

#------------------------------------------------------ dependencies besides GTK

jhb build meta-meld-dependencies

#------------------------------------------------- run time dependencies: Python

meld_download_python

#---------------------------------- run time dependencies: build Python packages

meld_build_wheels
