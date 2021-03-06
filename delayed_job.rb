dep 'delayed job', :env, :user do
  requires 'delayed_job.upstart'.with(env, user)
end

dep 'delayed_job.upstart', :env, :user do
  respawn 'yes'
  command "bundle exec rake jobs:work RAILS_ENV=#{env}"
  setuid user
  chdir "/srv/http/#{user}/current"
  met? {
    shell?("ps ux | grep -v grep | grep 'rake jobs:work'")
  }
end
