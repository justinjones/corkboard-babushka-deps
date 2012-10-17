dep 'theconversation.edu.au system', :app_user, :key do
  requires [
    'benhoskings:user setup for provisioning'.with("dw.theconversation.edu.au", key), # For DW loads from psql on the counter machine
    'benhoskings:postgres access'.with("sharejs.theconversation.edu.au") # For proper DB permissions when the data is restored
  ]
end

dep 'theconversation.edu.au app', :env, :domain, :app_user, :app_root, :key do
  def db_name
    YAML.load_file(app_root / 'config/database.yml')[env.to_s]['database']
  end

  requires [
    'geoip database'.with(:app_root => app_root),
    'delayed job'.with(env, app_user),
    'ssl certificate'.with(env, domain, 'theconversation.edu.au'),
    'db restored'.with(
      :env => env,
      :app_user => app_user,
      :db_name => db_name,
      :app_root => app_root
    ),

    'benhoskings:rails app'.with(
      :env => env,
      :domain => domain,
      :username => app_user,
      :enable_https => 'yes',
      :data_required => 'yes'
    ),

    # Replace the default config with our own.
    'vhost enabled.nginx'.with(
      :app_name => 'tc',
      :env => env,
      :domain => domain,
      :domain_aliases => 'theconversation.com theconversation.org.au conversation.edu.au',
      :path => app_root,
      :proxy_host => 'localhost',
      :proxy_port => 9000,
      :enable_https => 'yes',
      :force_https => 'no'
    ),

    # 'http basic logins.nginx'.with(
    #   :domain => domain,
    #   :username => 'tc',
    #   :pass => ''
    # ),

    # For the dw.theconversation.edu.au -> backup.tc-dev.net psql/ssh connection.
    'read-only db access'.with(
      :db_name => db_name,
      :username => 'dw.theconversation.edu.au',
      :check_table => 'content'
    )
  ]
end

dep 'theconversation.edu.au packages' do
  requires [
    'postgres'.with('9.2'),
    'running.nginx',
    'memcached.bin', # for fragment caching
    'theconversation.edu.au common packages',
    'socat.bin' # for DB tunnelling
  ]
end

dep 'theconversation.edu.au dev' do
  requires [
    'theconversation.edu.au common packages',
    'pv.bin', # for db:production:pull (and it's awesome anyway)
    'phantomjs', # for js testing
    'geoip database'.with(:app_root => '.')
  ]
end

dep 'theconversation.edu.au common packages' do
  requires [
    'bundler.gem',
    'curl.lib',
    'postgres.bin',
    'geoip.bin', # for geoip-c
    'aspell dictionary.lib',
    'coffeescript.src', # for barista
    'tidy.bin', # for upmark preprocessing in MarkdownController
    'imagemagick.bin', # for paperclip
    'libxml.lib', # for nokogiri
    'libxslt.lib' # for nokogiri
  ]
end
