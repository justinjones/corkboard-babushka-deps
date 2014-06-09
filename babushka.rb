
dep 'babushka system', :app_user, :key, :env

dep 'babushka env vars set', :domain

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
