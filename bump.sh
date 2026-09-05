#!/bin/sh
# Bumps the pinned PocketBase release across every file that names it, then
# commits the result. Run on the host (Git Bash / Linux), not in the container.
#
#   ./bump.sh 0.40.3              bump and commit
#   ./bump.sh 0.40.3 --no-commit  rewrite the files only
set -e

# Every file carrying a hard-coded PB_VERSION. Keep this list in sync when
# adding a file that pins the version.
FILES=".env.example Dockerfile.root Dockerfile.rootless docker-compose.root.yml docker-compose.rootless.yml README.md"

NEW_VERSION="$1"
COMMIT=1
[ "$2" = "--no-commit" ] && COMMIT=0

if [ -z "${NEW_VERSION}" ]; then
  echo "usage: $0 <version> [--no-commit]   e.g. $0 0.40.3" >&2
  exit 1
fi

# Published tag without the leading "v".
if ! echo "${NEW_VERSION}" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "[bump] ERROR: '${NEW_VERSION}' is not a MAJOR.MINOR.PATCH version." >&2
  exit 1
fi

cd "$(dirname "$0")"

# Dockerfile.rootless is the source of truth for what is currently pinned.
OLD_VERSION=$(sed -n 's/^ARG PB_VERSION=//p' Dockerfile.rootless)
if [ -z "${OLD_VERSION}" ]; then
  echo "[bump] ERROR: could not read the current version from Dockerfile.rootless." >&2
  exit 1
fi

if [ "${OLD_VERSION}" = "${NEW_VERSION}" ]; then
  echo "[bump] Already pinned to ${NEW_VERSION} — nothing to do."
  exit 0
fi

# A dirty tree would get swept into the bump commit.
if [ "${COMMIT}" -eq 1 ] && [ -n "$(git status --porcelain)" ]; then
  echo "[bump] ERROR: working tree is not clean. Commit or stash first, or pass --no-commit." >&2
  exit 1
fi

echo "[bump] ${OLD_VERSION} -> ${NEW_VERSION}"
# Escape the dots so the old version matches literally.
OLD_PATTERN=$(echo "${OLD_VERSION}" | sed 's/\./\./g')
# shellcheck disable=SC2086
sed -i "s/${OLD_PATTERN}/${NEW_VERSION}/g" ${FILES}

# Catch any file the replacement missed (e.g. a version written differently).
# shellcheck disable=SC2086
if grep -n "${OLD_PATTERN}" ${FILES}; then
  echo "[bump] ERROR: ${OLD_VERSION} still present in the files above." >&2
  exit 1
fi

# shellcheck disable=SC2086
grep -n "${NEW_VERSION}" ${FILES}

if [ "${COMMIT}" -eq 0 ]; then
  echo "[bump] Files rewritten, not committed."
  exit 0
fi

# shellcheck disable=SC2086
git add ${FILES}
git commit -m "Bump PocketBase to ${NEW_VERSION}"
echo "[bump] Committed."
