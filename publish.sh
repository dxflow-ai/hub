#!/usr/bin/env bash
set -euo pipefail

# Hand a workflow to GitHub Actions from a workstation: pick an entry, see what a
# rebuild of it drags along, merge the work to main, and dispatch the publish
# workflow there — the build, the end-to-end verify, and the registry push all happen
# on runners, on the arch each image ships for. See .github/workflows/publish.yml.
#
# What reaches the registry is what is on main, so the merge comes first and the run
# is dispatched against main rather than whatever branch the work was done on.
#
# Usage: ./publish.sh           # interactive: pick a workflow, then dispatch
#        ./publish.sh <key>     # dispatch that workflow, e.g. ./publish.sh fastqc

REMOTE="origin"
RELEASE_BRANCH="main"
WORKFLOW_FILE="publish.yml"

die() { echo "Error: $*" >&2; exit 1; }
confirm() { read -rp "$1 [y/N]: " reply; [[ "$reply" == [yY] ]] || { echo "Aborted."; exit 0; }; }

# Preflight: tooling present, run from the hub repo root, GitHub reachable.
command -v git >/dev/null 2>&1                 || die "git is required"
command -v gh >/dev/null 2>&1                  || die "gh (GitHub CLI) is required"
[[ -f index.md && -d .github/workflows ]]      || die "run from the hub repo root"
gh auth status >/dev/null 2>&1                 || die "not signed in — run: gh auth login"
gh workflow view "$WORKFLOW_FILE" >/dev/null 2>&1 \
    || die "$WORKFLOW_FILE is not dispatchable — it has to be on the repository's default branch"

# The lookups the runner scripts use, so the preview here matches what they plan.
# shellcheck disable=SC1091
. .github/scripts/resolve.sh

# Report like the rest of this script, not as an Actions annotation
fail() { die "$*"; }

# The runner checks out a ref, not this working copy, so anything uncommitted or
# unpushed is invisible to the build about to run. Both are refused rather than
# noted: the merge below checks out main and back, which a dirty tree does not
# survive, and an unpushed commit would reach main without ever reaching its own
# branch on the remote.
branch="$(git branch --show-current)"
[[ -n "$branch" ]] || die "detached HEAD — check out a branch first"

git fetch --quiet "$REMOTE" "$branch" 2>/dev/null || die "no ${branch} on ${REMOTE} — push it first"
git fetch --quiet "$REMOTE" "$RELEASE_BRANCH"
[[ -z "$(git status --porcelain)" ]] || die "working tree is not clean — commit or stash first"
[[ "$(git rev-parse @)" == "$(git rev-parse "${REMOTE}/${branch}")" ]] \
    || die "${branch} differs from ${REMOTE}/${branch} — push it first"

# Pick the entry.
workflow="${1:-}"
if [[ -z "$workflow" ]]; then
    options=()
    while IFS= read -r key; do
        options+=("$key")
    done < <(publishable)

    PS3="publish which workflow? (number, or q to quit) "
    select choice in "${options[@]}"; do
        if [[ -n "$choice" ]]; then
            workflow="$choice"
            break
        fi
        [[ "$REPLY" == "q" ]] && { echo "Cancelled."; exit 0; }
    done
fi

[[ -n "$workflow" ]] || { echo "Cancelled."; exit 0; }
grep -qx "$workflow" <<< "$(publishable)" || die "unknown or unpublishable workflow: $workflow"

# Show what a rebuild reaches: an entry built FROM this one is stale the moment this
# one is republished, so the run rebuilds it too, in a later wave.
plan "$workflow"
deepest="$(deepest_wave)"

echo
echo "Publishing from ${REMOTE}/${RELEASE_BRANCH}:"
for wave in $(seq 0 "$deepest"); do
    echo "  wave $((wave + 1))  $(wave_keys "$wave" | paste -sd' ' -)"
done

dependents="true"
if [[ "$deepest" -gt 0 ]]; then
    echo
    read -rp "Rebuild the workflows built on ${workflow} too? [Y/n]: " reply
    [[ "$reply" == [nN] ]] && dependents="false"
fi

summary="$workflow"
if [[ "$dependents" == "false" ]]; then
    summary="$workflow alone"
fi

echo
if [[ "$branch" == "$RELEASE_BRANCH" ]]; then
    confirm "Dispatch publish for ${summary} on ${REMOTE}/${RELEASE_BRANCH}?"
else
    confirm "Merge '${branch}' into ${RELEASE_BRANCH} and dispatch publish for ${summary}?"
fi

# Bring the work onto main before the run reads it. The working branch is the source
# of truth, so -X theirs settles any drift in its favour rather than stopping the
# publish on a conflict — the same merge platform/publish.sh makes for a release.
if [[ "$branch" != "$RELEASE_BRANCH" ]]; then
    git checkout "$RELEASE_BRANCH"
    git merge --ff-only "${REMOTE}/${RELEASE_BRANCH}" || die "${RELEASE_BRANCH} diverged from ${REMOTE} — reconcile first"
    git merge --no-ff -X theirs "$branch" -m "Merge ${branch} into ${RELEASE_BRANCH} to publish ${workflow}" \
        || die "merge failed — resolve conflicts and retry"
    git push "$REMOTE" "$RELEASE_BRANCH"

    # Leave the tree on the branch it started on rather than parked on main.
    git checkout "$branch"
    echo
fi

# --raw-field, not --field: gh workflow run reads @ syntax out of --field values
gh workflow run "$WORKFLOW_FILE" --ref "$RELEASE_BRANCH" \
    --raw-field workflow="$workflow" \
    --raw-field dependents="$dependents"

echo "Dispatched — track it with: gh run watch \$(gh run list --workflow=${WORKFLOW_FILE} --limit 1 --json databaseId --jq '.[0].databaseId')"
