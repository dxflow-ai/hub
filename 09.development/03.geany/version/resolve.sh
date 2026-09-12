# Geany comes from the rolling Void repository, which does not hold the same
# version for every arch — arm64 can sit releases behind. Each arch is pinned to
# what its own repository holds, and the version recorded is the lower of the two,
# so the page never claims more than an arch actually ships.

amd64="$(xbps_package geany x86_64)"
arm64="$(xbps_package geany aarch64)"

echo "PACKAGE_AMD64=$amd64"
echo "PACKAGE_ARM64=$arm64"
echo "VERSION=$(lowest "${amd64%_*}" "${arm64%_*}")"
