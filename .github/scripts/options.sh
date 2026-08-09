#!/usr/bin/env bash
set -euo pipefail

# Refresh the publish workflow's dropdown from the entries on disk: a
# workflow_dispatch choice has to be a literal list, so re-run this after adding,
# renaming, or promoting a workflow. Idempotent — it rewrites the whole list.
# shellcheck disable=SC1091
. "$(dirname "$0")/resolve.sh"

file=".github/workflows/publish.yml"

keys=()
while IFS= read -r key; do
    keys+=("$key")
done < <(publishable)

[[ "${#keys[@]}" -gt 0 ]] || fail "no publishable entries found"

# Replace the items under `options:`, taking their indent from the key itself
temp="$(mktemp)"
awk -v keys="$(IFS=,; echo "${keys[*]}")" '
    /^ +options:$/ {
        print
        match($0, /^ +/)
        indent = substr($0, 1, RLENGTH) "    "
        total = split(keys, list, ",")
        for (position = 1; position <= total; position++) {
            print indent "- " list[position]
        }
        skip = 1
        next
    }
    skip && /^ +- / { next }
    { skip = 0; print }
' "$file" > "$temp"
mv "$temp" "$file"

echo "==> ${#keys[@]} options in $file"
