dep 'theconversation.edu.au system', :app_user, :key do
  requires [
    'benhoskings:user setup for provisioning'.with("dw.theconversation.edu.au", key) # For DW loads from psql on the counter machine
  ]
end

dep 'theconversation.edu.au app', :env, :domain, :app_user, :app_root, :key do
  def db_name
    YAML.load_file(app_root / 'config/database.yml')[env.to_s]['database']
  end

  requires [
    'geoip database'.with(:app_root => app_root),
    'cronjobs'.with(env),
    'delayed job'.with(env),
    'postgres extension'.with(app_user, db_name, 'pg_trgm'),
    'ssl certificate'.with(env, domain, 'theconversation.edu.au'),
    'restore db'.with(env, app_user, db_name, app_root),

    'benhoskings:rails app'.with(
      :env => env,
      :domain => domain,
      :username => app_user,
      :enable_https => 'yes',
      :data_required => 'yes'
    ),

    # Replace the default config with our own.
    'vhost enabled'.with(
      :app_name => 'tc',
      :domain => domain,
      :domain_aliases => 'theconversation.com theconversation.org.au conversation.edu.au',
      :path => app_root,
      :proxy_host => 'localhost',
      :proxy_port => 9000,
      :enable_https => 'yes',
      :force_https => 'no'
    ),

    # For the dw.theconversation.edu.au -> backup.tc-dev.net psql/ssh connection.
    'read-only db access'.with(
      :db_name => db_name,
      :username => 'dw.theconversation.edu.au',
      :check_table => 'content'
    )
  ]
end

dep 'theconversation.edu.au packages' do
  requires [
    'curl.lib',
    'benhoskings:running.nginx',
    'supervisor.managed',
    'memcached.managed', # for fragment caching
    'theconversation.edu.au common packages',
    'socat.managed' # for DB tunnelling
  ]
end

dep 'theconversation.edu.au dev' do
  requires [
    'theconversation.edu.au common packages',
    'pv.managed', # for db:production:pull (and it's awesome anyway)
    'phantomjs', # for js testing
    'geoip database'.with(:app_root => '.')
  ]
end

dep 'theconversation.edu.au common packages' do
  requires [
    'bundler.gem',
    'postgres.managed',
    'postgresql-contrib.managed', # for search
    'geoip.managed', # for geoip-c
    'aspell dictionary.managed',
    'coffeescript.src', # for barista
    'imagemagick.managed', # for paperclip
    'libxml.managed', # for nokogiri
    'libxslt.managed' # for nokogiri
  ]
end
