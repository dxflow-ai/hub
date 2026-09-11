# JupyterLab is installed from conda-forge, which keeps every version it has ever
# served — so the build asks for one by name. The Void it runs on is pinned too.

echo "VERSION=$(conda_version jupyterlab)"
echo "VOID=$(ghcr_tag void-linux/void-glibc '^[0-9]{8}R[0-9]+$')"
