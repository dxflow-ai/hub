# FastQC is re-published from the staphb image, whose tag is the FastQC version.

echo "VERSION=$(docker_tag staphb/fastqc '^[0-9]+\.[0-9]+\.[0-9]+$')"
