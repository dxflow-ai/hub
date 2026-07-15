#!/bin/sh

# Launch
echo "Launching ..."

# Start the application
nohup vivaldi-stable --no-sandbox --disable-gpu --disable-dev-shm-usage --no-first-run --user-data-dir="/volume/app/.$HOSTNAME/vivaldi/" &

# Wait for the application to start
while ! wmctrl -l | grep "Vivaldi"; do
  sleep 1
done

# Maximize the application window
wmctrl -r "Vivaldi" -b add,maximized_vert,maximized_horz
