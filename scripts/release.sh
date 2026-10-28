#!/usr/bin/env bash
# Check main is committed and pushed, export all platforms, tag HEAD with the
# next version, push the tag and push the builds to itch.io.
#USAGE arg "[version]" default="patch" help="patch (default), minor, major, or an explicit tag like v1.2.3"
set -euo pipefail
version="${usage_version}"
case "$version" in
  patch|minor|major) ;;
  *) [[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "version must be patch, minor, major or look like v1.2.3, got '$version'" >&2; exit 1; } ;;
esac
# Exports rsync the whole working tree, so untracked (non-ignored) files would ship too.
[[ -z "$(git status --porcelain)" ]] || { echo "uncommitted or untracked files; commit, stash or ignore them first" >&2; git status --short >&2; exit 1; }
branch="$(git branch --show-current)"
[[ "$branch" == main ]] || { echo "on branch '${branch:-detached HEAD}'; releases must be cut from main" >&2; exit 1; }
git fetch --tags --quiet origin main
read -r behind ahead < <(git rev-list --left-right --count origin/main...HEAD)
if (( ahead || behind )); then
  echo "main is out of sync with origin/main ($ahead ahead, $behind behind); push/pull first" >&2
  exit 1
fi
latest="$(git tag -l 'v*' --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -n1 || true)"
IFS=. read -r major minor patch <<< "${latest#v}"
major=${major:-0} minor=${minor:-0} patch=${patch:-0}
case "$version" in
  patch) tag="v$major.$minor.$((patch + 1))" ;;
  minor) tag="v$major.$((minor + 1)).0" ;;
  major) tag="v$((major + 1)).0.0" ;;
  *) tag="$version" ;;
esac
git rev-parse -q --verify "refs/tags/$tag" >/dev/null && { echo "tag $tag already exists" >&2; exit 1; }
# Fails before anything is exported or tagged if butler can't reach itch.io.
bash scripts/itch_preflight.sh
echo "Releasing $tag (previous: ${latest:-none})"
mise run export-desktop
git tag -a "$tag" -m "$tag"
git push origin "$tag"
mise run itch --skip-export "$tag"
