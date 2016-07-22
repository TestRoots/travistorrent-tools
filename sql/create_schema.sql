CREATE TABLE `travistorrent-5-3-2016` (
  `row` varchar(40) DEFAULT NULL, -- Added myself
  `git_commit` text,
  `gh_project_name` text,
  `gh_is_pr` BIT DEFAULT NULL,
  `git_merged_with` text,
  `gh_lang` varchar(40) DEFAULT NULL,
  `git_branch` text,
  `gh_first_commit_created_at` datetime DEFAULT NULL,
  `gh_team_size` int(11) DEFAULT NULL,
  `git_commits` text,
  `git_num_commits` int(11) DEFAULT NULL,
  `gh_num_issue_comments` int(11) DEFAULT NULL,
  `gh_num_commit_comments` int(11) DEFAULT NULL,
  `gh_num_pr_comments` int(11) DEFAULT NULL,
  `gh_src_churn` int(11) DEFAULT NULL, -- Added myself
  `gh_test_churn` int(11) DEFAULT NULL, -- Added myself
  `gh_files_added` int(11) DEFAULT NULL, -- Added myself
  `gh_files_deleted` int(11) DEFAULT NULL, -- Added myself
  `gh_files_modified` int(11) DEFAULT NULL, -- Added myself
  `gh_tests_added` int(11) DEFAULT NULL, -- Added myself
  `gh_tests_deleted` int(11) DEFAULT NULL, -- Added myself
  `gh_src_files` int(11) DEFAULT NULL, -- Added myself
  `gh_doc_files` int(11) DEFAULT NULL, -- Added myself
  `gh_other_files` int(11) DEFAULT NULL, -- Added myself
  `gh_commits_on_files_touched` int(11) DEFAULT NULL, -- Added myself
  `gh_sloc` int(11) DEFAULT NULL, -- Added myself
  `gh_test_lines_per_kloc` int(11) DEFAULT NULL, -- Added myself
  `gh_test_cases_per_kloc` int(11) DEFAULT NULL, -- Added myself
  `gh_asserts_cases_per_kloc` int(11) DEFAULT NULL, -- Added myself
  `gh_by_core_team_member` text, -- Added myself (is this a good type?)
  `gh_description_complexity` text, -- Added myself (likely incorrect type)
  `tr_build_id` text,
  `gh_pull_req_num` int(11) DEFAULT NULL,
  `tr_status` varchar(40) DEFAULT NULL,
  `tr_duration` int(11) DEFAULT NULL,
  `tr_started_at` datetime DEFAULT NULL,
  `tr_jobs` text,
  `tr_build_number` int(11) DEFAULT NULL,
  `tr_job_id` int(11) DEFAULT NULL,
  `tr_lan` varchar(40) DEFAULT NULL,
  `tr_setup_time` int(11) DEFAULT NULL,
  `tr_analyzer` varchar(40) DEFAULT NULL,
  `tr_frameworks` varchar(40) DEFAULT NULL,
  `tr_tests_ok` int(11) DEFAULT NULL,
  `tr_tests_fail` int(11) DEFAULT NULL,
  `tr_tests_run` int(11) DEFAULT NULL,
  `tr_tests_skipped` int(11) DEFAULT NULL,
  `tr_failed_tests` text,
  `tr_testduration` int(11) DEFAULT NULL,
  `tr_purebuildduration` int(11) DEFAULT NULL,
  `tr_tests_ran` varchar(10) DEFAULT NULL,
  `tr_tests_failed` varchar(10) DEFAULT NULL,
  `git_num_committers` int(11) DEFAULT NULL,
  `tr_num_jobs` int(11) DEFAULT NULL,
  `tr_prev_build` text,
  `tr_ci_latency` int(11) DEFAULT NULL -- Modified, was "num_commiters"
);
