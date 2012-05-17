dep 'aspell.managed'

dep 'aspell dictionary.managed', :for => :linux do
  requires 'aspell.managed'
  installs 'aspell-en', 'libaspell-dev'
  provides []
end

dep 'bundler.gem' do
  provides 'bundle'
end

# Actually headers, but 'lib' will do the trick for now.
dep 'curl.lib' do
  installs 'libcurl4-openssl-dev'
end

dep 'libxml.managed' do
  installs { via :apt, 'libxml2-dev' }
  provides []
end

dep 'memcached.managed'

dep 'libxslt.managed' do
  installs { via :apt, 'libxslt1-dev' }
  provides []
end

dep 'imagemagick.managed' do
  provides %w[compare animate convert composite conjure import identify stream display montage mogrify]
end

dep 'coffeescript.src', :version do
  version.default!('1.1.2')
  requires 'nodejs.managed'
  source "http://github.com/jashkenas/coffee-script/tarball/#{version}"
  provides 'coffee'

  configure { true }
  build { shell "bin/cake build" }
  install { shell "bin/cake install", :sudo => Babushka::SrcHelper.should_sudo? }
end

dep 'nodejs.managed', :version do
  requires {
    on :apt, 'our apt source'
  }
  version.default!('0.6.10')
  met? {
    in_path? "node ~> #{version}"
  }
  installs {
    via :apt, 'nodejs'
    via :brew, 'node'
  }
end

dep 'npm.managed', :version do
  requires {
    on :apt, 'our apt source', 'nodejs.managed'
    otherwise 'nodejs.managed'
  }
  version.default!('1.1.0')
  met? {
    in_path? "npm ~> #{version}"
  }
end

dep 'pv.managed'

dep 'rsync.managed'

dep 'socat.managed'

dep 'supervisor.managed' do
  requires 'meld3.pip'
  provides 'supervisord', 'supervisorctl'
end

dep 'meld3.pip' do
  provides []
end

dep 'phantomjs' do
  requires {
    on :linux, 'phantomjs.src'
    on :osx, dep('phantomjs.managed')
  }
end

dep 'phantomjs.src' do
  source 'http://phantomjs.googlecode.com/files/phantomjs-1.4.1-source.tar.gz'
  configure { shell 'qmake-qt4' }
  install { sudo 'cp bin/phantomjs /usr/local/bin/' }
  requires 'qt-dev.managed'
end

dep 'qt-dev.managed' do
  installs {
    on :apt, 'libqt4-dev', 'libqtwebkit-dev', 'qt4-qmake'
  }
  provides []
end

dep 'postgresql-contrib.managed' do
  installs {
    via :apt, 'postgresql-contrib'
    otherwise []
  }
  provides []
end

dep 'tidy.bin'

dep 'graphite-web.pip' do
  requires %w[carbon.pip whisper.pip django.pip django-tagging.pip uwsgi.pip simplejson.pip]
end

dep 'carbon.pip'

dep 'whisper.pip'

dep 'django.pip'

dep 'django-tagging.pip'

dep 'uwsgi.pip'

dep 'simplejson.pip'