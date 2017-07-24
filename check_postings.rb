require_relative 'config.rb'
require 'csv'
require 'restclient'
require 'nokogiri'

def check_for_job_postings
  page = RestClient.get 'https://www.cmec.ca/11/About/index.html'
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
  old_jobs = CSV.read('saved_jobs.csv',:encoding => 'ISO-8859-1')

  # ['JOB TITLE','JOB URL']

  new_jobs = new_jobs.select do |job|
              duplicate = old_jobs.detect do |old_job|
                            old_job[1] == job.attribute('href').content
                          end

              duplicate = !!duplicate
              !duplicate
            end

  new_jobs
end


def save_jobs(jobs)

  jobs.each do |job|
    CSV.open('saved_jobs.csv', 'ab') do |csv|
      csv << [job.content,job.attribute('href').content]
    end
  end
end


def send_notification(jobs)

  num_of_jobs = jobs.length

  jobs_text = num_of_jobs == 1 ? 'Posting' : 'Postings'

  body_text = jobs.map do |job|
                "<a href=\"https://www.cmec.ca#{job.attribute('href').content}\">#{job.content}</a>"
              end

  p "https://api:key-9a8c049041e1851e5d6bf84d8e584846"\
  "@api.mailgun.net/v3/#{ENV["MAILGUN_DOMAIN"]}/messages"

  sent = RestClient.post "https://api:key-9a8c049041e1851e5d6bf84d8e584846"\
  "@api.mailgun.net/v3/#{ENV["MAILGUN_DOMAIN"]}/messages",
  :from => "CMEC Notifier <mailgun@#{ENV["MAILGUN_DOMAIN"]}>",
  :to => "dominique.fascinato@gmail.com",
  :cc => "samkessaram@gmail.com",
  :subject => "#{num_of_jobs} New Job #{jobs_text} at CMEC",
  :html => "Hi Dom!<br>Something got posted on the CMEC site:<br><br>" + body_text.join('<br>') + "<br><br><hr>Love,<br>Sam"
end

def run_script
  jobs = check_for_job_postings
  jobs = filter_old_jobs(jobs)

  if !jobs.empty?
    save_jobs(jobs)
    send_notification(jobs)
  end
end

run_script
