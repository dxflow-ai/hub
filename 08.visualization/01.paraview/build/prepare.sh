#!/bin/sh

# Prepare
echo "Preparing ..."

# Make app directory
mkdir -p "/volume/app/.$HOSTNAME/paraview/" /root/.config/ParaView/

# Create Symlink
ln -s "/volume/app/.$HOSTNAME/paraview/" /root/.config/ParaView/
