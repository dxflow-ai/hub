# LibreCAD comes from the Ubuntu archive, where amd64 is served by archive.ubuntu.com
# and arm64 by ports.ubuntu.com — two indexes that can move apart, so each arch is
# pinned to what its own index holds and the version recorded is the lower of the two.
# The archive spells a version with its packaging revision, and marks a repacked
# source with a +dfsg suffix; the recorded version keeps neither, since a registry
# tag cannot hold a "+" anyway.
#
# `resolute` is Ubuntu 26.04, the release the Ubuntu desktop pins — move that pin
# and this codename moves with it.

index="http://archive.ubuntu.com/ubuntu/dists/resolute/universe/binary-amd64/Packages.gz"
ports="http://ports.ubuntu.com/ubuntu-ports/dists/resolute/universe/binary-arm64/Packages.gz"

amd64="$(apt_version "$index" librecad)"
arm64="$(apt_version "$ports" librecad)"

echo "PACKAGE_AMD64=$amd64"
echo "PACKAGE_ARM64=$arm64"
echo "VERSION=$(lowest "${amd64%%[-+]*}" "${arm64%%[-+]*}")"
