#!/bin/bash
cd ..

dir=`pwd`

ls $dir/build_logs | parallel -j 20 python3 bin/travis_plot_repo_analysis.py -r "$dir/build_logs/{}"