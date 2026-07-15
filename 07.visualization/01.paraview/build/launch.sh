#!/bin/sh

# Launch
echo "Launching ..."

# Start the application
nohup paraview &

# Wait for the application to start
while ! wmctrl -l | grep "ParaView"; do
  sleep 1
done

# Maximize the application window
wmctrl -r "ParaView" -b add,maximized_vert,maximized_horz
