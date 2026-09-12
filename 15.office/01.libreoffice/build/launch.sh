#!/bin/sh

# Launch
echo "Launching ..."

# Start the application
nohup libreoffice --nologo --norestore &

# Wait for the application to start
while ! wmctrl -l | grep "LibreOffice"; do
  sleep 1
done

# Maximize the application window
wmctrl -r "LibreOffice" -b add,maximized_vert,maximized_horz
