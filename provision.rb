dep 'public key in place', :host, :keys do
  met? {
    shell("ssh -o PasswordAuthentication=no root@#{host} 'true'").tap {|result|
      log "root@#{host} is#{"n't" unless result} accessible via publickey auth.", as: (:ok if result)
    }
  }
  meet {
    shell "ssh root@#{host} 'mkdir -p ~/.ssh; cat > ~/.ssh/authorized_keys'", input: keys
  }
end

dep 'babushka bootstrapped', :host do
  met? {
    raw_shell("ssh root@#{host} 'babushka --version'").stdout[/[\d\.]{5,} \([0-9a-f]{7,}\)/].tap {|result|
      log_ok "#{host} is running babushka-#{result}." if result
    }
  }
  meet {
    shell %{ssh root@#{host} 'bash -'}, :input => shell('curl babushka.me/up'), :log => true
  }
end

dep 'host provisioned', :host, :env, :app_user, :domain, :app_root, :keys, :template => 'task' do

  def as user, &block
    previous_user, @user = @user, user
    yield
  ensure
    @user = previous_user
  end

  def remote_shell *cmd
    host_spec = "#{@user || 'root'}@#{host}"
    opening_message = [
      host_spec.colorize("on grey"), # user@host spec
      cmd.map {|i| i.sub(/^(.{50})(.{3}).*/m, '\1...') }.join(' ') # the command, with long args truncated
    ].join(' $ ')
    log opening_message, :closing_status => opening_message do
      shell "ssh", "-A", host_spec, cmd.map{|i| "'#{i}'" }.join(' '), log: true
    end
  end

  def remote_babushka dep_spec, args = {}
    unless remote_shell('babushka', dep_spec, '--defaults', '--colour', *args.keys.map {|k| "#{k}=#{args[k]}" })
      unmeetable! "The remote babushka reported an error."
    end
  end

  requires 'public key in place'.with(host, keys)
  requires 'babushka bootstrapped'.with(host)
  requires 'git remote'.with(env, app_user, host)

  keys.default!((dependency.load_path.parent / 'config/authorized_keys').read)
  domain.default!(app_user) if env == 'production'
  app_root.default!('~/current')

  run {
    as('root') {
      # This has to be separate because we use 1.9 hashes everywhere else.
      remote_babushka 'benhoskings:ruby.src', version: '1.9.3', patchlevel: 'p0'

      # All the system-wide config for this app, like packages and user accounts.
      remote_babushka "conversation:system provisioned", host_name: host, app_user: app_user, key: keys
    }

    as(app_user) {
      # Set up the app user on the server to accept pushes to ~/current.
      remote_babushka 'benhoskings:web repo'

      # Locally, push code to ~/current on the server.
      Dep('benhoskings:pushed.push').meet(remote: env)

      # Now that the code is in place, provision the app.
      remote_babushka "conversation:app provisioned", env: env, domain: domain, app_user: app_user, app_root: app_root, key: keys
    }

    as('root') {
      remote_babushka "benhoskings:passwordless sudo removed"
    }
  }
end

dep 'system provisioned', :host_name, :app_user, :key do
  requires [
    'benhoskings:system'.with(host_name: host_name),
    'benhoskings:user setup'.with(key: key),
    'benhoskings:lamp stack removed',
    'benhoskings:postfix removed',
    "#{app_user} system".with(host_name, app_user, key),
    "#{app_user} packages",
    'benhoskings:user setup for provisioning'.with(app_user, key)
  ]
end

dep 'app provisioned', :env, :domain, :app_user, :app_root, :key do
  requires [
    "#{app_user} app".with(env, domain, app_user, app_root, key),
  ]
end
