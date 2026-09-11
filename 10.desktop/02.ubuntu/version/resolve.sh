# The desktop stays on an Ubuntu LTS — the even-year .04 releases — plus the pieces
# it builds from source.

echo "VERSION=$(docker_tag library/ubuntu '^[0-9]*[02468]\.04$')"
echo "QTFM=$(github_release rodlie/qtfm)"
echo "NOVNC=$(github_release novnc/noVNC)"
echo "WEBSOCKIFY=$(github_release novnc/websockify)"
