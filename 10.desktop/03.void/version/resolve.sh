# Void is a rolling release, so the dated base snapshot the desktop builds from is
# the closest thing it has to a version of its own — everything the image installs
# on top comes from the repository as it stood that day. The noVNC stack is pinned
# separately, since it is fetched from GitHub rather than xbps.

echo "VERSION=$(ghcr_tag void-linux/void-glibc '^[0-9]{8}R[0-9]+$')"
echo "NOVNC=$(github_release novnc/noVNC)"
echo "WEBSOCKIFY=$(github_release novnc/websockify)"
