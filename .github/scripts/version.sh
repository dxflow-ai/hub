#!/usr/bin/env bash
set -euo pipefail

# Find the version upstream ships today and bring the entry in line with it: the
# pins in build/Dockerfile and the "version" in the index.md json block, which is
# also the tag ./publish.sh publishes. Reports by default; --apply writes, leaving
# the entry ready for `make build` and `make publish`.
#
# Each entry answers for itself in version/resolve.sh — sourced with the lookups in
# upstream.sh in scope, printing one `NAME=VERSION` line per pin it tracks:
#
#     VERSION=0.12.1      the entry's own version: `ARG VERSION` and the json one
#     NOVNC=1.7.0         anything else it carries, named for what it pins rather
#                         than the part it plays: `ARG NOVNC_VERSION`
#
# A pin with no matching ARG in the Dockerfile is reported but not written — that
# is how an entry installing from a rolling repository (the xbps desktops, the
# conda notebooks) keeps its json version honest without pinning its build.
#
# The GitHub lookups go out anonymously unless the environment carries a token,
# and anonymous is 60 an hour for the whole host — enough for a sweep or two, not
# for a loop. A signed-in gh is borrowed when $GITHUB_TOKEN is not already set.
#
# Usage: version.sh                     # ask which, from the entries that resolve
#        version.sh <key> [--apply]     # one entry
#        version.sh --all [--apply]     # every entry that has a version/resolve.sh
# shellcheck disable=SC1090,SC1091
. "$(dirname "$0")/resolve.sh"
. .github/scripts/upstream.sh

# Borrow the token a workstation already has, so the GitHub lookups spend the
# account's allowance rather than the host's 60 an hour. Exported, since each
# entry's resolve.sh is sourced in a subshell of its own.
if [[ -z "${GITHUB_TOKEN:-}" ]] && command -v gh >/dev/null 2>&1; then
    GITHUB_TOKEN="$(gh auth token 2>/dev/null || true)"
    export GITHUB_TOKEN
fi

apply="false"
target=""
for argument in "$@"; do
    case "$argument" in
        --apply) apply="true" ;;
        --all) target="*" ;;
        -*) fail "unknown option: $argument" ;;
        *) target="$argument" ;;
    esac
done
target="${target:-${WORKFLOW:-}}"

# Ask which entry, the way ./publish.sh asks which to publish. Prints the choice,
# or nothing at all if the reader quits.
choose() {
    local options=("all") key choice
    while IFS= read -r key; do
        options+=("$key")
    done < <(resolvable)

    PS3="check which workflow? (number, or q to quit) "
    select choice in "${options[@]}"; do
        if [[ -n "$choice" ]]; then
            printf '%s' "$choice"
            return 0
        fi
        if [[ "$REPLY" == "q" ]]; then
            return 0
        fi
    done
}

if [[ -z "$target" ]]; then
    # A run with nowhere to ask — a hook, a pipe, Actions — is told rather than hung
    if [[ ! -t 0 ]]; then
        fail "no workflow given — pass a key or --all"
    fi

    target="$(choose)"
    if [[ -z "$target" ]]; then
        echo "Cancelled."
        exit 0
    fi
    if [[ "$target" == "all" ]]; then
        target="*"
    fi
fi

# The ARG a pin maps to. The entry's own version is the plain one, so a Dockerfile
# reads `ARG VERSION=0.12.1` for the tool and `ARG NOVNC_VERSION=1.7.0` for what it
# carries along.
arg_of() {
    [[ "$1" == "VERSION" ]] || printf '%s_' "$1"
    printf 'VERSION'
}

# The value an ARG holds in the entry's Dockerfile, empty when it has no such line.
pinned() {
    sed -n "s/^ARG[[:space:]]\{1,\}$1=[\"']\{0,1\}\([^\"'[:space:]]*\).*/\1/p" \
        "$context/Dockerfile" 2>/dev/null | head -1
}

# Point an ARG at a new value, in place.
repin() {
    sed -i.backup "s|^ARG[[:space:]]\{1,\}$1=.*|ARG $1=$2|" "$context/Dockerfile"
    rm -f "$context/Dockerfile.backup"
}

# Restamp the "version" of the index.md json block — only that block, so a version
# named anywhere else on the page is left alone.
restamp() {
    awk -v value="$1" '
        $0 == "```json" { inside = 1 }
        inside && !stamped && /"version"[[:space:]]*:/ {
            sub(/"version"[[:space:]]*:[[:space:]]*"[^"]*"/, "\"version\": \"" value "\"")
            stamped = 1
        }
        inside && $0 == "```" { inside = 0 }
        { print }
    ' "$dir/index.md" > "$dir/index.md.new"
    mv "$dir/index.md.new" "$dir/index.md"
}

# Report one pin and, under --apply, write it. Takes the file it lives in, the name
# it goes by there, what is on disk, and what upstream ships.
settle() {
    local file="$1" name="$2" current="$3" latest="$4"

    if [[ -z "$latest" ]]; then
        printf '    %-17s %-16s %s\n' "$file" "$name" "$current — lookup failed"
        missed=$((missed + 1))
        return 0
    fi

    [[ "$current" != "$latest" ]] || return 0

    printf '    %-17s %-16s %s → %s\n' "$file" "$name" "${current:-none}" "$latest"
    drifted=$((drifted + 1))

    [[ "$apply" == "true" ]] || return 0
    if [[ "$file" == "index.md" ]]; then
        restamp "$latest"
    else
        repin "$name" "$latest"
    fi
    written=$((written + 1))
}

keys=()
if [[ "$target" == "*" ]]; then
    while IFS= read -r key; do
        keys+=("$key")
    done < <(resolvable)
else
    keys=("$target")
fi

drifted=0
missed=0
written=0
for key in "${keys[@]}"; do
    WORKFLOW="$key"
    resolve

    if [[ ! -f "$dir/version/resolve.sh" ]]; then
        if [[ "$target" != "*" ]]; then
            fail "$key has no version/resolve.sh"
        fi
        continue
    fi

    echo "==> $key"
    before=$((drifted + missed))

    # Its own subshell: a lookup that dies takes the check down with it, not the run
    while IFS= read -r pin; do
        [[ "$pin" == *=* ]] || continue
        name="${pin%%=*}"
        latest="${pin#*=}"
        arg="$(arg_of "$name")"
        held="$(pinned "$arg")"

        if [[ -n "$held" ]]; then
            settle "build/Dockerfile" "$arg" "$held" "$latest"
        fi
        if [[ "$name" == "VERSION" && -n "$version" ]]; then
            settle "index.md" "version" "$version" "$latest"
        fi
    done < <(set +e; . "$dir/version/resolve.sh")

    if [[ $((drifted + missed)) -le "$before" ]]; then
        echo "    up to date"
    fi
done

echo
if [[ "$apply" == "true" ]]; then
    echo "==> $written updated, $missed missed"
    if [[ "$written" -gt 0 ]]; then
        echo "    build it before it ships: make build ARGS=<key> && make verify ARGS=<key>"
    fi
else
    echo "==> $drifted behind, $missed missed  (--apply to write)"
fi

[[ "$missed" -eq 0 ]] || exit 1
exit 0
