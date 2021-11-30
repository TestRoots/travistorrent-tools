### Running the data extraction process

#### Install dependencies and start extracting build logs

```
$ apt-get update
$ apt-get install ruby ruby-dev bundler pkg-config libmysqlclient-dev cmake libicu-dev parallel
$ git clone https://github.com/ECS260-TEAM6/travistorrent-tools.git
$ cd travistorrent-tools
$ git checkout ECS260
$ gem install bundler:1.16.2
$ gem install charlock_holmes -v '0.7.6' --source 'https://rubygems.org/'
$ bundle install
$ nohup cat {REPOS_FILE} | parallel -j 5 --colsep ' ' ruby bin/travis_harvester.rb &
```

#### Useful commands

##### Print all errors file
```
find . -name "errors" -exec cat {} \;
```

### Extracting GitHub features about each build

To extract features for one project, do

 ```bash
 ruby -Ibin bin/build_data_extraction.rb stripe brushfire github-token
 ```
 where `github-token` is a valid GitHub OAuth token used to download information
 about commits. To configure access to the required GHTorrent MySQL and MongoDB
 databases, copy `config.yaml.tmpl` to `config.yaml` and edit accordingly. You
 can have direct access to the GHTorrent MySQL and MongoDB databases using
 [this link](http://ghtorrent.org/services.html).

To extract features for multiple projects in parallel, you need

* A file (`project-list`) of projects, in the format specified above
* A file (`token-list`) of one or more Github tokens, one token per line

Then, run
```ruby
./bin/project_token.rb project-list token-list | sort -R > projects-tokens
./bin/all_projects.sh -p 4 -d data projects-tokens
```

this will create a file with tokens equi-distributed to projects
a directory `data`, and start 4 instanced of the `build_data_extraction.rb` script

### Analyzing Buildlogs
Our buildlog dispatcher handles everything that you typically want: It generates one convenient output file (a CSV) per project directory, and invokes an automatically dispatched correct buildlog analyzer. You can start the per-project analysis (typically on a directory structured checkedout through travis-harvester) via
```ruby
ruby bin/buildlog_analysis.rb directory-of-project-to-analyze
```

To start to analyze all buildlogs, parallel helps us again:
```bash
ls build_logs | parallel -j 5 ruby bin/buildlog_analysis.rb "build_logs/{}"
```

### Travis Breaking the Build
http://docs.travis-ci.com/user/customizing-the-build/

broken <- (errored|failed)
errored <- infrastructure
failed <- tests
canceled <- user abort

### Breaking the Build

If any of the commands in the first four stages returns a non-zero exit code, Travis CI considers the build to be broken.

When any of the steps in the before_install, install or before_script stages fails with a non-zero exit code, the build is marked as errored.

When any of the steps in the script stage fails with a non-zero exit code, the build is marked as failed.

Note that the script section has different semantics to the other steps. When a step defined in script fails, the build doesn’t end right away, it continues to run the remaining steps before it fails the build.

Currently, neither the after_success nor after_failure have any influence on the build result. Travis have plans to change this behaviour
