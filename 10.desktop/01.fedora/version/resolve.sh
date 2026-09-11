# The desktop is a Fedora release plus the pieces it builds from source. Fedora
# numbers its branched release and its rawhide before either ships, so the release
# to build on is the one `latest` resolves to rather than the highest number.

echo "VERSION=$(docker_latest library/fedora '^[0-9]+$')"
echo "TINT2=$(gitlab_tag o9000/tint2 '^[0-9]+\.[0-9]+\.[0-9]+$')"
echo "AUTOCUTSEL=$(github_release sigmike/autocutsel)"
echo "QTFM=$(github_release rodlie/qtfm)"
echo "NOVNC=$(github_release novnc/noVNC)"
echo "WEBSOCKIFY=$(github_release novnc/websockify)"
