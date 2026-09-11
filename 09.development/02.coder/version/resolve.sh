# code-server is installed by its own install.sh, which takes the release to fetch.
# The Void it runs on is pinned too.

echo "VERSION=$(github_release coder/code-server)"
echo "VOID=$(ghcr_tag void-linux/void-glibc '^[0-9]{8}R[0-9]+$')"
