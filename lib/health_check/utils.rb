# frozen_string_literal: true

# Copyright (c) 2010-2013 Ian Heggie, released under the MIT license.
# See MIT-LICENSE for details.

module HealthCheck
  class Utils
    @@default_smtp_settings =
      {
        address: 'localhost',
        port: 25,
        domain: 'localhost.localdomain',
        user_name: nil,
        password: nil,
        authentication: nil,
        enable_starttls_auto: true
      }

    cattr_accessor :default_smtp_settings

    # process an array containing a list of checks
    def self.process_checks(checks, called_from_middleware = false)
      errors = ''.dup # FIX 'RuntimeError: can't modify frozen String' with .dup (I think it is not a bug)
      checks.each do |check|
        case check
        when 'and', 'site'
        # do nothing
        when 'database'
          HealthCheck::Utils.get_database_version
        when 'email'
          errors << HealthCheck::Utils.check_email
        when 'emailconf'
          errors << HealthCheck::Utils.check_email if HealthCheck::Utils.mailer_configured?
        when 'migrations', 'migration'
          if defined?(ActiveRecord::Migration) && ActiveRecord::Migration.respond_to?(:check_pending!)
            # Rails 4+
            begin
              ActiveRecord::Migration.check_pending!
            rescue ActiveRecord::PendingMigrationError => ex
              errors << ex.message
            end
          else
            database_version  = HealthCheck::Utils.get_database_version
            migration_version = HealthCheck::Utils.get_migration_version
            errors << "Current database version (#{database_version}) does not match latest migration (#{migration_version}). " if database_version.to_i != migration_version.to_i
          end
        when 'cache'
          errors << HealthCheck::Utils.check_cache
        when 'resque-redis-if-present'
          errors << HealthCheck::ResqueHealthCheck.check if defined?(::Resque)
        when 'sidekiq-redis-if-present'
          errors << HealthCheck::SidekiqHealthCheck.check if defined?(::Sidekiq)
        when 'redis-if-present'
          errors << HealthCheck::RedisHealthCheck.check if defined?(::Redis)
        when 's3-if-present'
          errors << HealthCheck::S3HealthCheck.check if defined?(::Aws)
        when 'resque-redis'
          errors << HealthCheck::ResqueHealthCheck.check
        when 'sidekiq-redis'
          errors << HealthCheck::SidekiqHealthCheck.check
        when 'redis'
          errors << HealthCheck::RedisHealthCheck.check
        when 's3'
          errors << HealthCheck::S3HealthCheck.check
        when 'standard'
          errors << HealthCheck::Utils.process_checks(HealthCheck.standard_checks, called_from_middleware)
        when 'middleware'
          errors << 'Health check not called from middleware - probably not installed as middleware.' unless called_from_middleware
        when 'custom'
          HealthCheck.custom_checks.each do |_name, list|
            list.each do |custom_check|
              errors << custom_check.call(self)
            end
          end
        when 'all', 'full'
          errors << HealthCheck::Utils.process_checks(HealthCheck.full_checks, called_from_middleware)
        else
          if HealthCheck.custom_checks.include? check
            HealthCheck.custom_checks[check].each do |custom_check|
              errors << custom_check.call(self)
            end
          else
            return 'invalid argument to health_test.'
          end
        end
      end
      errors
    rescue StandardError => e
      e.message
    end

    def self.db_migrate_path
      # Lazy initialisation so Rails.root will be defined
      @@db_migrate_path ||= Rails.root.join('db', 'migrate')
    end

    def self.db_migrate_path=(value)
      @@db_migrate_path = value
    end

    def self.mailer_configured?
      defined?(ActionMailer::Base) && (ActionMailer::Base.delivery_method != :smtp || HealthCheck::Utils.default_smtp_settings != ActionMailer::Base.smtp_settings)
    end

    def self.get_database_version
      ActiveRecord::Migrator.current_version if defined?(ActiveRecord)
    end

    def self.get_migration_version(dir = db_migrate_path)
      latest_migration = nil
      Dir[File.join(dir, '[0-9]*_*.rb')].each do |f|
        l = begin
              f.scan(/0*([0-9]+)_[_.a-zA-Z0-9]*.rb/).first.first
            rescue StandardError
              -1
            end
        latest_migration = l if !latest_migration || l.to_i > latest_migration.to_i
      end
      latest_migration
    end

    def self.check_email
      case ActionMailer::Base.delivery_method
      when :smtp
        HealthCheck::Utils.check_smtp(ActionMailer::Base.smtp_settings, HealthCheck.smtp_timeout)
      when :sendmail
        HealthCheck::Utils.check_sendmail(ActionMailer::Base.sendmail_settings)
      else
        ''
      end
    end

    def self.check_sendmail(settings)
      File.executable?(settings[:location]) ? '' : 'no sendmail executable found. '
    end

    def self.check_smtp(settings, timeout)
      status = ''
      begin
        if @skip_external_checks
          status = '221'
        else
          Timeout.timeout(timeout) do |_timeout_length|
            t = TCPSocket.new(settings[:address], settings[:port])
            begin
              status = t.gets
              status = t.gets while !status.nil? && status !~ /^2/
              t.puts "HELO #{settings[:domain]}\r"
              status = t.gets while !status.nil? && status !~ /^250/
              t.puts "QUIT\r"
              status = t.gets
            ensure
              t.close
            end
          end
        end
      rescue Errno::EBADF
        status = 'Unable to connect to service'
      rescue Exception => ex
        status = ex.to_s
      end
      /^221/.match?(status) ? '' : "SMTP: #{status || 'unexpected EOF on socket'}. "
    end

    def self.check_cache
      Rails.cache.write('__health_check_cache_test__', 'ok', expires_in: 1.second) ? '' : 'Unable to write to cache. '
    end
  end
end
