#!/bin/sh

# Launch
echo "Launching ..."

# Start the application
nohup dbeaver -data "/volume/app/.$HOSTNAME/dbeaver/" &

# Wait for the application to start
while ! wmctrl -l | grep "DBeaver"; do
  sleep 1
done

# Maximize the application window
wmctrl -r "DBeaver" -b add,maximized_vert,maximized_horz
