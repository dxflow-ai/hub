#!/bin/sh

# Launch
echo "Launching ..."

# Hand the desktop's X credentials to the unprivileged user (the app refuses to run as root)
cp /root/.Xauthority /volume/app/.Xauthority
chown app:app /volume/app/.Xauthority

# Start the application as that user
nohup su -s /bin/sh -c "DISPLAY=$DISPLAY XAUTHORITY=/volume/app/.Xauthority PULSE_SERVER=${PULSE_SERVER:-unix:/run/pulse/native} HOME=/volume/app LIBGL_ALWAYS_SOFTWARE=1 vlc --no-qt-privacy-ask" app &

# Wait for the application to start
while ! wmctrl -l | grep "VLC media player"; do
  sleep 1
done

# Maximize the application window
wmctrl -r "VLC media player" -b add,maximized_vert,maximized_horz
