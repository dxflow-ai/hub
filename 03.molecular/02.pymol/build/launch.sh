#!/bin/sh

# Launch
echo "Launching ..."

# Start the application
nohup pymol &

# Wait for the application to start
while ! wmctrl -l | grep "PyMOL"; do
  sleep 1
done

# Maximize the application window
wmctrl -r "PyMOL" -b add,maximized_vert,maximized_horz
