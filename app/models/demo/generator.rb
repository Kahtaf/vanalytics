require "securerandom"

class Demo::Generator
  def initialize(seed: ENV.fetch("DEMO_DATA_SEED", nil))
    @seed = seed.present? ? seed.to_i : Random.new_seed
    @rng = Random.new(@seed)
    srand(@seed)
  end

  attr_reader :seed

  def generate_empty_data!(skip_clear: false)
    with_timing(__method__) do
      unless skip_clear
        puts "Clearing existing data..."
        clear_all_data!
      end

      puts "Creating empty family..."
      create_family_and_users!("Demo Family", "user@example.com", onboarded: true)

      puts "Empty demo data loaded successfully!"
    end
  end

  def generate_new_user_data!(skip_clear: false)
    with_timing(__method__) do
      unless skip_clear
        puts "Clearing existing data..."
        clear_all_data!
      end

      puts "Creating new user family..."
      create_family_and_users!("Demo Family", "user@example.com", onboarded: false)

      puts "New user demo data loaded successfully!"
    end
  end

  def generate_new_user_data_for!(family, email:)
    with_timing(__method__, max_seconds: 1000) do
      family = family.reload
      ensure_admin_user!(family, email)

      puts "Creating sample financial data for #{family.name}..."
      ActiveRecord::Base.transaction do
        create_realistic_accounts!(family)
      end

      family.sync_later

      puts "Sample data loaded successfully!"
    end
  end

  def generate_default_data!(skip_clear: false, email: "user@example.com")
    if skip_clear
      puts "Skipping data clearing (appending new family)..."
    else
      puts "Clearing existing data..."
      clear_all_data!
    end

    with_timing(__method__, max_seconds: 1000) do
      puts "Creating demo family..."
      family = create_family_and_users!("Demo Family", email, onboarded: true)

      puts "Creating monitoring API key..."
      create_monitoring_api_key!(family)

      puts "Creating realistic financial data..."
      create_realistic_accounts!(family)

      puts "Realistic demo data loaded successfully!"
    end
  end

  private

    def with_timing(label, max_seconds: nil)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
      puts "#{label} completed in #{duration.round(2)}s"

      if max_seconds && duration > max_seconds
        raise "Demo::Generator ##{label} exceeded #{max_seconds}s (#{duration.round(2)}s)"
      end

      result
    end

    def rand(*args)
      @rng.rand(*args)
    end

    def clear_all_data!
      family_count = Family.count
      if family_count > 50
        raise "Too much data to clear efficiently (#{family_count} families). Run 'rails db:reset' instead."
      end
      Demo::DataCleaner.new.destroy_everything!
    end

    def ensure_admin_user!(family, email)
      user = family.users.find_by(email: email)
      return user if user&.admin? || user&.super_admin?

      raise ActiveRecord::RecordNotFound, "No admin user with email #{email} found in family ##{family.id}"
    end

    def create_family_and_users!(family_name, email, onboarded:)
      family = Family.create!(
        name: family_name,
        currency: "USD",
        locale: "en",
        country: "US",
        timezone: "America/New_York",
        date_format: "%m-%d-%Y"
      )

      family.users.create!(
        email: email,
        first_name: "Jack",
        last_name: "Bogle",
        role: "admin",
        password: "Password1!",
        onboarded_at: onboarded ? Time.current : nil
      )

      family.users.create!(
        email: "partner_#{email}",
        first_name: "Eve",
        last_name: "Bogle",
        role: "member",
        password: "Password1!",
        onboarded_at: onboarded ? Time.current : nil
      )

      family
    end

    def create_monitoring_api_key!(family)
      admin_user = family.users.find_by(role: "admin")
      return unless admin_user

      existing_key = admin_user.api_keys.find_by(display_key: ApiKey::DEMO_MONITORING_KEY)

      if existing_key
        puts "  Use existing monitoring API key"
        return existing_key
      end

      admin_user.api_keys.active.visible.where(source: "web").find_each(&:revoke!)

      api_key = admin_user.api_keys.create!(
        name: "monitoring",
        key: ApiKey::DEMO_MONITORING_KEY,
        scopes: [ "read" ],
        source: "monitoring"
      )

      puts "  Created monitoring API key: #{ApiKey::DEMO_MONITORING_KEY}"
      api_key
    end

    def create_realistic_accounts!(family)
      family.accounts.create!(accountable: Crypto.new, name: "Coinbase USDC", balance: 0, currency: "USD")
    end
end
