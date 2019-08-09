#!/bin/bash
# This script wraps `aur sync` to mount an AWS S3 bucket that stores a repo.
# Cribbed liberally from https://disconnected.systems/blog/archlinux-repo-in-aws-bucket/#wrapper-scripts

###############################################################################
# USAGE
###############################################################################
#
# Must be called with an argument.
# `./aursync_wrapper.sh PACKAGE` to delete a package from a repo


###############################################################################
# ERROR HANDLING
###############################################################################

# Ensures failure when shell tries to expand unset variables and ensures
# failure on the first command in a pipeline that fails instead of waiting for
# the whole pipe
set -uo pipefail

# catches error messages
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

# check if package name was passed
package=${1:?"Missing package"}


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
# REMOVE PACKAGE
###############################################################################

# remove from local repo
repo-remove "$LOCAL_PATH/$REPO_NAME.db.tar.xz" "$@"

# sync local repo with remote db
s3cmd sync --follow-symlinks --acl-public \
  "$LOCAL_PATH/$REPO_NAME".{db,files}{,.tar.xz} \
  "$REMOTE_PATH/"

# remove given packages
for package in "$@"; do
  s3cmd rm "$REMOTE_PATH/$package-*.pkg.tar.xz"
done
