#!/bin/sh

# Launch
echo "Launching ..."

# Start the application
nohup fontforge -new &

# Wait for the application to start
while ! wmctrl -l | grep "Untitled"; do
  sleep 1
done

# Maximize the application window
wmctrl -r "Untitled" -b add,maximized_vert,maximized_horz
