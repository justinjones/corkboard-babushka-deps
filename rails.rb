dep 'rails app', :domain, :domain_aliases, :username, :path, :listen_host, :listen_port, :proxy_host, :proxy_port, :env, :nginx_prefix, :data_required do
  requires 'rack app'.with(domain, domain_aliases, username, path, listen_host, listen_port, proxy_host, proxy_port, env, nginx_prefix, data_required)
  requires 'benhoskings:db'.with(username, path, env, data_required, 'yes')
end

dep 'rack app', :domain, :domain_aliases, :username, :path, :listen_host, :listen_port, :proxy_host, :proxy_port, :env, :nginx_prefix, :data_required do
  username.default!(shell('whoami'))
  path.default('~/current')
  env.default(ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'production')

  requires 'webapp'.with('unicorn', domain, domain_aliases, username, path, listen_host, listen_port, proxy_host, proxy_port, nginx_prefix)
  requires 'benhoskings:web repo'.with(path)
  requires 'benhoskings:app bundled'.with(path, env)
  requires 'benhoskings:rack.logrotate'.with(username)
end

dep 'webapp', :type, :domain, :domain_aliases, :username, :path, :listen_host, :listen_port, :proxy_host, :proxy_port, :nginx_prefix do
  username.default!(domain)
  requires 'benhoskings:user exists'.with(username, '/srv/http')
  requires 'vhost enabled.nginx'.with(type, domain, domain_aliases, path, listen_host, listen_port, proxy_host, proxy_port, nginx_prefix)
  requires 'running.nginx'
end
