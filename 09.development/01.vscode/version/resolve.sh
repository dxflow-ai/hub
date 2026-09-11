# The Microsoft apt repository indexes each release under the timestamp it was
# packaged at, and the arches are packaged minutes apart — so each arch is pinned
# to what its own index carries, and the release they share is what gets recorded.

index="https://packages.microsoft.com/repos/code/dists/stable/main"

amd64="$(apt_version "$index/binary-amd64/Packages" code)"
arm64="$(apt_version "$index/binary-arm64/Packages" code)"

echo "PACKAGE_AMD64=$amd64"
echo "PACKAGE_ARM64=$arm64"
echo "VERSION=$(lowest "${amd64%%-*}" "${arm64%%-*}")"
