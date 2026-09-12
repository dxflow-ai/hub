#!/bin/sh

# Launch
echo "Launching ..."

# Start the application
nohup geany &

# Wait for the application to start
while ! wmctrl -l | grep "Geany"; do
  sleep 1
done

# Maximize the application window
wmctrl -r "Geany" -b add,maximized_vert,maximized_horz
