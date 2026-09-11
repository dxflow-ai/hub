# The staphb tag pairs the pangolin release with the pangolin-data it carries.

tag="$(docker_tag staphb/pangolin '^[0-9]+\.[0-9]+\.[0-9]+-pdata-[0-9.]+$')"

echo "VERSION=${tag%%-*}"
echo "PDATA=${tag##*-pdata-}"
