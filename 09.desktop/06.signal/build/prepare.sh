#!/bin/sh

# Prepare
echo "Preparing ..."

# Make app directory
mkdir -p "/volume/app/.$HOSTNAME/signal/" /root/.local/Signal/

# Create Symlink
ln -s "/volume/app/.$HOSTNAME/signal/" /root/.local/Signal/
