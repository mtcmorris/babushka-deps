dep 'system provisioned', :host_name, :app_user, :password, :key do
  requires [
    'base system provisioned'.with(host_name, password, key),
    'benhoskings:running.nginx',
    'users setup'.with(app_user, password, key)
  ]
end

dep 'base system provisioned', :host_name, :password, :key do
  requires [
    'benhoskings:system'.with(host_name: host_name),
    'benhoskings:user setup'.with(key: key),
    'benhoskings:lamp stack removed',
    'benhoskings:postfix removed',
    "#{app_user} packages",
  ]
end

dep 'users setup', :username, :password, :key do
  requires 'benhoskings:user auth setup'.with(username, password, key)
  requires 'benhoskings:user auth setup'.with("mobwrite.#{username}", password, key)
end
