#!/bin/sh

# Launch
echo "Launching ..."

# Start the application
nohup telegram-desktop &

# Wait for the application to start
while ! wmctrl -l | grep "Telegram"; do
  sleep 1
done

# Maximize the application window
wmctrl -r "Telegram" -b add,maximized_vert,maximized_horz
