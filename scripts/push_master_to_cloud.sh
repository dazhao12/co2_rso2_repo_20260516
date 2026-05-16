#!/bin/bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <REMOTE_URL> [REMOTE_NAME]"
  exit 1
fi

REMOTE_URL="$1"
REMOTE_NAME="${2:-origin}"

if git remote | grep -q "^${REMOTE_NAME}$"; then
  git remote set-url "${REMOTE_NAME}" "${REMOTE_URL}"
else
  git remote add "${REMOTE_NAME}" "${REMOTE_URL}"
fi

git checkout master
git push -u "${REMOTE_NAME}" master

echo "Pushed master to ${REMOTE_NAME}: ${REMOTE_URL}"
