#!/bin/sh

# Launch
echo "Launching ..."

# No runner has a card, so render through Mesa's software driver
export LIBGL_ALWAYS_SOFTWARE=1

# Start the application
nohup qgis &

# Wait for the application to start
while ! wmctrl -l | grep "QGIS"; do
  sleep 1
done

# Maximize the application window
wmctrl -r "QGIS" -b add,maximized_vert,maximized_horz
