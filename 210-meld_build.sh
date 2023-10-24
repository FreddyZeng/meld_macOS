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

#------------------------------------------------------ source jhb configuration

source "$(dirname "${BASH_SOURCE[0]}")"/jhb/etc/jhb.conf.sh

#------------------------------------------- source common functions from bash_d

# bash_d is already available (it's part of jhb configuration)

bash_d_include error

### variables ##################################################################

# Nothing here.

### functions ##################################################################

# Nothing here.

### main #######################################################################

error_trace_enable

#------------------------------------------------------------------ install Meld

jhb build meld
