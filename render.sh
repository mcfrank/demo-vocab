#!/bin/bash

cd /home/ubuntu/demo-vocab/
rm -rf out || exit 0;
mkdir out;

R CMD BATCH render.R;

mv out ..
git checkout gh-pages
mv ../out/* .
rm -r ../out
git add .
git commit -m "deployed to github pages"
git push --force --quiet origin gh-pages
git checkout master
