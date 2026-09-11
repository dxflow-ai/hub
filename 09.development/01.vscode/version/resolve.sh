# The Microsoft apt repository indexes each release by its version and the timestamp
# it was packaged at, so the install names both and the entry records the release.
# An arch never ships alone, so the amd64 index answers for arm64 too.

package="$(apt_version https://packages.microsoft.com/repos/code/dists/stable/main/binary-amd64/Packages code)"

echo "VERSION=${package%%-*}"
echo "PACKAGE=$package"
