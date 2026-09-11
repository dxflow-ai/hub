# OpenFOAM publishes one repository per release rather than one tag, each pinned to
# the ParaView it was built against.

repo="$(docker_repo openfoam '^openfoam[0-9]+-paraview[0-9]+$')"

echo "VERSION=$(printf '%s' "$repo" | sed 's/^openfoam//;s/-paraview.*//')"
echo "PARAVIEW=$(printf '%s' "$repo" | sed 's/.*-paraview//')"
