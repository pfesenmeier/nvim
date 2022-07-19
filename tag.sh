#! /usr/bin/env bash
dry=0

if [[ $1 == "-d" ]]; then
  dry=1
fi

# dry run mode
MANIFEST_CHANGES=$(git log --oneline --reverse -- Cargo.toml | awk '{print $1}')

PREVIOUS_PACKAGE_VERSION=''
for COMMIT in $MANIFEST_CHANGES; do
  # assuming here the package version is the first semver in the manifest
  PACKAGE_VERSION=$(git show $COMMIT:Cargo.toml \
    | rg 'version.*"(.+)"' -or '$1' \
    | head -n 1)

  COMMIT_TAG=$(git tag --points-at $COMMIT | rg '^[0-9]+\.[0-9]+\.[0-9]+.*$')

  if [ -z "$PACKAGE_VERSION" ]; then
    echo "could not find package version for a commit"
    exit 1
  elif [[ -n "$COMMIT_TAG" && "$PACKAGE_VERSION" != "$COMMIT_TAG" ]]; then
    echo "something went wrong! package and tag do not match for commit $COMMIT"
    exit 1
  fi


  if [[ "$PACKAGE_VERSION" != "$PREVIOUS_PACKAGE_VERSION" && "$COMMIT_TAG" == "$PACKAGE_VERSION" ]]; then
    echo "$COMMIT: $PREVIOUS_PACKAGE_VERSION => $PACKAGE_VERSION tag: $COMMIT_TAG"
  fi

  if [[ "$PACKAGE_VERSION" != "$PREVIOUS_PACKAGE_VERSION" && -z "$COMMIT_TAG" ]]; then
    echo "NEW $COMMIT: $PREVIOUS_PACKAGE_VERSION => $PACKAGE_VERSION tag: $PACKAGE_VERSION"

    if [[ $dry -eq 0 ]]; then
      git tag $PACKAGE_VERSION $COMMIT
    fi
  fi

  PREVIOUS_PACKAGE_VERSION="$PACKAGE_VERSION"
done

