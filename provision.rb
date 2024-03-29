
# Several deps load YAML, e.g. database configs.
require 'yaml'

dep 'no known_hosts conflicts', :host do
  met? {
    "~/.ssh/known_hosts".p.grep(/\b#{Regexp.escape(host)}\b/).blank?.tap {|result|
      log_ok "#{host} doesn't appear in #{'~/.ssh/known_hosts'.p}." if result
    }
  }
  meet {
    shell "sed -i'' -e '/#{Regexp.escape(host)}/d' ~/.ssh/known_hosts"
  }
end

dep 'public key in place', :host, :keys do
  requires_when_unmet 'no known_hosts conflicts'.with(host)
  met? {
    shell?("ssh -o PasswordAuthentication=no root@#{host} 'true'").tap {|result|
      log "root@#{host} is#{"n't" unless result} accessible via publickey auth.", :as => (:ok if result)
    }
  }
  meet {
    shell "ssh root@#{host} 'mkdir -p ~/.ssh; cat > ~/.ssh/authorized_keys'", :input => keys
  }
end

dep 'dir in path', :user, :host, :path do
  met? {
    ssh("#{user}@#{host}").shell("env | grep $PATH").val_for('PATH').split(':').include?(path)
  }
  meet {
    ssh("#{user}@#{host}").shell(%Q{echo "export PATH=#{path}:$PATH" >> /etc/environment})
  }
end

dep 'babushka bootstrapped', :host do
  met? {
    raw_shell("ssh root@#{host} 'babushka --version'").stdout[/[\d\.]{5,} \([0-9a-f]{7,}\)/].tap {|result|
      log_ok "#{host} is running babushka-#{result}." if result
    }
  }
  meet {
    shell %{ssh root@#{host} 'sh -'}, :input => shell('curl https://babushka.me/up/master'), :log => true
  }
end

dep 'remote source', :user, :host, :source_name, :source_uri do
  met? {
    ssh("#{user}@#{host}").shell("babushka sources -l").val_for(source_name.to_s)
  }
  meet {
    ssh("#{user}@#{host}").shell("babushka sources -a #{source_name} #{source_uri}")
  }
end

# This dep actually fixes the system on at least digitalocean ubuntu 14.04;
# the default image's sshd config refers to missing certificates, and the
# full-upgrade below installs them.
dep 'remote host prepared', :host do
  def host_spec
    "root@#{host}"
  end

  def reboot_remote!
    ssh(host_spec).shell('reboot')

    log "Waiting for #{host} to go offline...", :newline => false
    while shell?("ssh", '-o', 'ConnectTimeout=1', host_spec, 'true')
      print '.'
      sleep 5
    end
    puts " gone."

    log "Waiting for #{host} to boot...", :newline => false
    until shell?("ssh", '-o', 'ConnectTimeout=1', host_spec, 'true')
      print '.'
      sleep 5
    end
    puts " booted."
  end

  setup {
    ssh(host_spec).shell("aptitude update")
  }

  met? {
    # This returns 0 if there is nothing to upgrade.
    ssh(host_spec).shell("aptitude full-upgrade </dev/null")
  }

  meet {
    # Proper non-interactive settings for the real upgrade.
    ssh(host_spec).log_shell("#{Babushka::AptHelper.pkg_cmd} -y full-upgrade")
    # The kernel and/or glibc may have changed; play it safe and reboot.
    reboot_remote!
  }
end

# This is massive and needs a refactor, but it works for now.
dep 'host provisioned', :host, :host_name, :ref, :env, :app_name, :app_user, :domain, :app_root, :keys, :check_path, :expected_content_path, :expected_content do

  # In production, default the domain to the app user (specified per-app).
  domain.default!(app_user) if env == 'production'

  keys.default!((dependency.load_path.parent / 'config/authorized_keys').read)
  app_root.default!('~/current')
  check_path.default!('/health')
  expected_content_path.default!('/')

  met? {
    cmd = raw_shell("curl --connect-timeout 5 --max-time 30 -v -H 'Host: #{domain}' http://#{host}#{check_path}")

    if !cmd.ok?
      log "Couldn't connect to http://#{host}."
    else
      log_ok "#{host} is up."

      if cmd.stderr.val_for('Status') != '200 OK'
        @should_confirm = true
        log_warn "http://#{domain}#{check_path} on #{host} reported a problem:\n#{cmd.stdout}"
      else
        log_ok "#{domain}#{check_path} responded with 200 OK."

        check_uri = "http://#{host}#{expected_content_path}"
        check_output = shell("curl -v --max-time 30 -H 'Host: #{domain}' #{check_uri} | grep -c '#{expected_content}'")

        if check_output.to_i == 0
          @should_confirm = true
          log_warn "#{domain} on #{check_uri} doesn't contain '#{expected_content}'."
        else
          log_ok "#{domain} on #{check_uri} contains '#{expected_content}'."
          @run || log_warn("The app seems to be up; babushkaing anyway. (How bad could it be?)")
        end
      end
    end
  }

  prepare {
    unmeetable! "OK, bailing." if @should_confirm && !confirm("Sure you want to provision #{domain} on #{host}?")
  }

  requires_when_unmet 'public key in place'.with(host, keys)
  requires_when_unmet 'remote host prepared'.with(host)
  requires_when_unmet 'dir in path'.with('root', host, '/usr/local/bin')
  requires_when_unmet 'babushka bootstrapped'.with(host)
  requires_when_unmet 'remote source'.with('root', host, 'corkboard', 'https://github.com/benhoskings/corkboard-babushka-deps.git')
  requires_when_unmet 'git remote'.with(env, app_user, host)

  meet {
    ssh("root@#{host}") {|remote|
      # First, UTF-8 everything. (A new shell is required to test this, hence 2 runs.)
      begin
        remote.babushka 'corkboard:set.locale', :locale_name => 'en_AU'
      rescue Babushka::UnmeetableDep => ex
        log "Checking the locle on a fresh session."
        remote.babushka 'corkboard:set.locale', :locale_name => 'en_AU'
      end

      # Build ruby separately, because it changes the ruby binary for subsequent deps.
      remote.babushka 'benhoskings:ruby.src', :version => '2.1.2'

      # All the system-wide config for this app, like packages and user accounts.
      remote.babushka "corkboard:system provisioned", :host_name => host_name, :env => env, :app_name => app_name, :app_user => app_user, :key => keys
    }

    Dep('corkboard:dir in path').meet(app_user, host, '/usr/local/bin')
    Dep('corkboard:remote source').meet(app_user, host, 'corkboard', 'https://github.com/benhoskings/corkboard-babushka-deps.git')

    ssh("#{app_user}@#{host}") {|remote|
      # This has to run on a separate login from 'deploy user setup', which requires zsh to already be active.
      remote.babushka 'corkboard:user setup', :key => keys

      # Set up the app user for deploys: db user, env vars, and ~/current.
      remote.babushka 'corkboard:deploy user setup', :env => env, :app_name => app_name, :domain => domain
    }

    # The initial deploy.
    Dep('common:pushed.push').meet(ref, env)

    ssh("#{app_user}@#{host}") {|remote|
      # Now that the code is in place, provision the app.
      remote.babushka "corkboard:app provisioned", :env => env, :host => host, :domain => domain, :app_name => app_name, :app_user => app_user, :app_root => app_root, :key => keys
    }

    ssh("root@#{host}") {|remote|
      # Lastly, revoke sudo to lock the box down per-user.
      remote.babushka "corkboard:passwordless sudo removed"
    }

    @run = true
  }
end

dep 'system provisioned', :host_name, :env, :app_name, :app_user, :key do
  requires [
    'hostname'.with(host_name),
    'secured ssh logins',
    'utc',
    'time synchronised',
    'localhost hosts entry',
    'global gem installs',
    'core software',
    'lax host key checking',
    'admins can sudo',
    'tmp cleaning grace period',
    "#{app_name} packages",
    'user setup'.with(:key => key),
    "#{app_name} system".with(app_user, key, env),
    'user setup for provisioning'.with(app_user, key)
  ]
  setup {
    unmeetable! "This dep has to be run as root." unless shell('whoami') == 'root'
  }
end

dep 'app provisioned', :env, :host, :domain, :app_name, :app_user, :app_root, :key do
  requires [
    "#{app_name} app".with(env, host, domain, app_user, app_root, key)
  ]
  setup {
    unmeetable! "This dep has to be run as the app user, #{app_user}." unless shell('whoami') == app_user
  }
end
