#!/bin/sh

# Launch
echo "Launching ..."

# Start the application
nohup thunderbird --profile "/volume/app/.$HOSTNAME/thunderbird/" &

# Wait for the application to start
while ! wmctrl -l | grep "Thunderbird"; do
  sleep 1
done

# Maximize the application window
wmctrl -r "Thunderbird" -b add,maximized_vert,maximized_horz
