dep 'ruby.src', :version, :patchlevel do
  def version_group
    version.to_s.scan(/^\d\.\d/).first
  end
  def add_extension ext_name
    log_shell "configure #{ext_name}", "ruby extconf.rb", :cd => "ext/#{ext_name}"
  end
  version.default!('2.0.0')
  patchlevel.default!('p353')
  requires_when_unmet [
    'ruby.lib', # We need an existing ruby with mkmf to build a new ruby.
    'curl.lib',
    'openssl.lib',
    'readline.lib',
    'yaml.lib',
    'zlib.lib'
  ]
  source "ftp://ftp.ruby-lang.org/pub/ruby/#{version_group}/ruby-#{version}-#{patchlevel}.tar.gz"
  provides "ruby == #{version}#{patchlevel}", 'gem', 'irb'
  configure {
    log_shell "configure", "./configure --prefix=#{prefix} --disable-install-doc"
    add_extension 'openssl'
    add_extension 'psych'
    add_extension 'readline'
    add_extension 'zlib'
  }
  build {
    log_shell "build", "make -j#{Babushka.host.cpus}"
  }
  postinstall {
    # The ruby <1.9.3 installer skips bin/* when the build path contains a dot-dir.
    shell "cp bin/* #{prefix / 'bin'}", :sudo => Babushka::SrcHelper.should_sudo?
  }
end
