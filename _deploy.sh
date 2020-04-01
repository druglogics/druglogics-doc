#!/bin/bash

set -e

[ -z "${GITHUB_PAT}" ] && exit 0
[ "${TRAVIS_BRANCH}" != "master" ] && exit 0

git config --global user.email "bblodfon@gmail.com"
git config --global user.name "john"

# Build the book on master (docs/ has been updated)
Rscript -e "bookdown::render_book(input = 'index.Rmd', output_format = 'bookdown::gitbook')"

# Clone gh-pages branch
git clone -b gh-pages https://${GITHUB_PAT}@github.com/${TRAVIS_REPO_SLUG}.git repo
cd repo
git rm -rf *
cp -r ../docs/* ./
git add --all *
git commit -m "update book" || true
git push -q origin gh-pages

