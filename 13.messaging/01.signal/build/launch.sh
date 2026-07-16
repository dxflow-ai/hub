#!/bin/sh

# Launch
echo "Launching ..."

# Start the application
nohup signal-desktop --no-sandbox --disable-gpu --disable-dev-shm-usage &

# Wait for the application to start
while ! wmctrl -l | grep "Signal"; do
  sleep 1
done

# Maximize the application window
wmctrl -r "Signal" -b add,maximized_vert,maximized_horz
