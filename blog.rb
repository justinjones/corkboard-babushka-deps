
dep 'blog system', :app_user, :key, :env

dep 'blog env vars set', :domain

dep 'blog app', :env, :host, :domain, :app_user, :app_root, :key do
  requires [
    'vhosted app'.with(
      :app_name => 'blog',
      :env => env,
      :listen_host => host,
      :domain => domain,
      :username => app_user,
      :path => app_root,
    )
  ]
end

dep 'blog packages' do
  requires [
    'running.nginx',
    'blog common packages',
  ]
end

dep 'blog dev' do
  requires [
    'blog common packages'
  ]
end

dep 'blog common packages' do
  requires [
    'bundler.gem',
  ]
end
