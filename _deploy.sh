#!/bin/bash

set -e

[ -z "${GITHUB_PAT}" ] && exit 0
[ "${TRAVIS_BRANCH}" != "master" ] && exit 0

#git config --global user.email "bblodfon@gmail.com"
#git config --global user.name "john"

# TRAVIS_REPO_SLUG = owner_name/repo_name
git clone https://${GITHUB_PAT}@github.com/${TRAVIS_REPO_SLUG}.git repo
cd repo
bash _build.sh
git add --force docs/*
git commit -m "update docs" || true
git push

