#!/bin/sh

# Prepare
echo "Preparing ..."

# Make app directory
mkdir -p "/volume/app/.$HOSTNAME/scipion/" /root/ScipionUserData/

# Create Symlink
ln -s "/volume/app/.$HOSTNAME/scipion/" /root/ScipionUserData/
