#!/bin/sh

# Launch
echo "Launching ..."

# Install extensions
nohup code --user-data-dir="/volume/app/.$HOSTNAME/vscode/" --extensions-dir="/volume/app/.$HOSTNAME/vscode/extensions/" --install-extension github.copilot &

# Start the application
nohup code --no-sandbox --disable-chromium-sandbox --disable-gpu --disable-dev-shm-usage --user-data-dir="/volume/app/.$HOSTNAME/vscode/" --extensions-dir="/volume/app/.$HOSTNAME/vscode/extensions/" &

# Wait for the application to start
while ! wmctrl -l | grep "Code"; do
  sleep 1
done

# Maximize the application window
wmctrl -r "Code" -b add,maximized_vert,maximized_horz
