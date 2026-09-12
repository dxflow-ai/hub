#!/bin/sh

# Prepare
echo "Preparing ..."

# Make app directory
mkdir -p "/volume/app/.$HOSTNAME/vlc/"

# Hand the app directory to the unprivileged user the app runs as
chown app:app /volume/app
chown -R app:app "/volume/app/.$HOSTNAME/vlc/"

# Let that user reach the system-wide PulseAudio
usermod -aG pulse-access app 2>/dev/null || true
