dep 'findation system', :app_user, :key, :env

dep 'findation env vars set', :domain

dep 'findation packages' do
  requires [
    'postgres'.with('9.6'),
    'running.postfix',
    'running.nginx',
    'memcached',
    'findation common packages'
  ]
end

dep 'findation app', :env, :host, :domain, :app_user, :app_root, :key do
  def db_name
    YAML.load_file(app_root / 'config/database.yml')[env.to_s]['database']
  end
  if env == 'production'
    requires 'ssl cert in place'.with(:domain => domain, :env => env)
  end

  requires [
    'db'.with(
      :env => env,
      :username => app_user,
      :root => app_root,
      :data_required => 'no'
    ),

    'rails app'.with(
      :app_name => 'findation',
      :env => env,
      :listen_host => host,
      :domain => domain,
      :username => app_user,
      :path => app_root
    )
  ]
end


dep 'findation common packages' do
  requires [
    'bundler.gem',
    'postgres.bin',
    'libxml.lib', # for nokogiri
    'libxslt.lib', # for nokogiri
    'coffeescript.src' # for barista
  ]
end
