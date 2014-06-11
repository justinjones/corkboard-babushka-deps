dep 'stranger system', :app_user, :key, :env

dep 'stranger env vars set', :domain

dep 'stranger app', :env, :host, :domain, :app_user, :app_root, :key do
  requires [
    'vhosted app'.with(
      :app_name => 'stranger',
      :env => env,
      :listen_host => host,
      :domain => domain,
      :username => app_user,
      :path => app_root,
      :enable_https => 'no',
    )
  ]
end

dep 'stranger packages'
