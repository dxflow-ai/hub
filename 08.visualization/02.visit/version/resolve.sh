# VisIt names its installer and tarball after the version with underscores, which
# the Dockerfile derives — the pin is the release itself.

echo "VERSION=$(github_release visit-dav/visit)"
