dep 'aptitude.bin'

dep 'aspell.bin'

dep 'aspell dictionary.lib' do
  requires 'aspell.bin'
  installs {
    on :linux, 'aspell-en', 'libaspell-dev'
    otherwise []
  }
end

dep 'bundler.gem' do
  provides []
end

dep 'nodejs.bin', :version do
  version.default('4.2.6')
  requires_when_unmet {
    on :apt, 'keyed apt source'.with(
      :uri => 'http://ppa.launchpad.net/chris-lea/node.js/ubuntu',
      :release => 'precise',
      :repo => 'main',
      :key_sig => 'C7917B12',
      :key_uri => 'http://keyserver.ubuntu.com:11371/pks/lookup?op=get&search=0xB9316A7BC7917B12'
    )
  }
  installs {
    via :apt, [
      "nodejs",
      "nodejs-dev"
    ]
    via :brew, "nodejs"
  }
  provides "nodejs ~> #{version}"
end

dep 'coffeescript.bin', :version do
  version.default!('1.4.0')
  requires 'nodejs.bin'
  provides "coffee >= #{version}"
end

dep 'curl.lib' do
  installs {
    on :osx, [] # It's provided by the system.
    otherwise 'libcurl4-openssl-dev'
  }
end

dep 'git-smart.gem' do
  provides %w[git-smart-log git-smart-merge git-smart-pull]
end

dep 'htop.bin'

dep 'imagemagick.bin' do
  provides %w[compare animate convert composite conjure import identify stream display montage mogrify]
end

dep 'iotop.bin'

dep 'jnettop.bin'

dep 'libxml.lib' do
  installs {
    # The latest libxml2 on 12.04 doesn't have a corresponding libxml2-dev.
    on :precise, 'libxml2=2.7.8.dfsg-5.1ubuntu4', 'libxml2-dev=2.7.8.dfsg-5.1ubuntu4'

    via :apt, 'libxml2-dev'
  }
end

dep 'libxslt.lib' do
  installs { via :apt, 'libxslt1-dev' }
end

dep 'logrotate.bin'

dep 'lsof.bin'

dep 'memcached.bin'

dep 'nc.bin'

dep 'nmap.bin'

dep 'ntpdate.bin'

dep 'pcre.lib' do
  installs 'libpcre3-dev'
end

dep 'libtag.lib' do
  installs 'libtag1-dev'
end

dep 'pngquant.bin', :version do
  version.default('2.0.1')
  requires_when_unmet {
    on :apt, 'keyed apt source'.with(
      :uri => 'http://ppa.launchpad.net/danmbox/ppa/ubuntu',
      :release => 'precise',
      :repo => 'main',
      :key_sig => '751CCC86',
      :key_uri => 'http://keyserver.ubuntu.com:11371/pks/lookup?op=get&search=0x1066CD08751CCC86'
    )
  }
  installs {
    via :apt, "pngquant"
    via :brew, "pngquant"
  }
end

dep 'pv.bin'

dep 'readline.lib' do
  installs {
    on :lenny, 'libreadline5-dev'
    via :apt, 'libreadline6-dev'
  }
end

dep 'qt-dev.lib' do
  installs {
    on :apt, 'libqt4-dev', 'libqtwebkit-dev', 'qt4-qmake'
  }
end

dep 'raca.gem' do
  provides []
end

dep 'rcconf.bin' do
  requires 'whiptail.bin'
end

dep 'socat.bin'

dep 'sshd.bin' do
  installs {
    via :apt, 'openssh-server'
  }
end

dep 'ssl.lib' do
  installs {
    via :apt, 'libssl-dev'
    via :yum, 'openssl-devel'
  }
end

dep 'tidy.bin'

dep 'tmux.bin'

dep 'traceroute.bin'

dep 'tree.bin'

dep 'vim.bin'

dep 'whiptail.bin'

dep 'yaml.lib' do
  installs {
    via :brew, 'libyaml'
    via :apt, 'libyaml-dev'
  }
end

dep 'zlib.lib' do
  installs {
    via :apt, 'zlib1g-dev'
    via :yum, 'zlib-devel'
  }
end
