
dep 'pechakucha system', :app_user, :key, :env

dep 'pechakucha env vars set', :env, :domain

dep 'pechakucha app', :env, :host, :domain, :app_user, :app_root, :key do
  requires [
    # 'ssl cert in place'.with(:domain => domain, :env => env),

    'db'.with(
      :env => env,
      :username => app_user,
      :root => app_root,
      :data_required => 'no'
    ),

    'rails app'.with(
      :app_name => 'pechakucha',
      :env => env,
      :listen_host => host,
      :domain => domain,
      :username => app_user,
      :path => app_root,
    )
  ]
end

dep 'pechakucha packages' do
  requires [
    'postgres',
    'running.nginx',
    'pechakucha common packages',
  ]
end

dep 'pechakucha dev' do
  requires [
    'pechakucha common packages'
  ]
end

dep 'pechakucha common packages' do
  requires [
    'bundler.gem',
    'postgres.bin',
  ]
end

dep 'pechakucha caches removed' do
  def paths
    %w[
      ~/.babushka/downloads/*
      ~/.babushka/build/*
    ]
  end
  def to_remove
    paths.reject {|p|
      Dir[p.p].empty?
    }
  end
  met? {
    to_remove.empty?
  }
  meet {
    to_remove.each {|path|
      shell %Q{rm -rf #{path}}
    }
  }
end
