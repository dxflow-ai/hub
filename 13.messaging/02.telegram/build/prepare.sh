#!/bin/sh

# Prepare
echo "Preparing ..."

# Make app directory
mkdir -p "/volume/app/.$HOSTNAME/telegram/" "/root/.local/share/TelegramDesktop/"

# Create Symlink
ln -s "/volume/app/.$HOSTNAME/telegram/" "/root/.local/share/TelegramDesktop/"
