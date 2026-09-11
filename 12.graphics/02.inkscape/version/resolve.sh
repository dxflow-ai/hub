# Inkscape comes from the rolling Void repository, so the build names the exact package —
# the version together with its packaging revision — that the recorded version
# stands for.

echo "VERSION=$(xbps_version inkscape)"
echo "PACKAGE=$(xbps_package inkscape)"
