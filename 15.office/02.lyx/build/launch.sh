#!/bin/sh

# Launch
echo "Launching ..."

# Start the application
nohup lyx &

# Wait for the application to start
while ! wmctrl -l | grep "LyX"; do
  sleep 1
done

# Maximize the application window
wmctrl -r "LyX" -b add,maximized_vert,maximized_horz
