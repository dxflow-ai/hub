# The desktop is a Fedora release plus the pieces it builds from source. Fedora
# stays on its numbered releases — rawhide is not one.

echo "VERSION=$(docker_tag library/fedora '^[0-9]+$')"
echo "TINT2=$(gitlab_tag o9000/tint2 '^[0-9]+\.[0-9]+\.[0-9]+$')"
echo "AUTOCUTSEL=$(github_release sigmike/autocutsel)"
echo "QTFM=$(github_release rodlie/qtfm)"
echo "NOVNC=$(github_release novnc/noVNC)"
echo "WEBSOCKIFY=$(github_release novnc/websockify)"
