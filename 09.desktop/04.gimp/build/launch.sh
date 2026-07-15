#!/bin/sh

# Launch
echo "Launching ..."

# Start the application
nohup gimp --no-shm --no-cpu-accel --no-splash &

# Wait for the application to start
while ! wmctrl -l | grep "GNU Image Manipulation Program"; do
  sleep 1
done

# Maximize the application window
wmctrl -r "GNU Image Manipulation Program" -b add,maximized_vert,maximized_horz
