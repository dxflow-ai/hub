#!/bin/sh

# Launch
echo "Launching ..."

# Start the application
nohup librecad &

# Wait for the application to start
while ! wmctrl -l | grep "LibreCAD"; do
  sleep 1
done

# Maximize the application window
wmctrl -r "LibreCAD" -b add,maximized_vert,maximized_horz
