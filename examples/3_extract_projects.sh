#!/bin/bash

cd ..
printf "Extracting only active projects to travis_active and extracting only projects that have history on Travis CI to travis_enabled\n\n"

# get only active projects
grep "^[^,]\+,[^,]\+,[^,]\+,[^,]\+,1," gh-active-java-projects-annotated.csv > travis_active
# get only projects that have history on Travis CI
grep "^[^,]\+,[^,]\+,[^,]\+,[^,]\+,[^,]\+,1," gh-active-java-projects-annotated.csv > travis_enabled