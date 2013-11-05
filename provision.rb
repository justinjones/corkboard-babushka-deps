
# Several deps load YAML, e.g. database configs.
require 'yaml'

dep 'no known_hosts conflicts', :host do
  met? {
    "~/.ssh/known_hosts".p.grep(/\b#{Regexp.escape(host)}\b/).blank?.tap {|result|
      log_ok "#{host} doesn't appear in #{'~/.ssh/known_hosts'.p}." if result
    }
  }
  meet {
    shell "sed -i '' -e '/#{Regexp.escape(host)}/d' ~/.ssh/known_hosts"
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

dep 'dir in path', :host, :path do
  met? {
    ssh("root@#{host}").shell("env | grep $PATH").val_for('PATH').split(':').include?(path)
  }
  meet {
    ssh("root@#{host}").shell("echo 'export PATH=#{path}:$PATH' >> ~/.profile")
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

dep 'remote source', :host, :source_name, :source_uri do
  met? {
    ssh("root@#{host}").shell("babushka sources -l").val_for(source_name.to_s)
  }
  meet {
    ssh("root@#{host}").shell("babushka sources -a #{source_name} #{source_uri}")
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
  requires_when_unmet 'dir in path'.with(host, '/usr/local/bin')
  requires_when_unmet 'babushka bootstrapped'.with(host)
  requires_when_unmet 'remote source'.with(host, 'corkboard', 'https://github.com/benhoskings/corkboard-babushka-deps.git')
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
      remote_babushka 'corkboard:ruby.src', :version => '2.0.0', :patchlevel => 'p247'

      # All the system-wide config for this app, like packages and user accounts.
      remote_babushka "corkboard:system provisioned", :host_name => host_name, :env => env, :app_name => app_name, :app_user => app_user, :key => keys
    }

    as(app_user) {
      # This has to run on a separate login from 'deploy user setup', which requires zsh to already be active.
      remote_babushka 'corkboard:user setup', :key => keys

      # Set up the app user for deploys: db user, env vars, and ~/current.
      remote_babushka 'corkboard:deploy user setup', :env => env, :app_name => app_name, :domain => domain
    }

    # The initial deploy.
    Dep('benhoskings:pushed.push').meet(ref, env)

    as(app_user) {
      # Now that the code is in place, provision the app.
      remote_babushka "corkboard:app provisioned", :env => env, :host => host, :domain => domain, :app_name => app_name, :app_user => app_user, :app_root => app_root, :key => keys
    }

    as('root') {
      # Lastly, revoke sudo to lock the box down per-user.
      remote_babushka "corkboard:passwordless sudo removed"
    }

    @run = true
  }
end

dep 'system provisioned', :host_name, :env, :app_name, :app_user, :key do
  requires [
    'hostname'.with(host_name),
    'secured ssh logins',
    'utc',
    'time is syncronised',
    'localhost hosts entry',
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
