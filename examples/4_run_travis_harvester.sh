#!/bin/bash
cd ..
# pass filename as parameter, i.e., travis_enabled
cat $1 | parallel -j 20 --colsep ' ' ruby bin/travis_harvester.rb -s {1}/{2}