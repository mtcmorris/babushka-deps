
# Several deps load YAML, e.g. database configs.
require 'yaml'

dep 'no known_hosts conflicts', :host do
  met? {
    "~/.ssh/known_hosts".p.grep(/\b#{Regexp.escape(host)}\b/).blank?.tap {|result|
      log_ok "#{host} doesn't appear in #{'~/.ssh/known_hosts'.p}." if result
    }
  }
  meet {
    shell "sed -i '' -e '/#{Regexp.escape(host)}/d' ~/.ssh/known_hosts"
  }
end

dep 'public key in place', :host, :keys do
  requires_when_unmet 'no known_hosts conflicts'.with(host)
  met? {
    shell?("ssh -o PasswordAuthentication=no root@#{host} 'true'").tap {|result|
      log "root@#{host} is#{"n't" unless result} accessible via publickey auth.", :as => (:ok if result)
    }
  }
  meet {
    shell "ssh root@#{host} 'mkdir -p ~/.ssh; cat > ~/.ssh/authorized_keys'", :input => keys
  }
end

dep 'babushka bootstrapped', :host do
  met? {
    raw_shell("ssh root@#{host} 'babushka --version'").stdout[/[\d\.]{5,} \([0-9a-f]{7,}\)/].tap {|result|
      log_ok "#{host} is running babushka-#{result}." if result
    }
  }
  meet {
    shell %{ssh root@#{host} 'sh -'}, :input => shell('curl https://babushka.me/up'), :log => true
  }
end

meta :remote do
  def as user, &block
    previous_user, @user = @user, user
    yield
  ensure
    @user = previous_user
  end

  def host_spec
    "#{@user || 'root'}@#{host}"
  end

  def remote_shell *cmd
    opening_message = [
      host_spec.colorize("on grey"), # user@host spec
      cmd.map {|i| i.sub(/^(.{50})(.{3}).*/m, '\1...') }.join(' ') # the command, with long args truncated
    ].join(' $ ')
    log opening_message, :closing_status => opening_message do
      shell "ssh", "-A", host_spec, cmd.map{|i| "'#{i}'" }.join(' '), :log => true
    end
  end

  def remote_babushka dep_spec, args = {}
    remote_args = [
      '--defaults',
      ('--update' if Babushka::Base.task.opt(:update)),
      ('--debug'  if Babushka::Base.task.opt(:debug)),
      ('--colour' if $stdin.tty?),
      '--show-args'
    ].compact

    remote_args.concat args.keys.map {|k| "#{k}=#{args[k]}" }

    remote_shell(
      'babushka',
      dep_spec,
      *remote_args
    ).tap {|result|
      unmeetable! "The remote babushka reported an error." unless result
    }
  end

  def failable_remote_babushka dep_spec, args = {}
    remote_babushka(dep_spec, args)
  rescue Babushka::UnmeetableDep
    log "That remote run was marked as failable; moving on."
    false
  end
end

# This dep couples two concerns together (kernel & apt upgrade) and should be refactored.
dep 'host updated', :host, :template => 'remote' do

  def reboot_remote!
    remote_shell('reboot')

    log "Waiting for #{host} to go offline...", :newline => false
    while shell?("ssh", '-o', 'ConnectTimeout=1', host_spec, 'true')
      print '.'
      sleep 5
    end
    puts " gone."

    log "Waiting for #{host} to boot...", :newline => false
    until shell?("ssh", '-o', 'ConnectTimeout=1', host_spec, 'true')
      print '.'
      sleep 5
    end
    puts " booted."
  end

  met? {
    # Make sure we're running on the correct kernel (it should have been installed and booted
    # by the above upgrade; this dep won't attempt an install).
    remote_babushka 'mtcmorris:kernel running', :version => '3.2.0-43-generic' # linux-3.2.0-43.68, for the CVE-2013-2094 fix.
  }

  meet {
    # First we need to configure apt. This involves a dist-upgrade, which should update the kernel.
    remote_babushka 'mtcmorris:apt configured'
    # The above update could have touched the kernel and/or glibc, so a reboot might be required.
    reboot_remote!
  }
end

# This is massive and needs a refactor, but it works for now.
dep 'host provisioned', :host, :host_name, :ref, :env, :app_name, :app_user, :domain, :app_root, :keys, :check_path, :expected_content_path, :expected_content, :template => 'remote' do

  # In production, default the domain to the app user (specified per-app).
  domain.default!(app_user) if env == 'production'

  keys.default!((dependency.load_path.parent / 'config/authorized_keys').read)
  app_root.default!('~/current')
  check_path.default!('/health')
  expected_content_path.default!('/')

  met? {
    cmd = raw_shell("curl --connect-timeout 5 --max-time 30 -v -H 'Host: #{domain}' http://#{host}#{check_path}")

    if !cmd.ok?
      log "Couldn't connect to http://#{host}."
    else
      log_ok "#{host} is up."

      if cmd.stderr.val_for('Status') != '200 OK'
        @should_confirm = true
        log_warn "http://#{domain}#{check_path} on #{host} reported a problem:\n#{cmd.stdout}"
      else
        log_ok "#{domain}#{check_path} responded with 200 OK."

        check_uri = "http://#{host}#{expected_content_path}"
        check_output = shell("curl -v --max-time 30 -H 'Host: #{domain}' #{check_uri} | grep -c '#{expected_content}'")

        if check_output.to_i == 0
          @should_confirm = true
          log_warn "#{domain} on #{check_uri} doesn't contain '#{expected_content}'."
        else
          log_ok "#{domain} on #{check_uri} contains '#{expected_content}'."
          @run || log_warn("The app seems to be up; babushkaing anyway. (How bad could it be?)")
        end
      end
    end
  }

  prepare {
    unmeetable! "OK, bailing." if @should_confirm && !confirm("Sure you want to provision #{domain} on #{host}?")
  }

  requires_when_unmet 'public key in place'.with(host, keys)
  requires_when_unmet 'babushka bootstrapped'.with(host)
  requires_when_unmet 'git remote'.with(env, app_user, host)

  meet {
    as('root') {
      # First, UTF-8 everything. (A new shell is required to test this, hence 2 runs.)
      failable_remote_babushka 'mtcmorris:set.locale', :locale_name => 'en_AU'
      remote_babushka 'mtcmorris:set.locale', :locale_name => 'en_AU'

      # Build ruby separately, because it changes the ruby binary for subsequent deps.
      remote_babushka 'mtcmorris:ruby.src', :version => '2.3.3', :patchlevel => 'p222'

      # All the system-wide config for this app, like packages and user accounts.
      remote_babushka "mtcmorris:system provisioned", :host_name => host_name, :env => env, :app_name => app_name, :app_user => app_user, :key => keys
    }

    as(app_user) {
      # This has to run on a separate login from 'deploy user setup', which requires zsh to already be active.
      remote_babushka 'mtcmorris:user setup', :key => keys

      # Set up the app user for deploys: db user, env vars, and ~/current.
      remote_babushka 'mtcmorris:deploy user setup', :env => env, :app_name => app_name, :domain => domain
    }

    # The initial deploy.
    Dep('benhoskings:pushed.push').meet(ref, env)

    as(app_user) {
      # Now that the code is in place, provision the app.
      remote_babushka "mtcmorris:app provisioned", :env => env, :host => host, :domain => domain, :app_name => app_name, :app_user => app_user, :app_root => app_root, :key => keys
    }

    as('root') {
      # Lastly, revoke sudo to lock the box down per-user.
      remote_babushka "mtcmorris:passwordless sudo removed"
    }

    @run = true
  }
end

dep 'apt configured' do
  requires [
    'apt sources',
    'apt packages removed'.with([/apache/i, /mysql/i, /php/i]),
    'upgrade apt packages'
  ]
end

dep 'system provisioned', :host_name, :env, :app_name, :app_user, :key do
  requires [
    'localhost hosts entry',
    'hostname'.with(host_name),
    'secured ssh logins',
    'utc',
    'time is syncronised',
    'core software',
    'lax host key checking',
    'admins can sudo',
    'tmp cleaning grace period',
    "#{app_name} packages",
    'user setup'.with(:key => key),
    "#{app_name} system".with(app_user, key, env),
    'user setup for provisioning'.with(app_user, key)
  ]
  setup {
    unmeetable! "This dep has to be run as root." unless shell('whoami') == 'root'
  }
end

dep 'app provisioned', :env, :host, :domain, :app_name, :app_user, :app_root, :key do
  requires [
    "#{app_name} app".with(env, host, domain, app_user, app_root, key)
  ]
  setup {
    unmeetable! "This dep has to be run as the app user, #{app_user}." unless shell('whoami') == app_user
  }
end
