meta :upstart do
  accepts_value_for :task, 'no' # A fire-and-forget command; wait until it's exited.
  accepts_value_for :respawn, 'no' # Restart the process when it exits.
  accepts_value_for :command
  accepts_list_for :environment
  accepts_value_for :chdir
  accepts_value_for :setuid
  template {
    def conf_name
      "#{setuid}_#{basename.gsub(' ', '_')}"
    end
    def conf_dest
      "/etc/init/#{conf_name}.conf"
    end
    met? {
      Babushka::Renderable.new(conf_dest).from?(dependency.load_path.parent / "upstart/service.conf.erb")
    }
    meet {
      render_erb "upstart/service.conf.erb", :to => conf_dest, :sudo => true
    }
  }
end
