#!/bin/sh

# Launch
echo "Launching ..."

# Start the application
nohup igv &

# Wait for the application to start
while ! wmctrl -l | grep "IGV"; do
  sleep 1
done

# Maximize the application window
wmctrl -r "IGV" -b add,maximized_vert,maximized_horz
