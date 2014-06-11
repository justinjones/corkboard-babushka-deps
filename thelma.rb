dep 'thelma system', :app_user, :key, :env

dep 'thelma env vars set', :domain

dep 'thelma app', :env, :host, :domain, :app_user, :app_root, :key do
  requires [
    'rack app'.with(
      :app_name => 'thelma',
      :env => env,
      :listen_host => host,
      :domain => domain,
      :username => app_user,
      :path => app_root,
      :enable_https => 'no',
    )
  ]
end

dep 'thelma packages' do
  requires [
    'running.nginx',
    'thelma common packages',
  ]
end

dep 'thelma dev' do
  requires [
    'thelma common packages'
  ]
end

dep 'thelma common packages' do
  requires [
    'bundler.gem',
    'coffee-script.npm',
  ]
end
