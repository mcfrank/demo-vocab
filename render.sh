#!/bin/bash

rm -rf out || exit 0;
mkdir out;

R CMD BATCH render.R;

cd out
git checkout gh-pages
git add .
git commit -m "deployed to github pages"
git push --force --quiet master:gh-pages
