# PyMOL ships prebuilt tarballs from a public bucket, and the installer is named
# for three things at once: the version, the build it came out of, and the python
# it was built against.

file="$(fetch 'https://storage.googleapis.com/storage/v1/b/pymol-storage/o?prefix=installers/PyMOL-&fields=items/name' |
    grep -oE 'PyMOL-[^"]+-Linux-x86_64-py[0-9]+\.tar\.bz2' |
    sed 's/^PyMOL-//;s/\.tar\.bz2$//' | newest)"

build="${file#*_}"

echo "VERSION=${file%%_*}"
echo "BUILD=${build%%-*}"
echo "PYTHON=$(printf '%s' "${file##*-py}" | sed 's/\(.\)/\1./')"
