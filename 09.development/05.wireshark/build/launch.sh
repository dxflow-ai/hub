#!/bin/sh

# Launch
echo "Launching ..."

# Start the application
nohup wireshark &

# Wait for the application to start
while ! wmctrl -l | grep "Wireshark"; do
  sleep 1
done

# Maximize the application window
wmctrl -r "Wireshark" -b add,maximized_vert,maximized_horz
