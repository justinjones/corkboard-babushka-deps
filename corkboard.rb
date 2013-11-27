
dep 'corkboard env vars set', :domain

dep 'corkboard system', :app_user, :key, :env

dep 'corkboard app', :env, :host, :domain, :app_user, :app_root, :key do
  requires [
    'delayed job'.with(env, app_user),

    'db'.with(
      :env => env,
      :username => app_user,
      :root => app_root,
      :data_required => 'yes'
    ),

    'corkboard dirs'.with(:app_root => app_root),

    'rails app'.with(
      :app_name => 'corkboard',
      :env => env,
      :listen_host => host,
      :domain => domain,
      :username => app_user,
      :path => app_root,
    )
  ]
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
    'corkboard dirs exist',
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

dep 'corkboard dirs' do
  requires
  met? {
    shell('find data/ -type d').split("\n").all? {|dir|
      dir.p.owner == 'www' &&
      dir.p.group == 'corkboard.cc' &&
      (File.lstat(dir).mode & 0777) == 0770
    }
  }
  meet {
    sudo('chown -R www:corkboard.cc data/')
    sudo('chmod -R 770 data')
  }
end

dep 'corkboard dirs exist' do
  def corkboard_dirs
    %w[
      data/assets
      data/transfers
    ].concat(
      0.upto(10).map {|i| "data/tmp/#{i}" }
    ).map {|i|
      i.p.mkdir
    }
  end
  met? { corkboard_dirs.all?(&:exists?) }
  meet { corkboard_dirs.each(&:mkdir) }
end
