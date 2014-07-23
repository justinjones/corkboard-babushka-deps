
dep 'corkboard env vars set', :domain

dep 'corkboard system', :app_user, :key, :env do
  requires 'dnsmasq'
end

dep 'corkboard app', :env, :host, :domain, :app_user, :app_root, :key do
  requires 'delayed job'.with(env, app_user)

  requires 'db'.with(
    :env => env,
    :username => app_user,
    :root => app_root,
    :data_required => 'yes'
  )

  requires 'corkboard dirs'.with(app_user, app_root)

  if env == 'production'
    requires 'ssl cert in place'.with(:domain => domain, :env => env)
  else
    requires 'benhoskings:self signed cert.nginx'.with(
      :country => 'AU',
      :state => 'QLD',
      :city => 'Brisbane',
      :organisation => 'corkboard.cc',
      :domain => domain,
      :email => 'support@corkboard.cc'
    )
  end

  requires 'rails app'.with(
    :app_name => 'corkboard',
    :env => env,
    :listen_host => host,
    :domain => domain,
    :username => app_user,
    :path => app_root,
  )
end

dep 'corkboard packages' do
  requires [
    'postgres',
    'running.nginx',
    'corkboard common packages',
  ]
end

dep 'corkboard dev' do
  requires [
    'corkboard common packages',
    'corkboard dirs exist'.with(:app_root => '.'),
  ]
end

dep 'corkboard common packages' do
  requires [
    'bundler.gem',
    'curl.lib',
    'postgres.bin',
    'coffeescript.src', # for barista
    'libxml.lib', # for nokogiri
    'libxslt.lib', # for nokogiri
    '7zip.bin', # to create transfer archives
  ]
end

dep 'corkboard dirs', :app_user, :app_root do
  requires 'corkboard dirs exist'.with(app_root)
  def datadir
    app_root / 'data'
  end
  met? {
    shell("find '#{datadir}' -type d").split("\n").all? {|dir|
      dir.p.owner == 'www' &&
      dir.p.group == app_user &&
      (File.lstat(dir).mode & 0777) == 0770
    }
  }
  meet {
    sudo("chown -R www:#{app_user} '#{datadir}'")
    sudo("chmod -R 770 '#{datadir}'")
  }
end

dep 'corkboard dirs exist', :app_root do
  def corkboard_dirs
    %w[
      data/assets
      data/transfers
    ].concat(
      0.upto(10).map {|i| "data/tmp/#{i}" }
    ).map {|i|
      (app_root / i).p
    }
  end
  met? { corkboard_dirs.all?(&:exists?) }
  meet { corkboard_dirs.each(&:mkdir) }
end
