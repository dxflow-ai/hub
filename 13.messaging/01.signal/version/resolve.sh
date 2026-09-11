# Signal comes from the rolling Void repository, so the build names the exact package —
# the version together with its packaging revision — that the recorded version
# stands for. The entry is amd64 only, so x86_64 is the only repository to ask.

echo "VERSION=$(xbps_version Signal-Desktop)"
echo "PACKAGE=$(xbps_package Signal-Desktop)"
