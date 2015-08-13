#!/usr/bin/env ruby
#
# (c) 2012 -- 2015 Georgios Gousios <gousiosg@gmail.com>
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

require 'java'
require 'ruby'
require 'scala'
require 'python'

class BuildDataExtraction

  include Mongo
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
    command = self
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
      unless (file_exists?("config.yaml"))
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

  def threads
    @threads ||= 2
    @threads
  end

  # Read a source file from the repo and strip its comments
  # The argument f is the result of Grit.lstree
  # Memoizes result per f
  def semaphore
    @semaphore ||= Mutex.new
    @semaphore
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

  def builds(owner, repo)
    f = File.join("build_logs", "#{owner}@#{repo}", "repo-data-travis.json")
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
    STDERR.puts("Requesting #{url} (#{@remaining} remaining)")

    contents = nil
    begin
      r = open(url, 'User-Agent' => 'ghtorrent', :http_basic_authentication => [@token, 'x-oauth-basic'])
      @remaining = r.meta['x-ratelimit-remaining'].to_i
      @reset = r.meta['x-ratelimit-reset'].to_i
      contents = r.read
      JSON.parse contents
    rescue OpenURI::HTTPError => e
      @remaining = e.io.meta['x-ratelimit-remaining'].to_i
      @reset = e.io.meta['x-ratelimit-reset'].to_i
      STDERR.puts "Cannot get #{url}. Error #{e.io.status[0].to_i}"
      {}
    rescue StandardError => e
      STDERR.puts "Cannot get #{url}. General error: #{e.message}"
      {}
    ensure
      File.open(commit_json, 'w') do |f|
        f.write contents unless r.nil?
        f.write '' if r.nil?
      end

      if 5000 - @remaining >= @req_limit
        to_sleep = @reset - Time.now.to_i + 2
        STDERR.puts "Request limit reached, sleeping for #{to_sleep} secs"
        sleep(to_sleep)
      end
    end
  end

  # Main command code
  def go
    interrupted = false

    trap('INT') {
      STDERR.puts "#{File.basename($0)}(#{Process.pid}): Received SIGINT, exiting"
      interrupted = true
    }

    owner = ARGV[0]
    repo = ARGV[1]
    @token = ARGV[2]
    @req_limit = 4990

    # Init the semaphore
    semaphore

    user_entry = db[:users].first(:login => owner)

    if user_entry.nil?
      Trollop::die "Cannot find user #{owner}"
    end

    repo_entry = db.from(:projects, :users).\
                  where(:users__id => :projects__owner_id).\
                  where(:users__login => owner).\
                  where(:projects__name => repo).select(:projects__id,
                                                        :projects__language).\
                  first

    if repo_entry.nil?
      Trollop::die "Cannot find repository #{owner}/#{repo}"
    end

    language = repo_entry[:language]

    case language
      when /ruby/i then
        self.extend(RubyData)
      when /java/i then
        self.extend(JavaData)
      when /scala/i then
        self.extend(ScalaData)
      when /javascript/i then
        self.extend(JavascriptData)
      when /c/i then
        self.extend(CData)
      when /python/i then
        self.extend(PythonData)
    end

    @builds = builds(owner, repo)
    if @builds.empty?
      STDERR.puts "No builds for #{owner}/#{repo}"
      return
    else
      STDERR.puts "#{@builds.size} builds for #{owner}/#{repo}"
    end

    @builds = @builds.reduce([]) do |acc, b|
      unless b[:started_at].nil?
        b[:started_at] = Time.parse(b[:started_at])
        acc << b
      else
        acc
      end
    end
    STDERR.puts "#{@builds.size} builds after filtering out empty build dates"

    STDERR.puts "\nCalculating GHTorrent PR ids"
    @builds = @builds.reduce([]) do |acc, build|
      if build[:pull_req].nil?
        acc << build
      else
        q = <<-QUERY
        select pr.id as id
        from pull_requests pr, users u, projects p
        where u.login = ?
        and p.name = ?
        and pr.pullreq_id = ?
        and p.owner_id = u.id
        and pr.base_repo_id = p.id
        QUERY
        #STDERR.write "\r #{build[:pull_req]}"
        r = db.fetch(q, owner, repo, build[:pull_req].to_i).first
        unless r.nil?
          build[:pull_req_id] = r[:id]
          acc << build
        else
          # Not yet processed by GHTorrent, don't process further
          acc
        end
      end
    end

    STDERR.puts "After resolving GHT pullreqs: #{@builds.size} builds for #{owner}/#{repo}"
    # Update the repo
    clone(owner, repo, true)

    STDERR.puts "Retrieving all commits for the project"
    walker = Rugged::Walker.new(git)
    walker.sorting(Rugged::SORT_DATE)
    walker.push(git.head.target)
    @all_commits = walker.map do |commit|
      commit.oid[0..10]
    end

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

    STDERR.puts 'Calculating PRs closed by commits'
    @closed_by_commit ={}
    commits_in_prs = db.fetch(q, repo_entry[:id]).all
    @closed_by_commit =
        Parallel.map(commits_in_prs, :in_threads => threads) do |x|
          sha = x[:sha]
          result = {}
          mongo['commits'].find({:sha => sha},
                                {:fields => {'commit.message' => 1, '_id' => 0}}).map do |x|
            #STDERR.write "\r #{sha}"
            comment = x['commit']['message']

            comment.match(fixre) do |m|
              (1..(m.size - 1)).map do |y|
                result[m[y].to_i] = sha
              end
            end
          end
          result
        end.select{|x| !x.empty?}.reduce({}){|acc, x| acc.merge(x)}

    STDERR.puts "\nCalculating PR close reasons"
    @close_reason = {}
    @close_reason = @builds.select{|b| not b[:pull_req].nil?}.reduce({}) do |acc, build|
      acc[build[:pull_req]] = merged_with(owner, repo, build)
      acc
    end

    STDERR.puts "Retrieving actual built commits for pull requests"
    # When building pull requests, travis creates artifical commits by merging
    # the commit to be built with the branch to be built. By default, it reports
    # those commits instead of the latest built PR commit.
    # The algorithm below attempts to resolve the actual PR commit. If the
    # PR commit (or the PR) cannot be retrieved, the build is skipped from further processing.
    @builds = Parallel.map(@builds, :in_threads => threads) do |build|
      unless build[:pull_req].nil?
        c = github_commit(owner, repo, build[:commit])
        unless c.empty?
          shas = c['commit']['message'].match(/Merge (.*) into (.*)/i).captures
          if shas.size == 2
            STDERR.puts "Replacing Travis commit #{build[:commit]} with actual #{shas[0]}"
            build[:commit] = shas[0]
          end
          build
        else
          nil
        end
      else
        build
      end
    end.select{ |x| !x.nil? }

    STDERR.puts "After resolving PR commits: #{@builds.size} builds for #{owner}/#{repo}"

    STDERR.puts "Calculating build diff information"
    @build_stats = @builds.map do |build|

      begin
        build_commit = git.lookup(build[:commit])
      rescue
        next
      end
      next if build_commit.nil?

      walker = Rugged::Walker.new(git)
      walker.sorting(Rugged::SORT_TOPO)
      walker.push(build_commit)

      # Get all previous commits up to a branch point
      prev_commits = []
      walker.each do |commit|
        prev_commits << commit
        break if commit.parents.size > 1
      end

      # Remove current commit from list of previous commits
      unless prev_commits.nil?
        prev_commits = prev_commits.select{|c| c.oid != build_commit.oid}
      end

      # TODO: What happens if the build commit is a merge commit?
      if prev_commits.nil? or prev_commits.empty?
        STDERR.puts "Build #{build[:build_id]} is on a merge commit #{build[:commit]}"
        next
      end

      # Find the first commit that was built prior to the commit that triggered
      # the current build
      prev_build_commit_idx = prev_commits.find_index do |c|
        not @builds.find do |b|
          b[:build_id] < build[:build_id] and c.oid.start_with? b[:commit]
        end.nil?
      end

      if prev_build_commit_idx.nil?
        STDERR.puts "No previous build on the same branch for build #{build[:build_id]}"
        next
      end
      prev_build_commit = prev_commits[prev_build_commit_idx]

      # Get diff between the current build commit and previous one
      diff = build_commit.diff(prev_build_commit)

      {
          :build_id      => build[:build_id],
          :prev_build    => @builds.find{|b| b[:build_id] < build[:build_id] and prev_build_commit.oid.start_with? b[:commit]},
          :commits       => prev_commits[0..prev_build_commit_idx].map{|c| c.oid},
          :authors       => prev_commits[0..prev_build_commit_idx].map{|c| c.author[:email]}.uniq,
          :files         => diff.deltas.map { |d| d.old_file }.map { |f| f[:path] },
          :lines_added   => diff.stat[1],
          :lines_deleted => diff.stat[2]
      }
    end.select { |x| !x.nil? }

    @builds = @builds.select{|b| !@build_stats.find{|bd| bd[:build_id] == b[:build_id]}.nil?}
    STDERR.puts "After calculating build stats: #{@builds.size} builds for #{owner}/#{repo}"

    results = Parallel.map(@builds, :in_threads => threads) do |build|
      begin
        r = process_build(build, owner, repo, language.downcase)
        if interrupted
          return
        end
        STDERR.puts r
        r
      rescue StandardError => e
        STDERR.puts "Error processing build #{build[:build_id]}: #{e.message}"
        STDERR.puts e.backtrace
      end
    end.select { |x| !x.nil? }

    puts results.first.keys.map { |x| x.to_s }.join(',')
    results.sort { |a, b| b[:build_id]<=>a[:build_id] }.each { |x| puts x.values.join(',') }

  end

  # Process a single build
  def process_build(build, owner, repo, lang)

    # Count number of src/comment lines
    sloc = src_lines(build[:commit])

    if sloc == 0 then
      raise Exception.new("Bad src lines: 0, build: #{build[:build_id]}")
    end

    months_back = 3

    # Create line for build
    bs = @build_stats.find{|b| b[:build_id] == build[:build_id]}
    stats = build_stats(owner, repo, bs[:commits])
    is_pr = if build[:pull_req].nil? then false else true end
    pr_id = unless build[:pull_req].nil? then build[:pull_req] end
    committers = bs[:authors].map{|a| github_login(a)}.select{|x| not x.nil?}
    main_team = main_team(owner, repo, build, months_back)
    test_diff = test_diff_stats(bs[:prev_build][:commit], build[:commit])

    {
        :build_id                 => build[:build_id],
        :project_name             => "#{owner}/#{repo}",
        :is_pr                    => is_pr,
        :pullreq_id               => pr_id,
        :merged_with              => @close_reason[pr_id],
        :lang                     => lang,
        :branch                   => build[:branch],
        :first_commit_created_at  => build[:started_at].to_i,
        :team_size                => main_team.size,
        :commits                  => bs[:commits].join('#'),
        :num_commits              => bs[:commits].size,
        :num_issue_comments       => num_issue_comments(build, bs[:prev_build][:started_at], build[:started_at]),
        :num_commit_comments      => num_commit_comments(owner, repo, bs[:prev_build][:started_at], build[:started_at]),
        :num_pr_comments          => num_pr_comments(build, bs[:prev_build][:started_at], build[:started_at]),
        :committers               => bs[:authors].join('#'),

        :src_churn                => stats[:lines_added] + stats[:lines_deleted],
        :test_churn               => stats[:test_lines_added] + stats[:test_lines_deleted],

        :files_added              => stats[:files_added],
        :files_deleted            => stats[:files_removed],
        :files_modified           => stats[:files_modified],

        :tests_added              => test_diff[:tests_added], # e.g. for Java, @Test annotations
        :tests_deleted            => test_diff[:tests_deleted],
        # :tests_modified           => 0,

        :src_files                => stats[:src_files],
        :doc_files                => stats[:doc_files],
        :other_files              => stats[:other_files],

        :commits_on_files_touched => commits_on_files_touched(owner, repo, build, months_back),

        :sloc                     => sloc,
        :test_lines_per_kloc      => (test_lines(build[:commit]).to_f / sloc.to_f) * 1000,
        :test_cases_per_kloc      => (num_test_cases(build[:commit]).to_f / sloc.to_f) * 1000,
        :asserts_per_kloc         => (num_assertions(build[:commit]).to_f / sloc.to_f) * 1000,

        :main_team_member         => (committers - main_team).empty?,
        :description_complexity   => if is_pr then description_complexity(build) else nil end
        #:workload                => workload(owner, repo, build)
        # :ci_latency             => ci_latency(build) # TODO time between push even for triggering commit and build time
    }
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
      unless @all_commits.select { |y| x[:sha].start_with? y }.empty?
        return :commits_in_master
      end
    end

    #2. The PR was closed by a commit (using the Fixes: convention).
    # Check whether the commit that closes the PR is in the project's
    # master branch
    unless @closed_by_commit[build[:pull_req]].nil?
      sha = @closed_by_commit[build[:pull_req]]
      unless @all_commits.select { |x| sha.start_with? x }.empty?
        return :fixes_in_commit
      end
    end

    comments = mongo['issue_comments'].find(
        {'owner' => owner, 'repo' => repo, 'issue_id' => build[:pull_req_id].to_i},
        {:fields => {'body' => 1, 'created_at' => 1, '_id' => 0},
         :sort => {'created_at' => :asc}}
    ).map{|x| x}

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
          unless @all_commits.select { |y| x[0].start_with? y }.empty?
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

  # Number of commit comments on commits composing between builds in the same branch
  def num_commit_comments(onwer, repo, from, to)
    q = <<-QUERY
    select count(*) as commit_comment_count
    from project_commits pc, projects p, users u, commit_comments cc
    where pc.commit_id = cc.commit_id
      and p.id = pc.project_id
      and p.owner_id = u.id
      and u.login = ?
      and p.name = ?
      and cc.created_at between timestamp(?) and timestamp(?)
    QUERY
    db.fetch(q, onwer, repo, from, to).first[:commit_comment_count]
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
      and u1.fake is false
      and c.created_at between DATE_SUB(timestamp(?), INTERVAL #{months_back} MONTH) and timestamp(?);
    QUERY
    db.fetch(q, owner, repo, build[:started_at], build[:started_at]).all
  end

  # People that merged (not necessarily through pull requests) up to months_back
  # from the time the built PR was created.
  def merger_team(owner, repo, build, months_back)

    recently_merged = @builds.select do |b|
      not b[:pull_req].nil?
    end.find_all do |b|
      @close_reason[b[:pull_req]] != :unknown and
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
      if not a.nil? then a[:merger] else nil end
    end.select {|x| not x.nil?}.uniq

  end

  # Number of integrators active during x months prior to pull request
  # creation.
  def main_team(owner, repo, build, months_back)
    (committer_team(owner, repo, build, months_back) + merger_team(owner, repo, build, months_back)).uniq
  end

  # Time between PR arrival and last CI run
  def ci_latency(pr)
    last_run = travis.find_all { |b| b[:pull_req] == pr[:github_id] }.sort_by { |x| Time.parse(x[:finished_at]).to_i }[-1]
    unless last_run.nil?
      Time.parse(last_run[:finished_at]) - pr[:created_at]
    else
      -1
    end
  end

  # Total number of words in the pull request title and description
  def description_complexity(build)
    pull_req = pull_req_entry(build[:pull_req_id])
    (pull_req['title'] + ' ' + pull_req['body']).gsub(/[\n\r]\s+/, ' ').split(/\s+/).size
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
  def build_stats(owner, repo, commits)

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
      result[:lines_added]        += lines(x, :src, :added)
      result[:lines_deleted]      += lines(x, :src, :deleted)
      result[:test_lines_added]   += lines(x, :test, :added)
      result[:test_lines_deleted] += lines(x, :test, :deleted)
    end

    result[:files_added]    += file_count(raw_commits, "added")
    result[:files_removed]  += file_count(raw_commits, "removed")
    result[:files_modified] += file_count(raw_commits, "modified")
    result[:files_touched]  += files_touched(raw_commits)

    result[:src_files]   += file_type_count(raw_commits, :programming)
    result[:doc_files]   += file_type_count(raw_commits, :markup)
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
  # period between pull request open and months_back. The returned
  # results do not include the commits comming from the PR.
  def commits_on_build_files(owner, repo, build, months_back)

    oldest = Time.at(build[:started_at].to_i - 3600 * 24 * 30 * months_back)
    commits = commit_entries(owner, repo, @build_stats.find{|b| b[:build_id] == build[:build_id]}[:commits])

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
    unless l.nil? then l[:login] else nil end
  end

  # JSON objects for the commits included in the pull request
  def commit_entries(owner, repo ,shas)
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
          STDERR.puts e
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
        STDERR.puts "No files for commit #{sha}"
      end
      files.select { |x| filter.call(x) }
    rescue StandardError => e
      STDERR.puts "Cannot find commit #{sha} in base repo"
      []
    end
  end

  # Clone or update, if already cloned, a git repository
  def clone(user, repo, update = false)

    def spawn(cmd)
      proc = IO.popen(cmd, 'r')

      proc_out = Thread.new {
        while !proc.eof
          STDERR.puts "#{proc.gets}"
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
