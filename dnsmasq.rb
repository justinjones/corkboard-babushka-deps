
dep 'dnsmasq' do
  requires 'dnsmasq.bin', 'user exists'.with(:username => 'dnsmasq', :allow_login => 'no')
  def listening_locally?
    (shell?('lsof -P -n -Fn -sTCP:LISTEN -i :53') || '').
      split("\n").collapse(/^n/).uniq == ['127.0.0.1:53', '[::1]:53']
  end
  met? {
    Babushka::Renderable.new("/etc/dnsmasq.conf").from?(dependency.load_path.parent / "dnsmasq/dnsmasq.conf.erb") &&
    listening_locally?
  }
  meet {
    render_erb "dnsmasq/dnsmasq.conf.erb", :to => "/etc/dnsmasq.conf"

    if Babushka.host.matches?(:arch)
      sudo 'systemctl restart dnsmasq'
    elsif Babushka.host.matches?(:apt)
      sudo '/etc/init.d/dnsmasq restart'
    end
  }
end
