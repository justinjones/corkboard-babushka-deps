dep 'pendulum system', :app_user, :key, :env

dep 'pendulum env vars set', :domain

dep 'pendulum app', :env, :host, :domain, :app_user, :app_root, :key do
  requires [
    # 'ssl cert in place'.with(:domain => domain, :env => env),

    'db'.with(
      :env => env,
      :username => app_user,
      :root => app_root,
      :data_required => 'yes'
    ),

    'assets precompiled'.with(env, app_root),

    'rails app'.with(
      :app_name => 'pendulum',
      :env => env,
      :listen_host => host,
      :domain => domain,
      :username => app_user,
      :path => app_root,
      :enable_https => 'no', # :|
    )
  ]
end

dep 'pendulum packages' do
  requires [
    'postgres',
    'running.nginx',
    'pendulum common packages',
  ]
end

dep 'pendulum dev' do
  requires [
    'pendulum common packages'
  ]
end

dep 'pendulum common packages' do
  requires [
    'bundler.gem',
    'postgres.bin',
    'nodejs.bin',
  ]
end
