meta :nginx do
  accepts_list_for :source

  def nginx_bin;    nginx_prefix / "sbin/nginx" end
  def nginx_pid;    nginx_prefix / 'logs/nginx.pid' end
  def cert_path;    nginx_prefix / "conf/certs" end
  def nginx_conf;   nginx_prefix / "conf/nginx.conf" end
  def vhost_conf;   nginx_prefix / "conf/vhosts/#{domain}.conf" end
  def vhost_common; nginx_prefix / "conf/vhosts/#{domain}.common" end
  def vhost_link;   nginx_prefix / "conf/vhosts/on/#{domain}.conf" end

  def upstream_name
    "#{domain}.upstream"
  end
  def unicorn_socket
    path / 'tmp/sockets/unicorn.socket'
  end
  def nginx_running?
    shell? "netstat -an | grep -E '^tcp.*[.:]80 +.*LISTEN'"
  end
  def reload_nginx
    if nginx_running?
      log_shell "Restarting nginx", "#{nginx_bin} -s reload", :sudo => true
      sleep 1 # The reload just sends the signal, and doesn't wait.
    end
  end
end

dep 'vhost enabled.nginx', :app_name, :env, :domain, :path, :listen_host, :listen_port, :enable_https, :proxy_host, :proxy_port, :nginx_prefix do
  requires 'vhost configured.nginx'.with(app_name, env, domain, path, listen_host, listen_port, enable_https, proxy_host, proxy_port, nginx_prefix)
  met? { vhost_link.exists? }
  meet {
    sudo "mkdir -p #{nginx_prefix / 'conf/vhosts/on'}"
    sudo "ln -sf '#{vhost_conf}' '#{vhost_link}'"
  }
  after { reload_nginx }
end

dep 'vhost configured.nginx', :app_name, :env, :domain, :path, :listen_host, :listen_port, :enable_https, :proxy_host, :proxy_port, :nginx_prefix do
  env.default!('production')
  listen_host.default!('[::]')
  listen_port.default!('80')
  enable_https.default!('yes')
  proxy_host.default('localhost')
  proxy_port.default('8000')

  # TODO: Only required until we move to a single-IP nginx config.
  def listen_host_au
    {
      # .com IP => .edu.au IP
      '74.50.63.173' => '74.50.63.170',
      '91.186.19.133' => '31.193.141.103'
    }[listen_host.to_s]
  end
  def listen_host_uk; listen_host; end
  def domain_au; 'theconversation.edu.au' end
  def domain_uk; 'theconversation.org.uk' end

  def up_to_date? source_name, dest
    source = dependency.load_path.parent / source_name
    if !source.p.exists?
      true # If the source config doesn't exist, this is optional (i.e. a .common conf).
    else
      Babushka::Renderable.new(dest).from?(source)
    end
  end

  path.default("~#{domain}/current".p) if shell?('id', domain)
  nginx_prefix.default!('/opt/nginx')

  requires 'configured.nginx'.with(nginx_prefix)
  requires 'unicorn configured'.with(path)

  met? {
    up_to_date?("nginx/#{app_name}_vhost.conf.erb", vhost_conf) &&
    up_to_date?("nginx/#{app_name}_vhost.common.erb", vhost_common)
  }
  meet {
    sudo "mkdir -p #{nginx_prefix / 'conf/vhosts'}"
    render_erb "nginx/#{app_name}_vhost.conf.erb", :to => vhost_conf, :sudo => true
    render_erb "nginx/#{app_name}_vhost.common.erb", :to => vhost_common, :sudo => true if (dependency.load_path.parent / "nginx/#{app_name}_vhost.common.erb").p.exists?
  }
end

dep 'http basic logins.nginx', :nginx_prefix, :domain, :username, :pass do
  nginx_prefix.default!('/opt/nginx')
  met? { shell("curl -I -u #{username}:#{pass} #{domain}").val_for('HTTP/1.1')[/^[25]0\d\b/] }
  meet { (nginx_prefix / 'conf/htpasswd').append("#{username}:#{pass.to_s.crypt(pass)}") }
  after { reload_nginx }
end

dep 'running.nginx', :nginx_prefix do
  requires 'configured.nginx'.with(nginx_prefix), 'initscript.nginx'.with(nginx_prefix)
  met? {
    nginx_running?.tap {|result|
      log "There is #{result ? 'something' : 'nothing'} listening on port 80."
    }
  }
  meet {
    if Babushka.host.matches?(:arch)
      shell 'systemctl start nginx'
      sleep 1
    elsif Babushka.host.matches?(:apt)
      shell 'initctl start nginx'
    end
  }
end

dep 'initscript.nginx', :nginx_prefix do
  requires 'nginx.src'.with(:nginx_prefix => nginx_prefix)
  met? {
    if Babushka.host.matches?(:arch)
      Babushka::Renderable.new('/usr/lib/systemd/system/nginx.service').from?(dependency.load_path.parent / "nginx/nginx.systemctl.conf.erb") &&
      shell('systemctl status nginx') {|s| s.stdout['Loaded: loaded'] }
    elsif Babushka.host.matches?(:apt)
      shell('initctl list').split("\n").grep(/^nginx\b/).any?
    end
  }
  meet {
    if Babushka.host.matches?(:arch)
      render_erb 'nginx/nginx.systemctl.conf.erb', :to => '/usr/lib/systemd/system/nginx.service'
      shell "systemctl daemon-reload"
      shell "systemctl enable nginx"
    elsif Babushka.host.matches?(:apt)
      render_erb 'nginx/nginx.upstart.conf.erb', :to => '/etc/init/nginx.conf'
    end
  }
end

dep 'configured.nginx', :nginx_prefix do
  nginx_prefix.default!('/opt/nginx') # This is required because nginx.src might be cached.
  requires [
    'nginx.src'.with(:nginx_prefix => nginx_prefix),
    'www user and group',
    'nginx.logrotate'
  ]
  met? {
    Babushka::Renderable.new(nginx_conf).from?(dependency.load_path.parent / "nginx/nginx.conf.erb")
  }
  meet {
    render_erb 'nginx/nginx.conf.erb', :to => nginx_conf, :sudo => true
  }
end

dep 'nginx.src', :nginx_prefix, :version do
  nginx_prefix.default!("/opt/nginx")
  version.default!('1.4.3')

  requires 'pcre.lib', 'openssl.lib', 'zlib.lib', 'unzip.bin'

  source "http://nginx.org/download/nginx-#{version}.tar.gz"
  extra_source "https://github.com/vkholodkov/nginx-upload-module/archive/2.2.zip"

  configure_args L{
    [
      "--with-ipv6",
      "--with-pcre",
      "--with-http_ssl_module",
      "--with-http_gzip_static_module",
      "--with-ld-opt='#{shell('pcre-config --libs')}'",
      "--add-module=../../2.2/nginx-upload-module-2.2"
    ].join(' ')
  }

  prefix nginx_prefix
  provides nginx_prefix / 'sbin/nginx'

  configure { log_shell "configure", default_configure_command }
  build { log_shell "build", "make" }
  install { log_shell "install", "make install", :sudo => true }

  met? {
    if !File.executable?(nginx_prefix / 'sbin/nginx')
      log "nginx isn't installed"
    else
      installed_version = shell(nginx_prefix / 'sbin/nginx -v') {|shell| shell.stderr }.val_for(/(nginx: )?nginx version:/).sub('nginx/', '')
      (installed_version.to_version >= version.to_s).tap {|result|
        log "nginx-#{installed_version} is installed"
      }
    end
  }
end
