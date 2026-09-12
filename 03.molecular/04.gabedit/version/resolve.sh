# Gabedit comes from the Fedora repositories, which serve one build for every arch,
# so a single pin covers both. The pin is the package as dnf spells it — version and
# release together — and the recorded version keeps only the version part.
#
# The branch to ask is whatever release the Fedora desktop pins, read from its own
# Dockerfile, so this entry follows the base it builds on instead of carrying a
# second copy of the number to keep in step.

release="$(sed -n 's/^ARG VERSION=\([0-9]\{1,\}\).*/\1/p' 10.desktop/01.fedora/build/Dockerfile | head -1)"

echo "VERSION=$(dnf_version gabedit "f${release}")"
echo "PACKAGE=$(dnf_package gabedit "f${release}")"
