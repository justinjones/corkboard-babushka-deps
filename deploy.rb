# coding: utf-8

dep 'ready for update.repo' do
  requires [
    'valid git_ref_data.repo',
    'clean.repo'
  ]
end

dep 'up to date.repo' do
  setup {
    set :rails_root, var(:repo_path)
    set :rails_env, 'production'
    set :username, shell('whoami')
  }
  requires [
    'app updated',
    'pre-restart',
    'app flagged for restart.task',
    'delayed job restarted.task',
    'post-restart'
  ]
end

dep 'app updated' do
  requires [
    'ref info extracted.repo',
    'branch exists.repo',
    'branch checked out.repo',
    'HEAD up to date.repo',
    'benhoskings:app bundled'
  ]
end

dep 'pre-restart' do
  requires [
    'offsite backup.cloudfiles', 
    # 'maintenance page up',
    '☕ & db'
  ]
end

dep 'post-restart' do
  requires [
    'cached JS and CSS removed',
    'maintenance page down'
  ]
end

dep 'ref info extracted.repo' do
  requires 'valid git_ref_data.repo'
  met? {
    %w[old_id new_id branch].all? {|name|
      !Babushka::Base.task.vars.vars[name][:value].nil?
    }
  }
  meet {
    old_id, new_id, branch = var(:git_ref_data).scan(ref_data_regexp).flatten
    set :old_id, old_id
    set :new_id, new_id
    set :branch, branch
  }
end

dep 'valid git_ref_data.repo' do
  met? {
    var(:git_ref_data)[ref_data_regexp] ||
      raise(UnmeetableDep, "Invalid value '#{var(:git_ref_data)}' for :git_ref_data.")
  }
end

dep 'clean.repo' do
  setup {
    # Clear git's internal cache, which sometimes says the repo is dirty when it isn't.
    repo.repo_shell "git diff"
  }
  met? { repo.clean? || raise(UnmeetableDep, "The remote repo has local changes.") }
end

dep 'branch exists.repo' do
  met? { repo.branches.include? var(:branch) }
  meet { repo.branch! var(:branch) }
end

dep 'branch checked out.repo' do
  met? { repo.current_branch == var(:branch) }
  meet { repo.checkout! var(:branch) }
end

dep 'HEAD up to date.repo' do
  met? { repo.current_full_head == var(:new_id) && repo.clean? }
  meet { repo.reset_hard! var(:new_id) }
end

dep 'cached JS and CSS removed' do
  def paths
    %w[
      public/javascripts/all.js
      public/stylesheets/base.css
      public/stylesheets/screen.css
      public/stylesheets/author.css
      public/stylesheets/editor.css
    ]
  end
  def to_remove
    paths.select {|f| f.p.exists? }
  end
  met? {
    to_remove.empty?
  }
  meet {
    to_remove.each {|path| log_shell "Removing #{path}", "rm #{path}" }
  }
end

dep 'app flagged for restart.task' do
  before { shell 'mkdir -p tmp' }
  run { shell 'touch tmp/restart.txt' }
end

dep 'maintenance page up' do
  met? {
    !'public/system/maintenance.html.off'.p.exists? or
    'public/system/maintenance.html'.p.exists?
  }
  meet { 'public/system/maintenance.html.off'.p.copy 'public/system/maintenance.html' }
end

dep 'maintenance page down' do
  met? { !'public/system/maintenance.html'.p.exists? }
  meet { 'public/system/maintenance.html'.p.rm }
end

dep '☕ & db', :template => 'benhoskings:task' do
  run { bundle_rake 'barista:brew db:migrate db:autoupgrade data:migrate tc:data:production' }
end
