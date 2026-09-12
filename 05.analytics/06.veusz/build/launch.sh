#!/bin/sh

# Launch
echo "Launching ..."

# Start the application
nohup veusz &

# Wait for the application to start
while ! wmctrl -l | grep "Veusz"; do
  sleep 1
done

# Maximize the application window
wmctrl -r "Veusz" -b add,maximized_vert,maximized_horz
