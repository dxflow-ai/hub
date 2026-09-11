# The transfer runs the AWS CLI from its own image, whose tag is the CLI version.
# It stays on v2, the line the entrypoint's flags are written for.

echo "VERSION=$(docker_tag amazon/aws-cli '^2\.[0-9]+\.[0-9]+$')"
