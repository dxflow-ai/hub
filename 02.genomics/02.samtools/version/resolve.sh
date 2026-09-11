# Samtools is re-published from the staphb image, whose tag is the samtools version.

echo "VERSION=$(docker_tag staphb/samtools '^[0-9]+\.[0-9]+(\.[0-9]+)?$')"
