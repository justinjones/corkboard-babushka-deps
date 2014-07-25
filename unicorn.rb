dep 'unicorn service', :env, :username, :app_root do
  if Babushka.host.matches?(:arch)
    requires 'unicorn.systemctl'.with(env, username, app_root)
  elsif Babushka.host.matches?(:apt)
    requires 'unicorn.upstart'.with(env, username, app_root)
  end

  def conf_name
    "#{username}_unicorn"
  end

  met? {
    if !(app_root / 'config/unicorn.rb').exists?
      log "Not starting any unicorns because there's no unicorn config."
      true
    else
      running_count = shell('lsof -U').split("\n").grep(/#{Regexp.escape(app_root / 'tmp/sockets/unicorn.socket')}$/).count
      (running_count >= 3).tap {|result| # 1 master + 2 workers
        if result
          log_ok "This app has #{running_count} unicorn#{'s' unless running_count == 1} running (1 master + #{running_count - 1} workers)."
        elsif running_count > 0
          unmeetable! "This app is in an unexpected state: (1 master + #{running_count - 1} workers)."
        else
          log "This app has no unicorns running."
        end
      }
    end
  }

  meet {
    if Babushka.host.matches?(:arch)
      sudo "systemctl daemon-reload"
      sudo "systemctl enable #{conf_name}.service"
      sudo "systemctl start #{conf_name}.service"
    elsif Babushka.host.matches?(:apt)
      sudo "initctl start #{conf_name}"
    end
    sleep 2
  }
end

dep 'unicorn.upstart', :env, :username, :app_root do
  task 'yes'
  command "#{app_root/'bin/unicorn'} -D -E #{env} -c config/unicorn.rb"
  setuid username
  chdir app_root.p
end

dep 'unicorn.systemctl', :env, :username, :app_root do
  type 'forking'
  command "#{app_root/'bin/unicorn'} -D -E #{env} -c config/unicorn.rb"
  user username
  working_directory app_root.p
  pidfile_path(app_root/'tmp/pids/unicorn.pid')
end

dep 'unicorn configured', :path do
  requires 'unicorn config exists'.with(path)
  requires 'unicorn paths'.with(path)
end

dep 'unicorn config exists', :path do
  def unicorn_config
    path / 'config/unicorn.rb'
  end
  def unicorn_socket
    path / 'tmp/sockets/unicorn.socket'
  end
  met? { unicorn_config.exists? }
  meet { render_erb 'unicorn/unicorn.rb.erb', :to => unicorn_config }
end

dep 'unicorn paths', :root do
  def missing_paths
    %w[log tmp/pids tmp/sockets].reject {|p| (root / p).dir? }
  end
  met? { missing_paths.empty? }
  meet { missing_paths.each {|p| (root / p).mkdir } }
end
