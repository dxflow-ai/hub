# ParaView keeps its binaries under a directory per series. Take the newest series
# that actually carries a Linux build — the newest one often has none yet — and read
# the version and the python it was built against off the file name.

for series in $(listing https://www.paraview.org/files/ 'v[0-9]+\.[0-9]+' | sort -Vru | head -5); do
    file="$(listing "https://www.paraview.org/files/$series/" \
        'ParaView-[0-9.]+-MPI-Linux-Python[0-9.]+-x86_64\.tar\.gz' | newest)" || continue

    echo "VERSION=$(printf '%s' "$file" | sed 's/^ParaView-//;s/-MPI.*//')"
    echo "PYTHON=$(printf '%s' "$file" | sed 's/.*-Python//;s/-x86_64.*//')"
    break
done
