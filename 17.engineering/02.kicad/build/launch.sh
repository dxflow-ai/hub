#!/bin/sh

# Launch
echo "Launching ..."

# No runner has a card, so render through Mesa's software driver
export LIBGL_ALWAYS_SOFTWARE=1

# Start the application
nohup kicad &

# Wait for the application to start
while ! wmctrl -l | grep "KiCad"; do
  sleep 1
done

# Maximize the application window
wmctrl -r "KiCad" -b add,maximized_vert,maximized_horz
