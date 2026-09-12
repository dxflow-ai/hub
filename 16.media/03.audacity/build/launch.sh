#!/bin/sh

# Launch
echo "Launching ..."

# Start the application
nohup audacity &

# Wait for the application to start
while ! wmctrl -l | grep "Audacity"; do
  sleep 1
done

# Maximize the application window
wmctrl -r "Audacity" -b add,maximized_vert,maximized_horz
