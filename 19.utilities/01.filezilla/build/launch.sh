#!/bin/sh

# Launch
echo "Launching ..."

# Start the application
nohup filezilla &

# Wait for the application to start
while ! wmctrl -l | grep "FileZilla"; do
  sleep 1
done

# Maximize the application window
wmctrl -r "FileZilla" -b add,maximized_vert,maximized_horz
