#!/usr/bin/env bash

# Upstream version lookups for the entries' version/resolve.sh — sourced by
# ./version.sh, never run on its own. Each function prints one version and nothing
# else, so a check line reads `echo "VERSION=$(docker_tag staphb/fastqc)"`.
#
# Everything here is curl and the shell: no jq, no registry login, no endpoint that
# needs an account. A lookup that cannot answer prints nothing and returns
# non-zero, which ./version.sh reports as a miss rather than writing an empty pin.

# GET a url, riding out the flaky mirrors. An HTTP error fails rather than handing
# back an error page for a version. api.github.com picks up $GITHUB_TOKEN when the
# environment has one, which lifts the 60-per-hour anonymous limit.
fetch() {
    local auth=()
    if [[ -n "${GITHUB_TOKEN:-}" && "$1" == "https://api.github.com/"* ]]; then
        auth=(--header "Authorization: Bearer $GITHUB_TOKEN")
    fi

    if curl -fsSL --retry 3 --retry-delay 2 --max-time 45 \
        --header "User-Agent: dxflow-hub" ${auth[@]+"${auth[@]}"} "$1"; then
        return 0
    fi

    # 403 from an anonymous GitHub is almost always the hourly limit, which reads
    # like a broken lookup unless it says so
    if [[ "$1" == "https://api.github.com/"* && -z "${GITHUB_TOKEN:-}" ]]; then
        echo "    github refused an anonymous request — 60 an hour per host." >&2
        echo "    Sign in with gh, or set \$GITHUB_TOKEN, and it lifts." >&2
    fi

    return 1
}

# Print the first value a json string field holds, from stdin.
json_value() {
    sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1
}

# Print every value a repeated json string field holds, one per line, from stdin.
json_values() {
    grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | sed "s/.*:[[:space:]]*\"//;s/\"$//"
}

# Read candidates on stdin, keep the ones matching, print the highest. The version
# sort is what decides "latest" everywhere here — an upstream that happens to list
# newest first is not trusted to keep doing it.
newest() {
    local best
    best="$(grep -E "${1:-.}" | sort -V -u | tail -1)"

    [[ -n "$best" ]] || return 1
    printf '%s\n' "$best"
}

# The highest tag of a Docker Hub repository. Official images take the library
# prefix (`docker_tag library/ubuntu`). The second argument selects which tags
# count — it is the entry's pinning policy, so `^12\.` keeps a base on its major
# while still catching its patches. The third narrows what the API returns, for a
# repository with more tags than a few pages hold.
docker_tag() {
    local repo="$1" select="${2:-^[0-9]+([._][0-9]+)*$}" filter="${3:-}" page
    for page in 1 2 3; do
        fetch "https://hub.docker.com/v2/repositories/${repo}/tags?page_size=100&page=${page}${filter:+&name=$filter}" 2>/dev/null |
            json_values name
    done | newest "$select"
}

# The highest-named repository of a Docker Hub namespace, for an upstream that
# publishes one repository per release rather than one tag per release.
docker_repo() {
    local namespace="$1" select="$2" page
    for page in 1 2 3; do
        fetch "https://hub.docker.com/v2/repositories/${namespace}/?page_size=100&page=${page}" 2>/dev/null |
            json_values name
    done | newest "$select"
}

# The highest tag of a ghcr.io repository, through the anonymous pull token the
# registry hands out for a public image.
ghcr_tag() {
    local repo="$1" select="${2:-^[0-9]+([._][0-9]+)*$}" token
    token="$(fetch "https://ghcr.io/token?scope=repository:${repo}:pull" | json_value token)"
    [[ -n "$token" ]] || return 1

    curl -fsSL --retry 3 --max-time 45 --header "Authorization: Bearer $token" \
        "https://ghcr.io/v2/${repo}/tags/list" |
        tr ',' '\n' | grep -oE '"[^"]+"' | tr -d '"' | newest "$select"
}

# The tag of a repository's latest GitHub release, with any leading v dropped.
github_release() {
    fetch "https://api.github.com/repos/$1/releases/latest" | json_value tag_name | sed 's/^v//'
}

# The highest tag of a GitHub repository, for a project that tags without cutting
# releases — or one whose latest release is a pre-release.
github_tag() {
    fetch "https://api.github.com/repos/$1/tags?per_page=100" |
        json_values name | sed 's/^v//' | newest "${2:-}"
}

# The highest tag of a GitLab project, e.g. `gitlab_tag o9000/tint2`.
gitlab_tag() {
    local project="${1//\//%2F}"
    fetch "https://gitlab.com/api/v4/projects/${project}/repository/tags?per_page=100" |
        json_values name | sed 's/^v//' | newest "${2:-}"
}

# What the rolling Void repository holds for a package today, as the one line of
# json its record occupies.
xbps_record() {
    fetch "https://xq-api.voidlinux.org/v1/query/x86_64?q=$1" |
        tr '}' '\n' | grep -E "\"name\"[[:space:]]*:[[:space:]]*\"$1\"," | head -1
}

# The version it serves, cleaned up to be a tag: a `+N` upstream suffix goes, since
# a registry would refuse it.
xbps_version() {
    xbps_record "$1" | json_value version | sed 's/+[0-9]*$//'
}

# The exact package an `xbps-install` has to name to get that version and nothing
# else — `<version>_<revision>`, which is how xbps spells a pinned package.
xbps_package() {
    xbps_record "$1" |
        sed -n 's/.*"version"[^"]*"\([^"]*\)".*"revision"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1_\2/p'
}

# The version a conda channel serves for a package, conda-forge unless told otherwise.
conda_version() {
    fetch "https://api.anaconda.org/package/${2:-conda-forge}/$1" | json_value latest_version
}

# The version PyPI serves for a package.
pypi_version() {
    fetch "https://pypi.org/pypi/$1/json" | tr ',' '\n' | json_value version
}

# The version the npm registry serves for a package.
npm_version() {
    fetch "https://registry.npmjs.org/$1/latest" | json_value version
}

# The highest version of a package in a Debian/Ubuntu apt index, given the url of
# its Packages file.
apt_version() {
    fetch "$1" | awk -v package="$2" '
        $1 == "Package:" { match_package = ($2 == package) }
        match_package && $1 == "Version:" { print $2 }
    ' | newest "${3:-}"
}

# The hrefs and file names a plain directory listing or download page mentions,
# for an upstream with no api at all.
listing() {
    fetch "$1" | grep -oE "${2:-href=\"[^\"]*\"}"
}
