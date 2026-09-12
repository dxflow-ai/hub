#!/bin/sh

# Launch
echo "Launching ..."

# No runner has a card, so render through Mesa's software driver
export LIBGL_ALWAYS_SOFTWARE=1

# Qt WebEngine is Chromium underneath: it cannot keep its sandbox as root, and it
# has no GPU to talk to here
export QTWEBENGINE_DISABLE_SANDBOX=1
export QTWEBENGINE_CHROMIUM_FLAGS="--no-sandbox --disable-gpu --disable-dev-shm-usage"

# Start the application
nohup sigil &

# Wait for the application to start
while ! wmctrl -l | grep "Sigil"; do
  sleep 1
done

# Maximize the application window
wmctrl -r "Sigil" -b add,maximized_vert,maximized_horz
