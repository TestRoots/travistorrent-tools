#!/usr/bin/env ruby
#
# (c) 2012 -- 2016 Georgios Gousios <gousiosg@gmail.com>
# (c) 2015 -- 2016 Moritz Beller <moritzbeller -AT- gmx.de>
#
# BSD licensed, see LICENSE in top level dir

require 'time'
require 'linguist'
require 'thread'
require 'rugged'
require 'parallel'
require 'mongo'
require 'json'
require 'sequel'
require 'trollop'
require 'open-uri'
require 'net/http'
require 'fileutils'
require 'time_difference'

require_relative 'java'
require_relative 'ruby'
require_relative 'scala'
require_relative 'python'

class BuildDataExtraction

  include Mongo

  REQ_LIMIT = 4990
  THREADS = 2

  attr_accessor :builds, :owner, :repo, :all_commits, :closed_by_commit, :close_reason, :token

  class << self
    def run(args = ARGV)
      attr_accessor :options, :args, :name, :config

      command = new()
      command.name = self.class.name
      command.args = args

      command.process_options
      command.validate

      command.config = YAML::load_file command.options[:config]
      command.go
    end
  end

  def process_options
    #command = self
    @options = Trollop::options do
      banner <<-BANNER
Extract data for builds given a Github repo and a Travis build info file
A minimal Travis build info file should look like this

[
  {
    "build_id":68177642,
    "commit":"92f43dfb416990ce2f530ce29446481fe4641b73",
    "pull_req": null,
    "branch":"master",
    "status":"failed",
    "duration":278,
    "started_at":"2015-06-24 15:  42:17 UTC",
    "jobs":[68177643,68177644,68177645,68177646,68177647,68177648]
  }
]

Travis information contained in dir build_logs, one dir per Github repo

Token is a Github API token required to do API calls

usage:
#{File.basename($0)} owner repo token

      BANNER
      opt :config, 'config.yaml file location', :short => 'c',
          :default => 'config.yaml'
    end
  end

  def validate
    if options[:config].nil?
      unless file_exists?("config.yaml")
        Trollop::die "No config file in default location (#{Dir.pwd}). You
                        need to specify the #{:config} parameter."
      end
    else
      Trollop::die "Cannot find file #{options[:config]}" \
          unless File.exists?(options[:config])
    end

    Trollop::die 'Three arguments required' unless !args[1].nil?
  end

  def db
    Thread.current[:sql_db] ||= Proc.new do
      Sequel.single_threaded = true
      Sequel.connect(self.config['sql']['url'], :encoding => 'utf8')
    end.call
    Thread.current[:sql_db]
  end

  def mongo
    Thread.current[:mongo_db] ||= Proc.new do
      mongo_db = MongoClient.new(self.config['mongo']['host'], self.config['mongo']['port']).db(self.config['mongo']['db'])
      unless self.config['mongo']['username'].nil?
        mongo_db.authenticate(self.config['mongo']['username'], self.config['mongo']['password'])
      end
      mongo_db
    end.call
    Thread.current[:mongo_db]
  end

  def git
    Thread.current[:repo] ||= clone(ARGV[0], ARGV[1])
    Thread.current[:repo]
  end

  # Read a source file from the repo and strip its comments
  # The argument f is the result of Grit.lstree
  # Memoizes result per f
  def semaphore
    @semaphore ||= Mutex.new
    @semaphore
  end

  def load_builds(owner, repo)
    f = File.join("build_logs", "rubyjava", "#{owner}@#{repo}", "repo-data-travis.json")
    unless File.exists? f
      Trollop::die "Build file (#{f}) does not exist"
    end

    JSON.parse File.open(f).read, :symbolize_names => true
  end

  # Load a commit from Github. Will return an empty hash if the commit does not exist.
  def github_commit(owner, repo, sha)
    parent_dir = File.join('commits', "#{owner}@#{repo}")
    commit_json = File.join(parent_dir, "#{sha}.json")
    FileUtils::mkdir_p(parent_dir)

    r = nil
    if File.exists? commit_json
      r = begin
        JSON.parse File.open(commit_json).read
      rescue
        # This means that the retrieval operation resulted in no commit being retrieved
        {}
      end
      return r
    end

    url = "https://api.github.com/repos/#{owner}/#{repo}/commits/#{sha}"
    log("Requesting #{url} (#{@remaining} remaining)")

    contents = nil
    begin
      r = open(url, 'User-Agent' => 'ghtorrent', 'Authorization' => "token #{token}")
      @remaining = r.meta['x-ratelimit-remaining'].to_i
      @reset = r.meta['x-ratelimit-reset'].to_i
      contents = r.read
      JSON.parse contents
    rescue OpenURI::HTTPError => e
      @remaining = e.io.meta['x-ratelimit-remaining'].to_i
      @reset = e.io.meta['x-ratelimit-reset'].to_i
      log "Cannot get #{url}. Error #{e.io.status[0].to_i}"
      {}
    rescue StandardError => e
      log "Cannot get #{url}. General error: #{e.message}"
      {}
    ensure
      File.open(commit_json, 'w') do |f|
        f.write contents unless r.nil?
        f.write '' if r.nil?
      end

      if 5000 - @remaining >= REQ_LIMIT
        to_sleep = @reset - Time.now.to_i + 2
        log "Request limit reached, sleeping for #{to_sleep} secs"
        sleep(to_sleep)
      end
    end
  end

  def log(msg, level = 0)
    semaphore.synchronize do
      (0..level).each { STDERR.write ' ' }
      STDERR.puts msg
    end
  end

  # Main command code
  def go
    interrupted = false

    trap('INT') {
      log "#{File.basename($0)}(#{Process.pid}): Received SIGINT, exiting"
      interrupted = true
    }

    self.owner = ARGV[0]
    self.repo = ARGV[1]
    self.token = ARGV[2]

    user_entry = db[:users].first(:login => owner)

    if user_entry.nil?
      Trollop::die "Cannot find user #{owner}"
    end

    repo_entry = db.from(:projects, :users).\
                  where(:users__id => :projects__owner_id).\
                  where(:users__login => owner).\
                  where(:projects__name => repo).\
                  select(:projects__id, :projects__language).\
                  first

    if repo_entry.nil?
      Trollop::die "Cannot find repository #{owner}/#{repo}"
    end

    language = repo_entry[:language]

    unless %w(ruby Ruby Java java).include? language
      # Try to guess the language from "buildlog-data-travis.csv"
      require 'csv'
      csv = CSV.open(File.join("build_logs", "rubyjava", "#{owner}@#{repo}", "buildlog-data-travis.csv"))
      language = csv.readlines.last[3]
      log "Switching from GHTorrent provided language #{repo_entry[:language]} to #{language}"
    end

    case language
      when /ruby/i then
        self.extend(RubyData)
      when /java/i then
        self.extend(JavaData)
      else
        Trollop::die "Language #{language} not supported"
    end

    self.builds = load_builds(owner, repo)

    if builds.empty?
      log "No builds for #{owner}/#{repo}"
      return
    end

    log "#{builds.size} builds for #{owner}/#{repo}"

    # Filter out empty build dates
    self.builds = builds.reduce([]) do |acc, b|
      unless b[:started_at].nil?
        #b[:started_at] = Time.parse(b[:started_at])
        acc << b
      else
        acc
      end
    end

    log "After filtering empty build dates: #{builds.size} builds"

    log "\nCalculating GHTorrent PR ids"
    self.builds = builds.reduce([]) do |acc, build|
      unless is_pr?(build)
        acc << build
      else
        q = <<-QUERY
        select pr.id as id, prh.created_at as created_at
        from pull_requests pr, users u, projects p, pull_request_history prh
        where u.login = ?
        and p.name = ?
        and pr.pullreq_id = ?
        and p.owner_id = u.id
        and pr.base_repo_id = p.id
        and prh.pull_request_id = pr.id
        and prh.action = 'opened'
        order by prh.created_at asc
        limit 1
        QUERY
        r = db.fetch(q, owner, repo, build[:pull_req].to_i).first
        unless r.nil?
          build[:pull_req_id] = r[:id]
          build[:pull_req_created_at] = r[:created_at]
          log "GHT PR #{r[:id]} (#{r[:created_at]}) triggered build #{build[:pull_req]}", 1
          acc << build
        else
          # Not yet processed by GHTorrent, don't process further
          acc
        end
      end
    end

    log "After resolving GHT pullreqs: #{builds.size} builds for #{owner}/#{repo}"
    # Update the repo
    clone(owner, repo, true)

    log 'Retrieving all commits'
    walker = Rugged::Walker.new(git)
    walker.sorting(Rugged::SORT_DATE)
    walker.push(git.head.target)
    self.all_commits = walker.map do |commit|
      commit.oid[0..10]
    end
    log "#{all_commits.size} commits to process"

    # Get commits that close issues/pull requests
    # Index them by issue/pullreq id, as a sha might close multiple issues
    # see: https://help.github.com/articles/closing-issues-via-commit-messages
    q = <<-QUERY
    select c.sha
    from commits c, project_commits pc
    where pc.project_id = ?
    and pc.commit_id = c.id
    QUERY

    fixre = /(?:fixe[sd]?|close[sd]?|resolve[sd]?)(?:[^\/]*?|and)#([0-9]+)/mi

    log 'Calculating PRs closed by commits'
    commits_in_prs = db.fetch(q, repo_entry[:id]).all
    self.closed_by_commit =
        Parallel.map(commits_in_prs, :in_threads => THREADS) do |x|
          sha = x[:sha]
          result = {}
          mongo['commits'].find({:sha => sha},
                                {:fields => {'commit.message' => 1, '_id' => 0}}).map do |x|
            comment = x['commit']['message']

            comment.match(fixre) do |m|
              (1..(m.size - 1)).map do |y|
                result[m[y].to_i] = sha
              end
            end
          end
          result
        end.select { |x| !x.empty? }.reduce({}) { |acc, x| acc.merge(x) }
    log "#{closed_by_commit.size} PRs closed by commits"

    log 'Calculating PR close reasons'
    self.close_reason = builds.select { |b| not b[:pull_req].nil? }.reduce({}) do |acc, build|
      acc[build[:pull_req]] = merged_with(owner, repo, build)
      acc
    end
    log "Close reasons: #{close_reason.group_by { |_, v| v }.reduce({}) { |acc, x| acc.merge({x[0] => x[1].size}) }}"

    self.builds = builds.map { |x| x[:tr_build_commit] = x[:commit]; x }

    log 'Retrieving commits that were actually built (for pull requests)'
    # When building pull requests, travis creates artifical commits by merging
    # the commit to be built with the branch to be built. By default, it reports
    # those commits instead of the latest built PR commit.
    # The algorithm below attempts to resolve the actual PR commit. If the
    # PR commit (or the PR) cannot be retrieved, the build is skipped from further processing.
    self.builds = Parallel.map(builds, :in_threads => THREADS) do |build|
      if is_pr?(build)
        c = github_commit(owner, repo, build[:commit])
        unless c.empty?
          shas = c['commit']['message'].match(/Merge (.*) into (.*)/i).captures
          if shas.size == 2
            log "Replacing Travis commit #{build[:commit]} with actual #{shas[0]}", 2

            build[:commit] = shas[0]
            build[:tr_virtual_merged_into] = shas[1]

          end
          build
        else
          nil
        end
      else
        build
      end
    end.select { |x| !x.nil? }

    log "After resolving PR commits: #{builds.size} builds for #{owner}/#{repo}"

    log 'Calculating build diff information'
    build_stats = builds.map do |build|

      begin
        build_commit = git.lookup(build[:commit])
      rescue
        next
      end
      next if build_commit.nil?

      walker = Rugged::Walker.new(git)
      walker.sorting(Rugged::SORT_TOPO)
      walker.push(build_commit)

      # Get all previous commits up to a prior build or a branch point
      prev_commits = [build_commit]
      commit_resolution_status = :no_previous_build
      last_commit = nil

      walker.each do |commit|
        last_commit = commit

        if commit.oid == build_commit.oid
          if commit.parents.size > 1
            commit_resolution_status = :merge_found
            break
          end
          next
        end

        if not builds.select { |b| b[:commit] == commit.oid }.empty?
          commit_resolution_status = :build_found
          break
        end

        prev_commits << commit

        if commit.parents.size > 1
          commit_resolution_status = :merge_found
          break
        end

      end

      log "#{prev_commits.size} built commits (#{commit_resolution_status}) for build #{build[:build_id]}", 2

      {
          :build_id => build[:build_id],
          :prev_build => if not commit_resolution_status == :merge_found
                           builds.find { |b| b[:build_id] < build[:build_id] and last_commit.oid.start_with? b[:commit] }
                         else
                           nil
                         end,
          :commits => prev_commits.map { |c| c.oid },
          :authors => prev_commits.map { |c| c.author[:email] }.uniq,
          :prev_built_commit => commit_resolution_status == :merge_found ? nil : (last_commit.nil? ? nil : last_commit.oid),
          :prev_commit_resolution_status => commit_resolution_status
      }
    end.select { |x| !x.nil? }

    # Filter out builds without build statistics
    self.builds = builds.select do |b|
      not build_stats.find do |bd|
        bd[:build_id] == b[:build_id]
      end.nil?
    end
    log "After calculating build stats: #{builds.size} builds for #{owner}/#{repo}"

    # Merge build statistics into build information
    self.builds = builds.map { |b| b.merge(build_stats.find { |bs| bs[:build_id] == b[:build_id] }) }

    # Find push events for commits that triggered builds:
    # For builds that are triggered from PRs, we need to find the push
    # events in the source repositories. All the remaining builds are
    # from pushes to local repository branches
    forks = builds.select { |b| not b[:pull_req].nil? }.map do |b|
      # Resolve PR object
      pr = mongo['pull_requests'].find_one({'owner' => owner,
                                            'repo' => repo,
                                            'number' => b[:pull_req]})
      next if pr.nil?
      next if pr['head'].nil?
      next if pr['head']['repo'].nil?
      next if pr['head']['repo']['login'].nil?

      head_owner = pr['head']['user']['login']
      head_repo = pr['head']['repo']['name']
      {:owner => head_owner, :repo => head_repo}
    end.select { |x| !x.nil? }

    all_repos = (forks << {:owner => owner, :repo => repo}).uniq
    log 'Finding push events for all repositories that contributed pull requests'
    log "#{all_repos.size} repos to retrieve push events for"

    commit_push_info =
        all_repos.map do |repo|
          log "Retrieving push events for #{repo[:owner]}/#{repo[:repo]}"
          repo_commits = []
          push_events_processed = 0
          mongo['events'].find({'repo.name' => "#{repo[:owner]}/#{repo[:repo]}", 'type' => 'PushEvent'},
                               :timeout => false, :batch_size => 10) do |cursor|
            # Produce a list of commit object information items
            while cursor.has_next?
              push = cursor.next
              push['payload']['commits'].each do |commit|
                repo_commits << {:sha => commit['sha'],
                                 :pushed_at => push['created_at'],
                                 :push_id => push['id']}
                push_events_processed += 1
              end
            end
            log "#{push_events_processed} push events for #{repo[:owner]}/#{repo[:repo]}\n"
          end
          repo_commits
        end.\
        flatten.\
          # Gather all appearances of a commit in a list per commit
            group_by { |x| x[:sha] }.\
          # Find the first appearance of each commit
            reduce({}) do |acc, commit_group|
          # sort all commit appearances in descending order and get the earliest one
          if commit_group[1].size > 1
            log "Commit #{commit_group[0]} appears in #{commit_group[1].size} push events", 2
          end
          first_appearence = commit_group[1].sort { |a, b| a[:pushed_at] <=> b[:pushed_at] }.first
          acc.merge({commit_group[0] => [first_appearence[:pushed_at], first_appearence[:push_id]]})
        end

    # join build info with commit push info
    log 'Matching push events to build commits'
    builds.map do |build|
      push_info = commit_push_info[build[:commit]]

      unless push_info.nil?
        log "Push event at #{commit_push_info[build[:commit]][0]} triggered build #{build[:build_id]} (#{build[:commit]})", 2
        build[:commit_pushed_at] = commit_push_info[build[:commit]][0]
        build[:push_id] = commit_push_info[build[:commit]][1]

        push_event = mongo['events'].find_one({'id' => push_info[1]})
        pushed_commits = push_event['payload']['commits']

        timestamps = pushed_commits.map do |x|
          c = mongo['commits'].find_one({'sha' => x['sha']})

          # Try to find the commit on GitHub if it is not in GHTorrent
          c = c.nil? ? github_commit(owner, repo, x['sha']) : c
          c['commit']['author']['date'] unless c.nil? or c.empty?
        end.select { |x| !x.nil? }

        build[:first_commit_created_at] = timestamps.min
        build[:num_commits_in_push] = pushed_commits.size
        build[:commits_in_push] = pushed_commits.map { |c| c['sha'] }
      else
        log "No push event for build commit #{build[:commit]}", 2
      end
    end

    neg_latency = builds.select do |x|
      not x[:commit_pushed_at].nil? and
          Time.parse(x[:commit_pushed_at]) > Time.parse(x[:started_at])
    end
    no_push = builds.select { |x| x[:commit_pushed_at].nil? }
    log "#{neg_latency.size} builds have negative latency"
    log "#{no_push.size} builds have no push info"
    log "#{builds.size} builds to process"

    results = Parallel.map(builds, :in_threads => THREADS) do |build|
      if interrupted
        raise Parallel::Kill
      end

      begin
        r = process_build(build, owner, repo, language.downcase)
        log r
        r
      rescue StandardError => e
        log "Error processing build #{build[:build_id]}: #{e.message}"
        log e.backtrace
      end
    end.select { |x| !x.nil? }

    puts results.first.keys.map { |x| x.to_s }.join(',')
    results.sort { |a, b| b[:build_id]<=>a[:build_id] }.each { |x| puts x.values.join(',') }

  end

  def calculate_time_difference(walker, trigger_commit)
    begin
      latest_commit_time = git.lookup(trigger_commit).time
      first_commit_time = walker.take(1).first.time
      age = TimeDifference.between(latest_commit_time, first_commit_time).in_days
    rescue => e
      log "Exception on time difference processing commit #{tigger_commit}: #{e.message}"
      log e.backtrace
    ensure
      return age
    end
  end

  def calculate_number_of_commits(walker)
    begin
      num_commits = walker.count
    rescue => e
      log "Exception on commit numbers processing commit #{tigger_commit}: #{e.message}"
      log e.backtrace
    ensure
      return num_commits
    end
  end

  def calculate_confounds(trigger_comit)
    begin
      walker = Rugged::Walker.new(git)
      walker.sorting(Rugged::SORT_TOPO | Rugged::SORT_DATE | Rugged::SORT_REVERSE)
      walker.push(trigger_comit)

      age = calculate_time_difference(walker, trigger_comit)
      num_commits = calculate_number_of_commits walker
    ensure
      return {
          :repo_age => age,
          :repo_num_commits => num_commits
      }
    end
  end

  # Process a single build
  def process_build(build, owner, repo, lang)

    # Count number of src/comment lines
    sloc = src_lines(build[:commit])
    months_back = 3

    stats = calc_build_stats(owner, repo, build[:commits])

    pr_id = build[:pull_req] if is_pr?(build)
    committers = build[:authors].map { |a| github_login(a) }.select { |x| not x.nil? }
    main_team = main_team(owner, repo, build, months_back)
    test_diff = test_diff_stats(build[:prev_built_commit].nil? ? build[:commit] : build[:prev_built_commit], build[:commit])
    tr_original_commit = build[:tr_build_commit]
    prev_build_started_at = build[:prev_build].nil? ? nil : Time.parse(build[:prev_build][:started_at])
    git_trigger_commit = is_pr?(build) ? build[:commits][0] : tr_original_commit

    confounds = calculate_confounds(git_trigger_commit)

    # exclude any previously built commits
    new_commits = build[:commits].select do |c|
      builds.select do |b|
        b[:build_id] < build[:build_id] and
            b[:commits].include?(c)
      end.empty?
    end

    # Some sanity checking
    raise "Bad src lines: 0, build: #{build[:build_id]}" if sloc == 0
    raise 'The trigger commit should always be the first one' unless build[:commits].first == git_trigger_commit

    {
        # [doc] The analyzed build id, as reported from Travis CI.
        :tr_build_id => build[:build_id],

        # [doc] Project name on GitHub.
        :gh_project_name => "#{owner}/#{repo}",

        # [doc] Whether this build was triggered as part of a pull request on GitHub.
        :gh_is_pr => is_pr?(build),

        # [doc] If the build is a pull request, the creation timestamp for this pull request.
        :gh_pr_created_at => build[:pull_req_created_at],

        # [doc] If the build is a pull request, its ID on GitHub.
        :gh_pull_req_num => pr_id,

        # [doc] Dominant repository language, according to GitHub.
        :gh_lang => lang,

        # [doc] If this commit sits on a pull request (`gh_is_pr` true), how it was closed (merge button, manual merge, ...).
        :git_merged_with => close_reason[pr_id],

        # [doc] The branch that was built
        :git_branch => build[:branch],

        # [doc] Number of commits included in the push that triggered the build. In rare cases, GHTorrent has not
        # recorded a push event for the commit that created the build in which case `num_commits_in_push` is nil.
        :gh_num_commits_in_push => build[:num_commits_in_push],

        # [doc] The commits included in the push that triggered the build. In rare cases, GHTorrent has not recorded
        # a push event for the commit that created the build in which case `gh_commits_in_push` is nil.
        :gh_commits_in_push => build[:commits_in_push].nil? ? nil : build[:commits_in_push].join('#'),

        # [doc] When walking backwards the branch to find previously built commits, what is the reason for stopping
        # the traversal? Can be one of: `no_previous_build`: when , `build_found`: when we find a previous build,
        # or `merge_found`: when we had to stop traversal at a merge point (we cannot decide which of the parents to
        # follow).
        :git_prev_commit_resolution_status => build[:prev_commit_resolution_status],

        # [doc] The commit that triggered the previous build on a linearized history. If
        # `git_prev_commit_resolution_status` is `merge_found`, then this is nil.
        :git_prev_built_commit => build[:prev_built_commit],

        # [doc] The build triggered by `git_prev_built_commit`. If `git_prev_commit_resolution_status` is `merge_found`,
        # then this is nil.
        :tr_prev_build => build[:prev_build].nil? ? nil : build[:prev_build][:build_id],

        # [doc] Timestamp of first commit in the push that triggered the build. In rare cases, GHTorrent has not
        # recorded a push event for the commit that created the build in which case `first_commit_created_at` is nil.
        :gh_first_commit_created_at => build[:first_commit_created_at],

        # [doc] Number of developers that committed directly or merged PRs from the moment the build was triggered and 3 months back.
        :gh_team_size => main_team.size,

        # [doc] A list of all commits that were built for this build, up to but excluding the commit of the previous
        # build, or up to and including a merge commit (in which case we cannot go further backward).
        # The internal calculation starts with the parent for PR builds or the actual
        # built commit for non-PR builds, traverse the parent commits up until a commit that is linked to a previous
        # build is found (excluded, this is under `tr_prev_built_commit`) or until we cannot go any further because a
        # branch point was reached. This is indicated in `git_prev_commit_resolution_status`. This list is what
        # the `git_diff_*` fields are calculated upon.
        :git_all_built_commits => build[:commits].join('#'),

        # [doc] Number of `git_all_built_commits`.
        :git_num_all_built_commits => build[:commits].size,

        # [doc] The commit that triggered the build.
        :git_trigger_commit => git_trigger_commit,

        # [doc] The commit of the branch that the commit built by Travis is merged into when testing pull requests.
        :tr_virtual_merged_into => build[:tr_virtual_merged_into],

        # [doc] The original commit that was build as linked to from Travis. Might be a virtual commit that is not part
        # of the original repository.
        :tr_original_commit => tr_original_commit,

        # [doc] If git_commit is linked to a PR on GitHub, the number of discussion comments on that PR.
        :gh_num_issue_comments => num_issue_comments(build, prev_build_started_at, Time.parse(build[:started_at])),

        # [doc] The number of comments on `git_all_built_commits` on GitHub.
        :gh_num_commit_comments => num_commit_comments(owner, repo, build[:commits]),

        # [doc] If gh_is_pr is true, the number of comments (code review) on this pull request on GitHub.
        :gh_num_pr_comments => num_pr_comments(build, prev_build_started_at, Time.parse(build[:started_at])),

        # [doc] The emails of the committers of the commits in all `git_all_built_commits`.
        :git_diff_committers => build[:authors].join('#'),

        # [doc] Number of lines of production code changed in all `git_all_built_commits`.
        :git_diff_src_churn => stats[:lines_added] + stats[:lines_deleted],

        # [doc] Number of lines of test code changed in all `git_all_built_commits`.
        :git_diff_test_churn => stats[:test_lines_added] + stats[:test_lines_deleted],

        # [doc] Number of files added by all `git_all_built_commits`.
        :gh_diff_files_added => stats[:files_added],

        # [doc] Number of files deleted by all `git_all_built_commits`.
        :gh_diff_files_deleted => stats[:files_removed],

        # [doc] Number of files modified by all `git_all_built_commits`.
        :gh_diff_files_modified => stats[:files_modified],

        # [doc] Lines of testing code added by all `git_all_built_commits`.
        :gh_diff_tests_added => test_diff[:tests_added],

        # [doc] Lines of testing code deleted by all `git_all_built_commits`.
        :gh_diff_tests_deleted => test_diff[:tests_deleted],

        # [doc] Number of src files changed by all `git_all_built_commits`.
        :gh_diff_src_files => stats[:src_files],

        # [doc] Number of documentation files changed by all `git_all_built_commits`.
        :gh_diff_doc_files => stats[:doc_files],

        # [doc] Number of files which are neither source code nor documentation that changed by the commits that where built.
        :gh_diff_other_files => stats[:other_files],

        # [doc] Number of unique commits on the files touched in the commits (`git_all_built_commits`) that triggered the
        # build from the moment the build was triggered and 3 months back. It is a metric of how active the part of
        # the project is that these commits touched.
        :gh_num_commits_on_files_touched => commits_on_files_touched(owner, repo, build, months_back),

        # [doc] Number of executable production source lines of code, in the entire repository.
        :gh_sloc => sloc,

        # [doc] Test density. Number of lines in test cases per 1000 `gh_sloc`.
        :gh_test_lines_per_kloc => (test_lines(build[:commit]).to_f / sloc.to_f) * 1000,

        # [doc] Test density. Test density. Number of test cases per 1000 `gh_sloc`.
        :gh_test_cases_per_kloc => (num_test_cases(build[:commit]).to_f / sloc.to_f) * 1000,

        # [doc] Test density. Assert density. Number of assertions per 1000 `gh_sloc`.
        :gh_asserts_cases_per_kloc => (num_assertions(build[:commit]).to_f / sloc.to_f) * 1000,

        # [doc] Whether this commit was authored by a core team member. A core team member is someone who has committed
        # code at least once within the 3 months before this commit, either by directly committing it or by merging
        # commits.
        :gh_by_core_team_member => (committers - main_team).empty?,

        # [doc] If the build is a pull request, the total number of words in the pull request title and description.
        :gh_description_complexity => is_pr?(build) ? description_complexity(build) : nil,

        # [doc] Timestamp of the push that triggered the build (GitHub provided).
        :gh_pushed_at => build[:commit_pushed_at],

        # [doc] Timestamp of the push that triggered the build (Travis provided).
        :gh_build_started_at => build[:started_at],

        # [doc] Age of the repository, from the latest commit to its first commit, in days
        :gh_repo_age => confounds[:repo_age],

        # [doc] Number of commits in the repository
        :gh_repo_num_commits => confounds[:repo_num_commits]
    }

  end

  def is_pr?(build)
    build[:pull_req].nil? ? false : true
  end

  # Checks how a merge occured
  def merged_with(owner, repo, build)
    #0. Merged with Github?
    q = <<-QUERY
	  select prh.id as merge_id
    from pull_request_history prh
	  where prh.action = 'merged'
      and prh.pull_request_id = ?
    QUERY
    r = db.fetch(q, build[:pull_req_id]).first
    unless r.nil?
      return :merge_button
    end

    #1. Commits from the pull request appear in the project's main branch
    q = <<-QUERY
	  select c.sha
    from pull_request_commits prc, commits c
	  where prc.commit_id = c.id
      and prc.pull_request_id = ?
    QUERY
    db.fetch(q, build[:pull_req_id]).each do |x|
      unless all_commits.select { |y| x[:sha].start_with? y }.empty?
        return :commits_in_master
      end
    end

    #2. The PR was closed by a commit (using the Fixes: convention).
    # Check whether the commit that closes the PR is in the project's
    # master branch
    unless closed_by_commit[build[:pull_req]].nil?
      sha = closed_by_commit[build[:pull_req]]
      unless all_commits.select { |x| sha.start_with? x }.empty?
        return :fixes_in_commit
      end
    end

    comments = mongo['issue_comments'].find(
        {'owner' => owner, 'repo' => repo, 'issue_id' => build[:pull_req_id].to_i},
        {:fields => {'body' => 1, 'created_at' => 1, '_id' => 0},
         :sort => {'created_at' => :asc}}
    ).map { |x| x }

    comments.reverse.take(3).map { |x| x['body'] }.uniq.each do |last|
      # 3. Last comment contains a commit number
      last.scan(/([0-9a-f]{6,40})/m).each do |x|
        # Commit is identified as merged
        if last.match(/merg(?:ing|ed)/i) or
            last.match(/appl(?:ying|ied)/i) or
            last.match(/pull[?:ing|ed]/i) or
            last.match(/push[?:ing|ed]/i) or
            last.match(/integrat[?:ing|ed]/i)
          return :commit_sha_in_comments
        else
          # Commit appears in master branch
          unless all_commits.select { |y| x[0].start_with? y }.empty?
            return :commit_sha_in_comments
          end
        end
      end

      # 4. Merg[ing|ed] or appl[ing|ed] as last comment of pull request
      if last.match(/merg(?:ing|ed)/i) or
          last.match(/appl(?:ying|ed)/i) or
          last.match(/pull[?:ing|ed]/i) or
          last.match(/push[?:ing|ed]/i) or
          last.match(/integrat[?:ing|ed]/i)
        return :merged_in_comments
      end
    end

    :unknown
  end

  # Number of pull request code review comments in pull request
  def num_pr_comments(build, from, to)
    return nil unless is_pr?(build)

    if from.nil?
      from = build[:pull_req_created_at]
    end

    q = <<-QUERY
    select count(*) as comment_count
    from pull_request_comments prc
    where prc.pull_request_id = ?
    and prc.created_at between timestamp(?) and timestamp(?)
    QUERY
    db.fetch(q, build[:pull_req_id], from, to).first[:comment_count]
  end

  # Number of pull request discussion comments
  def num_issue_comments(build, from, to)

    return nil unless is_pr?(build)
    if from.nil?
      from = build[:pull_req_created_at]
    end

    q = <<-QUERY
    select count(*) as issue_comment_count
    from pull_requests pr, issue_comments ic, issues i
    where ic.issue_id=i.id
    and i.issue_id=pr.pullreq_id
    and pr.base_repo_id = i.repo_id
    and pr.id = ?
    and ic.created_at between timestamp(?) and timestamp(?)
    QUERY
    db.fetch(q, build[:pull_req_id], from, to).first[:issue_comment_count]
  end

  # Number of commit comments on commits between builds in the same branch
  def num_commit_comments(owner, repo, commits)

    commits.map do |sha|
      q = <<-QUERY
      select count(*) as commit_comment_count
      from project_commits pc, projects p, users u, commit_comments cc, commits c
      where pc.commit_id = cc.commit_id
        and p.id = pc.project_id
        and c.id = pc.commit_id
        and p.owner_id = u.id
        and u.login = ?
        and p.name = ?
        and c.sha = ?
      QUERY
      db.fetch(q, owner, repo, sha).first[:commit_comment_count]
    end.reduce(0) { |acc, x| acc + x }
  end

  # People that committed (not through pull requests) up to months_back
  # from the time the build was started.
  def committer_team(owner, repo, build, months_back)
    q = <<-QUERY
    select distinct(u1.login)
    from commits c, project_commits pc, users u, projects p, users u1
    where
      pc.project_id = p.id
      and not exists (select * from pull_request_commits where commit_id = c.id)
      and pc.commit_id = c.id
      and u.login = ?
      and p.name = ?
      and c.author_id = u1.id
      and p.owner_id = u.id
      and u1.fake is false
      and c.created_at between DATE_SUB(timestamp(?), INTERVAL #{months_back} MONTH) and timestamp(?);
    QUERY
    db.fetch(q, owner, repo, build[:started_at], build[:started_at]).all
  end

  # People that merged (not necessarily through pull requests) up to months_back
  # from the time the built PR was created.
  def merger_team(owner, repo, build, months_back)

    recently_merged = builds.select do |b|
      not b[:pull_req].nil?
    end.find_all do |b|
      close_reason[b[:pull_req]] != :unknown and
          b[:started_at].to_i > (build[:started_at].to_i - months_back * 30 * 24 * 3600)
    end.map do |b|
      b[:pull_req]
    end

    q = <<-QUERY
    select u1.login as merger
    from users u, projects p, pull_requests pr, pull_request_history prh, users u1
    where prh.action = 'closed'
      and prh.actor_id = u1.id
      and prh.pull_request_id = pr.id
      and pr.base_repo_id = p.id
      and p.owner_id = u.id
      and u.login = ?
      and p.name = ?
      and pr.pullreq_id = ?
    QUERY

    recently_merged.map do |pr_id|
      a = db.fetch(q, owner, repo, pr_id).first
      if not a.nil? then
        a[:merger]
      else
        nil
      end
    end.select { |x| not x.nil? }.uniq

  end

  # Number of integrators active during x months prior to pull request
  # creation.
  def main_team(owner, repo, build, months_back)
    (committer_team(owner, repo, build, months_back) + merger_team(owner, repo, build, months_back)).uniq
  end

  # Total number of words in the pull request title and description
  def description_complexity(build)
    pull_req = pull_req_entry(build[:pull_req_id])
    begin
      (pull_req['title'] + ' ' + pull_req['body']).gsub(/[\n\r]\s+/, ' ').split(/\s+/).size
    rescue
      nil
    end
  end

  # Total number of pull requests/branches still open in each project at pull
  # request creation time.
  def workload(owner, repo, build)
    q = <<-QUERY
    select count(distinct(prh.pull_request_id)) as num_open
    from pull_request_history prh, pull_requests pr, pull_request_history prh3
    where prh.created_at <  prh3.created_at
    and prh.action = 'opened'
    and pr.id = prh.pull_request_id
    and prh3.pull_request_id = ?
    and (exists (select * from pull_request_history prh1
                where prh1.action = 'closed'
          and prh1.pull_request_id = prh.pull_request_id
          and prh1.created_at > prh3.created_at)
      or not exists (select * from pull_request_history prh1
               where prh1.action = 'closed'
               and prh1.pull_request_id = prh.pull_request_id)
    )
    and pr.base_repo_id = (select pr3.base_repo_id from pull_requests pr3 where pr3.id = ?)
    QUERY
    db.fetch(q, owner, repo, build[:started_at]).first[:num_open]
  end

  # Various statistics for the build. Returned as Hash with the following
  # keys: :lines_added, :lines_deleted, :files_added, :files_removed,
  # :files_modified, :files_touched, :src_files, :doc_files, :other_files.
  def calc_build_stats(owner, repo, commits)

    raw_commits = commit_entries(owner, repo, commits)
    result = Hash.new(0)

    def file_count(commits, status)
      commits.map do |c|
        c['files'].reduce(Array.new) do |acc, y|
          if y['status'] == status then
            acc << y['filename']
          else
            acc
          end
        end
      end.flatten.uniq.size
    end

    def files_touched(commits)
      commits.map do |c|
        c['files'].map do |y|
          y['filename']
        end
      end.flatten.uniq.size
    end

    def file_type(f)
      lang = Linguist::Language.find_by_filename(f)
      if lang.empty? then
        :data
      else
        lang[0].type
      end
    end

    def file_type_count(commits, type)
      commits.map do |c|
        c['files'].reduce(Array.new) do |acc, y|
          if file_type(y['filename']) == type then
            acc << y['filename']
          else
            acc
          end
        end
      end.flatten.uniq.size
    end

    def lines(commit, type, action)
      commit['files'].select do |x|
        next unless file_type(x['filename']) == :programming

        case type
          when :test
            true if test_file_filter.call(x['filename'])
          when :src
            true unless test_file_filter.call(x['filename'])
          else
            false
        end
      end.reduce(0) do |acc, y|
        diff_start = case action
                       when :added
                         "+"
                       when :deleted
                         "-"
                     end

        acc += unless y['patch'].nil?
                 y['patch'].lines.select { |x| x.start_with?(diff_start) }.size
               else
                 0
               end
        acc
      end
    end

    raw_commits.each do |x|
      next if x.nil?
      result[:lines_added] += lines(x, :src, :added)
      result[:lines_deleted] += lines(x, :src, :deleted)
      result[:test_lines_added] += lines(x, :test, :added)
      result[:test_lines_deleted] += lines(x, :test, :deleted)
    end

    result[:files_added] += file_count(raw_commits, "added")
    result[:files_removed] += file_count(raw_commits, "removed")
    result[:files_modified] += file_count(raw_commits, "modified")
    result[:files_touched] += files_touched(raw_commits)

    result[:src_files] += file_type_count(raw_commits, :programming)
    result[:doc_files] += file_type_count(raw_commits, :markup)
    result[:other_files] += file_type_count(raw_commits, :data)

    result
  end


  def test_diff_stats(from_sha, to_sha)

    from = git.lookup(from_sha)
    to = git.lookup(to_sha)

    diff = to.diff(from)

    added = deleted = 0
    state = :none
    diff.patch.lines.each do |line|
      if line.start_with? '---'
        file_path = line.strip.split(/---/)[1]
        next if file_path.nil?

        file_path = file_path[2..-1]
        next if file_path.nil?

        if test_file_filter.call(file_path)
          state = :in_test
        end
      end

      if line.start_with? '- ' and state == :in_test
        if test_case_filter.call(line)
          deleted += 1
        end
      end

      if line.start_with? '+ ' and state == :in_test
        if test_case_filter.call(line)
          added += 1
        end
      end

      if line.start_with? 'diff --'
        state = :none
      end
    end

    {:tests_added => added, :tests_deleted => deleted}
  end

  # Return a hash of file names and commits on those files in the
  # period between build start and months_back.
  def commits_on_build_files(owner, repo, build, months_back)

    oldest = Time.at(build[:started_at].to_i - 3600 * 24 * 30 * months_back)
    commits = commit_entries(owner, repo, build[:commits])

    commits_per_file = commits.flat_map { |c|
      c['files'].map { |f|
        [c['sha'], f['filename']]
      }
    }.group_by { |c|
      c[1]
    }

    commits_per_file.keys.reduce({}) do |acc, filename|
      commits_in_pr = commits_per_file[filename].map { |x| x[0] }

      walker = Rugged::Walker.new(git)
      walker.sorting(Rugged::SORT_DATE)
      walker.push(build[:commit])

      commit_list = walker.take_while do |c|
        c.time > oldest
      end.reduce([]) do |acc1, c|
        if c.diff(paths: [filename.to_s]).size > 0 and
            not commits_in_pr.include? c.oid
          acc1 << c.oid
        end
        acc1
      end
      acc.merge({filename => commit_list})
    end
  end

  # Number of unique commits on the files changed by the build commits
  # between the time the build was created and `months_back`
  def commits_on_files_touched(owner, repo, build, months_back)
    commits_on_build_files(owner, repo, build, months_back).reduce([]) do |acc, commit_list|
      acc + commit_list[1]
    end.flatten.uniq.size
  end

  def pull_req_entry(pr_id)
    q = <<-QUERY
    select u.login as user, p.name as name, pr.pullreq_id as pullreq_id
    from pull_requests pr, projects p, users u
    where pr.id = ?
    and pr.base_repo_id = p.id
    and u.id = p.owner_id
    QUERY
    pullreq = db.fetch(q, pr_id).all[0]

    mongo['pull_requests'].find_one({:owner => pullreq[:user],
                                     :repo => pullreq[:name],
                                     :number => pullreq[:pullreq_id]})
  end

  def github_login(email)
    q = <<-QUERY
    select u.login as login
    from users u
    where u.email = ?
    and u.fake is false
    QUERY
    l = db.fetch(q, email).first
    l.nil? ? nil : l[:login]
  end

  # JSON objects for the commits included in the pull request
  def commit_entries(owner, repo, shas)
    shas.reduce([]) { |acc, x|
      a = mongo['commits'].find_one({:sha => x})

      if a.nil?
        a = github_commit(owner, repo, x)
      end

      acc << a unless a.nil? or a.empty?
      acc
    }.select { |c| c['parents'] }
  end

  # Recursively get information from all files given a rugged Git tree
  def lslr(tree, path = '')
    all_files = []
    for f in tree.map { |x| x }
      f[:path] = path + '/' + f[:name]
      if f[:type] == :tree
        begin
          all_files << lslr(git.lookup(f[:oid]), f[:path])
        rescue StandardError => e
          log e
          all_files
        end
      else
        all_files << f
      end
    end
    all_files.flatten
  end


  # List of files in a project checkout. Filter is an optional binary function
  # that takes a file entry and decides whether to include it in the result.
  def files_at_commit(sha, filter = lambda { true })

    begin
      files = lslr(git.lookup(sha).tree)
      if files.size <= 0
        log "No files for commit #{sha}"
      end
      files.select { |x| filter.call(x) }
    rescue StandardError => e
      log "Cannot find commit #{sha} in base repo"
      []
    end
  end

  # Clone or update, if already cloned, a git repository
  def clone(user, repo, update = false)

    def spawn(cmd)
      proc = IO.popen(cmd, 'r')

      proc_out = Thread.new {
        while !proc.eof
          log "GIT: #{proc.gets}"
        end
      }

      proc_out.join
    end

    checkout_dir = File.join('repos', user, repo)

    begin
      repo = Rugged::Repository.new(checkout_dir)
      if update
        spawn("cd #{checkout_dir} && git pull")
      end
      repo
    rescue
      spawn("git clone git://github.com/#{user}/#{repo}.git #{checkout_dir}")
      Rugged::Repository.new(checkout_dir)
    end
  end

  def stripped(f)
    @stripped ||= Hash.new
    unless @stripped.has_key? f
      semaphore.synchronize do
        unless @stripped.has_key? f
          @stripped[f] = strip_comments(git.read(f[:oid]).data)
        end
      end
    end
    @stripped[f]
  end

  def count_lines(files, include_filter = lambda { |x| true })
    files.map { |f|
      stripped(f).lines.select { |x|
        not x.strip.empty?
      }.select { |x|
        include_filter.call(x)
      }.size
    }.reduce(0) { |acc, x| acc + x }
  end

  def src_files(sha)
    files_at_commit(sha, src_file_filter)
  end

  def src_lines(sha)
    count_lines(src_files(sha))
  end

  def test_files(sha)
    files_at_commit(sha, test_file_filter)
  end

  def test_lines(sha)
    count_lines(test_files(sha))
  end

  def num_test_cases(sha)
    count_lines(test_files(sha), test_case_filter)
  end

  def num_assertions(sha)
    count_lines(test_files(sha), assertion_filter)
  end

  # Return a f: filename -> Boolean, that determines whether a
  # filename is a test file
  def test_file_filter
    raise Exception.new("Unimplemented")
  end

  # Return a f: filename -> Boolean, that determines whether a
  # filename is a src file
  def src_file_filter
    raise Exception.new("Unimplemented")
  end

  # Return a f: buff -> Boolean, that determines whether a
  # line represents a test case declaration
  def test_case_filter
    raise Exception.new("Unimplemented")
  end

  # Return a f: buff -> Boolean, that determines whether a
  # line represents an assertion
  def assertion_filter
    raise Exception.new("Unimplemented")
  end

  def strip_comments(buff)
    raise Exception.new("Unimplemented")
  end

end

BuildDataExtraction.run
#vim: set filetype=ruby expandtab tabstop=2 shiftwidth=2 autoindent smartindent:
