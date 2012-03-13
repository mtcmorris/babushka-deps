dep 'sharejs', :username, :env do
  requires [
    'sharejs.supervisor'.with(:username => username, :env => env)
  ]
end


dep 'sharejs.supervisor', :username, :env, :db_name do
  requires 'sharejs app'.with(username, db_name)

  username.default!(shell('whoami'))
  db_name.default!("tc_#{env}")

  command "coffee app.coffee"
  environment %Q{NODE_ENV="#{env}"}
  user username
  directory "/srv/http/#{user}/current"

  met? {
    ((shell("curl -I localhost:9000") || '').val_for('X-Refspec') || '').length > 0
  }
end

dep 'sharejs app', :username, :db_name do
  requires [
    'sharejs db permissions'.with(username, db_name),
    'npm packages installed',
  ]
end

dep 'npm packages installed', :template => "benhoskings:task" do
  # No apparent equivalent for bundle check command
  run { shell %Q{npm install}, :cd => "~/current" }
end

dep 'sharejs db permissions', :username, :db_name do
  # Access to draft tables
  requires 'table access'.with(username, db_name, "sharejs.article_draft_operations")
  requires 'table access'.with(username, db_name, "sharejs.article_draft_snapshots")
end

dep 'table access', :username, :db_name, :table_name do
  requires 'benhoskings:postgres access'.with(username)
  requires 'table sequence access'.with(username, db_name, "#{table_name}_id_seq")
  met? { shell? "psql #{db_name} -c 'SELECT id FROM #{table_name} LIMIT 1'" }
  meet { sudo %Q{psql #{db_name} -c 'GRANT SELECT,INSERT,DELETE,UPDATE ON #{table_name} TO "#{username}"'}, :as => 'postgres' }
end

dep 'table sequence access', :username, :db_name, :seq_name do
  requires 'benhoskings:postgres access'.with(username)
  met? { shell? "psql #{db_name} -c 'SELECT sequence_name FROM #{seq_name} LIMIT 1'" }
  meet { sudo %Q{psql #{db_name} -c 'GRANT SELECT,UPDATE ON #{seq_name} TO "#{username}"'}, :as => 'postgres' }
end

