dep 'rails app', :app_name, :env, :domain, :username, :path, :listen_host, :listen_port, :enable_https, :proxy_host, :proxy_port, :nginx_prefix do
  requires [
    'rack app'.with(app_name, env, domain, username, path, listen_host, listen_port, enable_https, proxy_host, proxy_port, nginx_prefix),
    # 'assets precompiled'.with(env, path),
    'unicorn.systemctl'.with(env, username, path)
  ]
end

dep 'sinatra app', :app_name, :env, :domain, :username, :path, :listen_host, :listen_port, :enable_https, :proxy_host, :proxy_port, :nginx_prefix do
  requires [
    'rack app'.with(app_name, env, domain, username, path, listen_host, listen_port, enable_https, proxy_host, proxy_port, nginx_prefix),
    'unicorn.systemctl'.with(env, username, path)
  ]
end

dep 'rack app', :app_name, :env, :domain, :username, :path, :listen_host, :listen_port, :enable_https, :proxy_host, :proxy_port, :nginx_prefix do
  requires [
    'vhosted app'.with('unicorn', app_name, env, domain, username, path, listen_host, listen_port, enable_https, proxy_host, proxy_port, nginx_prefix),
    'rack.logrotate'.with(username),
  ]
end

dep 'vhosted app', :type, :app_name, :env, :domain, :username, :path, :listen_host, :listen_port, :enable_https, :proxy_host, :proxy_port, :nginx_prefix do
  type.default!('static')
  username.default!(domain)
  path.default('~/current')
  env.default(ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'production')

  requires [
    'user exists'.with(:username => username),
    'app bundled'.with(path, env),
    'vhost enabled.nginx'.with(type, app_name, env, domain, path, listen_host, listen_port, enable_https, proxy_host, proxy_port, nginx_prefix),
    'running.nginx'
  ]
end

dep 'assets precompiled', :env, :path, :template => 'task' do
  run {
    shell "bundle exec rake assets:precompile:primary RAILS_GROUPS=assets RAILS_ENV=#{env}", :cd => path
  }
end
