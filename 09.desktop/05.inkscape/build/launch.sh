#!/bin/sh

# Launch
echo "Launching ..."

# Start the application
nohup inkscape --with-gui &

# Wait for the application to start
while ! wmctrl -l | grep "Inkscape"; do
  sleep 1
done

# Maximize the application window
wmctrl -r "Inkscape" -b add,maximized_vert,maximized_horz
