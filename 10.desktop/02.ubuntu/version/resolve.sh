# The desktop stays on an Ubuntu LTS, which is what `latest` resolves to — asking
# for the highest .04 would take a devel tag the moment one appears.

echo "VERSION=$(docker_latest library/ubuntu '^[0-9]+\.04$')"
echo "QTFM=$(github_release rodlie/qtfm)"
echo "NOVNC=$(github_release novnc/noVNC)"
echo "WEBSOCKIFY=$(github_release novnc/websockify)"
