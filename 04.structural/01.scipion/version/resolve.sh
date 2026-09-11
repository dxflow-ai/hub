# scipion-installer pulls the current release rather than a pinned one, so nothing
# in the build is pinned — this only keeps the recorded version honest.

echo "VERSION=$(github_tag scipion-em/scipion-app '^[0-9]+\.[0-9]+\.[0-9]+$')"
