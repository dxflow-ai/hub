#!/bin/sh

# Launch
echo "Launching ..."

# Start the application
nohup mypaint &

# Wait for the application to start
while ! wmctrl -l | grep "MyPaint"; do
  sleep 1
done

# Maximize the application window
wmctrl -r "MyPaint" -b add,maximized_vert,maximized_horz
