
dep 'babushka system', :app_user, :key, :env

dep 'babushka env vars set', :domain

dep 'babushka app', :env, :host, :domain, :app_user, :app_root, :key do
  requires [
    # 'ssl cert in place'.with(:domain => domain, :env => env),

    'rails app'.with(
      :app_name => 'babushka',
      :env => env,
      :listen_host => host,
      :domain => domain,
      :username => app_user,
      :path => app_root,
    )
  ]
end

dep 'babushka packages' do
  requires [
    'postgres',
    'running.nginx',
    'babushka common packages',
  ]
end

dep 'babushka dev' do
  requires [
    'babushka common packages'
  ]
end

dep 'babushka common packages' do
  requires [
    'bundler.gem',
    'postgres.bin',
  ]
end

dep 'babushka caches removed' do
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
