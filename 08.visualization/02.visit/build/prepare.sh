#!/bin/sh

# Prepare
echo "Preparing ..."

# Make app directory
mkdir -p "/volume/app/.$HOSTNAME/visit/" /root/.visit/

# Create Symlink
ln -s "/volume/app/.$HOSTNAME/visit/" /root/.visit/
