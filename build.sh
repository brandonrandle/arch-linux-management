#!/bin/bash
# This script builds all packages and syncronizes them with the remote package
# repository.
# Cribbed liberally from https://disconnected.systems/blog/archlinux-meta-packages/#building-the-package

###############################################################################
# USAGE
###############################################################################

# This script must be run from the root of the project.
# `./build.sh` to build and synchronize all packages.


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

# gets relative paths for all packages
PACKAGES=${@:-pkg/*}

# sets chroot install path
CHROOT="$PWD/root"

# create local directory for repo
mkdir -p "$LOCAL_PATH"

# creates chroot install location
mkdir -p "$CHROOT"

# creates clean chroot environment if it doesn't exist
[[ -d "$CHROOT/root" ]] || mkarchroot -C /etc/pacman.conf "$CHROOT/root" base base-devel


###############################################################################
# BUILD PACKAGES
###############################################################################

# iterates over every package path, removes old builds, and builds anew
for package in $PACKAGES; do
  cd "$package"
  rm -f *.pkg.tar.xz
  makechrootpkg -cur $CHROOT
  cd -
done


###############################################################################
# SYNC REMOTE DB TO LOCAL
###############################################################################

s3cmd sync "$REMOTE_PATH/$REPO_NAME".{db,files}.tar.xz "$LOCAL_PATH/"
ln -sf "$REPO_NAME.db.tar.xz" "$LOCAL_PATH/$REPO_NAME.db"
ln -sf "$REPO_NAME.files.tar.gz" "$LOCAL_PATH/$REPO_NAME.files"


###############################################################################
# ADD PACKAGES TO REPO
###############################################################################

repo-add "$LOCAL_PATH/$REPO_NAME.db.tar.xz" ${PACKAGES[@]}/*.pkg.tar.xz


###############################################################################
# SYNC LOCAL DB TO REMOTE
###############################################################################

s3cmd sync --follow-symlinks --acl-public \
  ${PACKAGES[@]}/*.pkg.tar.xz \
  "$LOCAL_PATH/$REPO_NAME".{db,files}{,.tar.xz} \
  "$REMOTE_PATH/"
