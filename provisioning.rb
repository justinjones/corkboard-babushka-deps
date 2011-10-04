dep 'theconversation.edu.au provisioned' do
  requires [
    'theconversation.edu.au packages',
    'cronjobs',
    'delayed job'
  ]
end

dep 'theconversation.edu.au packages' do
  requires [
    'libxml.managed', # for nokogiri
    'libxslt.managed', # for nokogiri
    'imagemagick.managed', # for paperclip
    'coffeescript.src', # for barista
    'supervisor.managed'
  ]
end

dep 'jobs.theconversation.edu.au provisioned', :username, :db_name do
  requires [
    'jobs.theconversation.edu.au packages',
    'cronjobs',
    'postgres extension'.with(username, db_name, 'pg_trgm')
  ]
end

dep 'jobs.theconversation.edu.au packages' do
  requires [
    'imagemagick.managed', # for paperclip
    'postgresql-contrib.managed', # for search
    'tidy.managed' # for upmark
  ]
end
