require_relative 'config.rb'
require 'pg'
require 'httparty'
require 'nokogiri'
require 'pry'

def connect_to_db
  db_parts = ENV['DATABASE_URL'].split(/\/|:|@/)
  username = db_parts[3]
  password = db_parts[4]
  host = db_parts[5]
  db = db_parts[7]
  pry
  @conn = ENV['DATABASE_URL'] === 'dom_jobs' ? PG::Connection.open(:dbname => ENV['DATABASE_URL']) : PGconn.open(:host =>  host, :dbname => db, :user=> username, :password=> password)
end


def check_for_job_postings
  page = HTTParty.get 'https://www.cmec.ca/11/About/index.html'
  body = page.body
  noko_body = Nokogiri::HTML(body)
  jobs = []

  noko_body.css('a').each do |a|
    if a.attribute('href') && a.attribute('href').content.include?('/docs/jobs')
      jobs << a
    end
  end

  jobs

end


def filter_old_jobs(jobs)

  new_jobs = jobs

  # ['JOB TITLE','JOB URL']

  new_jobs = new_jobs.select do |job|

    href = job.attribute('href').content
    unique = (@conn.exec "SELECT * FROM cmec WHERE href = '#{href}'").values == []

    if unique
      save_job(href)
    end

    unique

  end

  new_jobs
end


def save_job(href)
  @conn.exec "INSERT INTO cmec VALUES ('#{href}','#{Time.now}') "
end


def send_notification(jobs)

  num_of_jobs = jobs.length

  jobs_text = num_of_jobs == 1 ? 'Posting' : 'Postings'

  body_text = jobs.map do |job|
                "<a href=\"https://www.cmec.ca#{job.attribute('href').content}\">#{job.content}</a>"
              end

  sent = HTTParty.post( 
      "https://api:key-9a8c049041e1851e5d6bf84d8e584846@api.mailgun.net/v3/#{ENV["MAILGUN_DOMAIN"]}/messages",
      :body => {
        :from => "CMEC Notifier <mailgun@#{ENV["MAILGUN_DOMAIN"]}>",
        # :to => "dominique.fascinato@gmail.com",
        :to => "samkessaram@gmail.com",
        :subject => "#{num_of_jobs} New Job #{jobs_text} at CMEC",
        :html => "Hi Dom!<br>Something got posted on the CMEC site:<br><br>" + body_text.join('<br>') + "<br><br><hr>Love,<br>Sam" 
      })
end

def run_script
  connect_to_db
  jobs = check_for_job_postings
  p jobs
  jobs = filter_old_jobs(jobs)

  if !jobs.empty?
    # send_notification(jobs)
  end
end

run_script
