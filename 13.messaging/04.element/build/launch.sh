#!/bin/sh

# Launch
echo "Launching ..."

# Start the application
nohup element-desktop --no-sandbox --disable-gpu --disable-dev-shm-usage --profile-dir "/volume/app/.$HOSTNAME/element/" &

# Wait for the application to start
while ! wmctrl -l | grep "Element"; do
  sleep 1
done

# Maximize the application window
wmctrl -r "Element" -b add,maximized_vert,maximized_horz
