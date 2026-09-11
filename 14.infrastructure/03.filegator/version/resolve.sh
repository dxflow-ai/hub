# FileGator publishes a release build per tag in a repository of its own, and the
# Dockerfile fetches that zip by name — so the entry's version is the release tag.
# The php-fpm it runs on stays on the 8.3 line, the one upstream builds and tests
# against; a newer interpreter is a change to make deliberately, not on a sweep.

echo "VERSION=$(github_release filegator/filegator)"
echo "PHP=$(docker_tag library/php '^8\.3\.[0-9]+-fpm-bookworm$' 'fpm')"
