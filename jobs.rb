dep 'jobs.theconversation.edu.au system', :app_user, :key

dep 'jobs.theconversation.edu.au app', :env, :domain, :app_user, :app_root, :key do
  def db_name
    YAML.load_file(app_root / 'config/database.yml')[env.to_s]['database']
  end

  requires [
    'cronjobs'.with(env),
    'delayed job'.with(env),
    'postgres extension'.with(app_user, db_name, 'pg_trgm'),
    'benhoskings:rails app'.with(
      :env => env,
      :domain => domain,
      :username => app_user,
      :enable_https => 'yes',
      :data_required => 'yes'
    )
  ]
end

dep 'jobs.theconversation.edu.au packages' do
  requires [
    'benhoskings:running.nginx',
    'supervisor.managed',
    'jobs.theconversation.edu.au common packages'
  ]
end

dep 'jobs.theconversation.edu.au dev' do
  requires 'jobs.theconversation.edu.au common packages'
end

dep 'jobs.theconversation.edu.au common packages' do
  requires [
    'bundler.gem',
    'postgres.managed',
    'libxml.managed', # for nokogiri
    'libxslt.managed', # for nokogiri
    'imagemagick.managed', # for paperclip
    'coffeescript.src', # for barista
    'postgresql-contrib.managed', # for search
    'tidy.managed' # for upmark
  ]
end
