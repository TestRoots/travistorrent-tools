#!/bin/bash
cd ..
printf "Now, we pokes en-mass whether a project has a Travis build history\n\n"
dir=`pwd`

ruby -Ibin bin/travis_poker.rb -f $dir/gh-active-java-projects.csv