dep 'delayed job', :env, :user do
  requires {
    on :arch, 'delayed_job.systemctl'.with(owner.env, owner.user)
    on :apt, 'delayed_job.upstart'.with(owner.env, owner.user)
  }
end

dep 'delayed_job.upstart', :env, :user do
  respawn 'yes'
  command "bin/rake jobs:work RAILS_ENV=#{env}"
  setuid user
  chdir "~#{user}/current".p
  met? {
    shell?("ps ux | grep -v grep | grep 'rake jobs:work'")
  }
end

dep 'delayed_job.systemctl', :env, :username do
  type 'simple'
  description "corkboard delayed_job worker"
  command "~#{user}/current/bin/rake jobs:work RAILS_ENV=#{env}"
  working_directory "~#{username}/current"
  user username
  met? {
    shell?("ps ux | grep -v grep | grep 'rake jobs:work'")
  }
end
