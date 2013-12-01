
dep 'dnsmasq' do
  requires 'dnsmasq.bin'
  met? {
    Babushka::Renderable.new("/etc/dnsmasq.conf").from?(dependency.load_path.parent / "dnsmasq/dnsmasq.conf.erb")
  }
  meet {
    render_erb "dnsmasq/dnsmasq.conf.erb", :to => "/etc/dnsmasq.conf"
    sudo 'systemctl restart dnsmasq'
  }
end
