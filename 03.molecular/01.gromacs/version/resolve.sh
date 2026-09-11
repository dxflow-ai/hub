# GROMACS is built from the source tarball on its own ftp site.

echo "VERSION=$(listing https://ftp.gromacs.org/gromacs/ 'gromacs-[0-9]+\.[0-9]+(\.[0-9]+)?\.tar\.gz' |
    sed 's/^gromacs-//;s/\.tar\.gz$//' | newest)"

# CUDA stays on its major and on jammy: a new major is a port, not an update
echo "CUDA=$(docker_tag nvidia/cuda '^12\.[0-9]+\.[0-9]+-devel-ubuntu22\.04$' devel-ubuntu22.04 |
    sed 's/-devel.*//')"
