require 'csv'
require 'travis'
require 'parallel'
require 'json'
require 'net/http'
require 'open-uri'

load 'lib/csv_helper.rb'

jobs = CSV.read(ARGV[0])

i = 1
length = jobs.length
header = jobs.shift
header.push 'tr_build_id'

def get_build_id(job_id, wait_in_s)
  # used to be a simple Travis::Job.find(job_id).build_id

  url = "https://api.travis-ci.org/jobs/#{job_id}"
  begin
    resp = open(url,
                'Content-Type' => 'application/json',
                'Accept' => 'application/vnd.travis-ci.2+json')
    json_resp = JSON.parse(resp.read)
    return json_resp['job']['build_id']
  rescue Exception => e
    STDERR.puts "Exception at #{job_id}"
    if e.io.status[0] == "429"
      STDERR.puts "Encountered API restriction: sleeping for #{wait_in_s}"
      sleep wait_in_s
      return get_build_id job_id, wait_in_s*2
    else
      raise e
    end

  end

end

jobs = Parallel.map(jobs, in_threads: 50) do |job|
  begin
    job_id = job[2]
    build_id = get_build_id job_id, 2
    sleep 0.01
    puts "#{i}/#{length}"
    job.push build_id
  rescue Exception => e
    STDERR.puts "Exception at #{i}"
    STDERR.puts e
  rescue Error => e
    STDERR.puts "Error at #{i}"
    STDERR.puts e
  ensure
    i += 1
  end
end

jobs = jobs.select { |a| !a.nil? }

CSV.open("n_#{ARGV[0]}", 'w',
         :write_headers => true,
         :headers => header
) do |hdr|
  jobs.each do |job|
    hdr << job
  end
end
