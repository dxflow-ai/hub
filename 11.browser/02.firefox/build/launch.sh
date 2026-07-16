#!/bin/sh

# Launch
echo "Launching ..."

# Start the application
nohup firefox --profile "/volume/app/.$HOSTNAME/firefox/" &

# Wait for the application to start
while ! wmctrl -l | grep "Firefox"; do
  sleep 1
done

# Maximize the application window
wmctrl -r "Firefox" -b add,maximized_vert,maximized_horz
