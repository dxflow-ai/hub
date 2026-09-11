# nginx is run from its own official image, whose tag is the version. It stays on
# the stable line — the even minor — so the entry follows its patches without being
# carried onto a mainline release the moment upstream cuts one.

echo "VERSION=$(docker_tag library/nginx '^1\.30\.[0-9]+$')"
