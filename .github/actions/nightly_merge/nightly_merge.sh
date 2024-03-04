#!/bin/bash

set -e

echo
echo "  'Nightly Merge' is using the following input:"
echo "    - stable_branch = '$STABLE_BRANCH'"
echo "    - development_branch = '$DEVELOPMENT_BRANCH'"
echo "    - allow_ff = $ALLOW_FF"
echo "    - allow_git_lfs = $ALLOW_GIT_LFS"
echo "    - ff_only = $FF_ONLY"
echo "    - allow_forks = $ALLOW_FORKS"
echo "    - user_name = $USER_NAME"
echo "    - user_email = $USER_EMAIL"
echo "    - push_token = $PUSH_TOKEN = ${!PUSH_TOKEN}"
echo

if [[ $ALLOW_FORKS != "true" ]]; then
  URI=https://api.github.com
  API_HEADER="Accept: application/vnd.github.v3+json"
  AUTH_HEADER=$([ -z "${GITHUB_TOKEN}" ] && echo 'foo: bar' || echo "Authorization: bearer ${GITHUB_TOKEN}")
  pr_resp=$(curl -X GET -s -H "${AUTH_HEADER}" -H "${API_HEADER}" "${URI}/repos/$GITHUB_REPOSITORY")
  if [[ "$(echo "$pr_resp" | jq -r .fork)" != "false" ]]; then
    echo "Nightly merge action is disabled for forks (use the 'allow_forks' option to enable it)."
    exit 0
  fi
fi

if [[ -z "${!PUSH_TOKEN}" ]]; then
  echo "Set the ${PUSH_TOKEN} env variable."
  exit 1
fi

FF_MODE="--no-ff"
if [[ "$ALLOW_FF" == "true" ]]; then
  FF_MODE="--ff"
  if [[ "$FF_ONLY" == "true" ]]; then
    FF_MODE="--ff-only"
  fi
else
  if [[ "$FF_ONLY" == "true" ]]; then
    echo "ff_only specified, but allow_ff isn't please update the options to make them consistent"
    exit 1
  fi
fi

git remote set-url origin https://x-access-token:${!PUSH_TOKEN}@github.com/$GITHUB_REPOSITORY.git
git config --global user.name "$USER_NAME"
git config --global user.email "$USER_EMAIL"

set -o xtrace

git fetch origin $STABLE_BRANCH
git checkout -b $STABLE_BRANCH origin/$STABLE_BRANCH

git fetch origin $DEVELOPMENT_BRANCH
git checkout -b $DEVELOPMENT_BRANCH origin/$DEVELOPMENT_BRANCH

if git merge-base --is-ancestor $STABLE_BRANCH $DEVELOPMENT_BRANCH; then
  echo "No merge is necessary"
  exit 0
fi;

# Get the current date in mm/dd/yyyy format
#DATE=$(date +"%m/%d/%Y")

#NEW_BRANCH="$STABLE_BRANCH_merge_into_$DEVELOPMENT_BRANCH_$DATE"

#git checkout -b $NEW_BRANCH origin/$DEVELOPMENT_BRANCH

# Do the merge
#git merge $FF_MODE --no-edit $STABLE_BRANCH

set +o xtrace
echo
echo "  'Nightly Merge Action' is trying to merge the '$STABLE_BRANCH' branch ($(git log -1 --pretty=%H $STABLE_BRANCH))"
echo "  into the '$DEVELOPMENT_BRANCH' branch ($(git log -1 --pretty=%H $DEVELOPMENT_BRANCH))"
echo
set -o xtrace

# Pull lfs if enabled
if [[ $INPUT_GIT_LFS == "true" ]]; then
  git lfs pull
fi

# Push the branch
git push origin $STABLE_BRANCH:$DEVELOPMENT_BRANCH