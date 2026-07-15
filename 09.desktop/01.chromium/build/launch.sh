#!/bin/sh

# Launch
echo "Launching ..."

# Start the application
nohup chromium --no-sandbox --disable-gpu --disable-dev-shm-usage --user-data-dir="/volume/app/.$HOSTNAME/chromium/" &

# Wait for the application to start
while ! wmctrl -l | grep "Chromium"; do
  sleep 1
done

# Maximize the application window
wmctrl -r "Chromium" -b add,maximized_vert,maximized_horz
