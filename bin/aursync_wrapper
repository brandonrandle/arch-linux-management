#!/bin/bash
# This script wraps `aur sync` to mount an AWS S3 bucket that stores a repo.
# Cribbed liberally from https://disconnected.systems/blog/archlinux-repo-in-aws-bucket/#wrapper-scripts

###############################################################################
# USAGE
###############################################################################
#
# Must be called with an argument. TODO: Check if an argument was passed.
# `./aursync_wrapper.sh PACKAGE` to add a new package to repo
# `./aursync_wrapper.sh -u` to check and update all packages in the repo


###############################################################################
# ERROR HANDLING
###############################################################################

# Ensures failure when shell tries to expand unset variables and ensures
# failure on the first command in a pipeline that fails instead of waiting for
# the whole pipe
set -uo pipefail

# catches error messages
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR


###############################################################################
# VARIABLES
###############################################################################

# path to repository on AWS S3 bucket
REMOTE_PATH=s3://brandle-arch/repo/x86_64

# path to repositor on local machine
LOCAL_PATH=$HOME/.local/share/arch-repo

# name of repository
REPO_NAME=brandle


###############################################################################
# SETUP
###############################################################################

# create local directory for repo
mkdir -p "$LOCAL_PATH"


###############################################################################
# SYNC REMOTE DB TO LOCAL
###############################################################################

s3cmd sync "$REMOTE_PATH/$REPO_NAME".{db,files}.tar.xz "$LOCAL_PATH/"
ln -sf "$REPO_NAME.db.tar.xz" "$LOCAL_PATH/$REPO_NAME.db"
ln -sf "$REPO_NAME.files.tar.gz" "$LOCAL_PATH/$REPO_NAME.files"


###############################################################################
# CLEANUP
###############################################################################

# clean up older packages that may have been deleted from remote so they don't
# get re-uploaded
rm -f "$LOCAL_PATH/"*.pkg.tar.xz


###############################################################################
# AUR SYNC
###############################################################################

# can be used to add new packages or to update packages
aur sync -d "$REPO_NAME" --root="$LOCAL_PATH" "$@" || true


###############################################################################
# SYNC LOCAL DB TO REMOTE
###############################################################################

s3cmd sync --follow-symlinks --acl-public \
  "$LOCAL_PATH/"*.pkg.tar.xz \
  "$LOCAL_PATH/$REPO_NAME".{db,files}{,.tar.xz} \
  "$REMOTE_PATH/"
