meta :systemctl do
  accepts_value_for :type, 'simple'
  accepts_value_for :description
  accepts_value_for :command
  accepts_value_for :working_directory
  accepts_value_for :pidfile_path
  accepts_list_for :environment
  accepts_value_for :user

  template {
    def conf_name
      "#{user}_#{basename.gsub(' ', '_')}"
    end
    def conf_dest
      "/usr/lib/systemd/system/#{conf_name}.service"
    end
    meet {
      render_erb "systemctl/service.erb", :to => conf_dest, :sudo => true
      sudo "systemctl daemon-reload"
      sudo "systemctl enable #{conf_name}.service"
      sudo "systemctl start #{conf_name}.service"
      sleep 2
    }
  }
end
