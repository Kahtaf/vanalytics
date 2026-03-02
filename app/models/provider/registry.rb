class Provider::Registry
  include ActiveModel::Validations

  Error = Class.new(StandardError)

  CONCEPTS = %i[exchange_rates securities]

  validates :concept, inclusion: { in: CONCEPTS }

  class << self
    def for_concept(concept)
      new(concept.to_sym)
    end

    def get_provider(name)
      send(name)
    rescue NoMethodError
      raise Error.new("Provider '#{name}' not found in registry")
    end

    private
      def twelve_data
        api_key = ENV["TWELVE_DATA_API_KEY"].presence || Setting.twelve_data_api_key

        return nil unless api_key.present?

        Provider::TwelveData.new(api_key)
      end

      def github
        Provider::Github.new
      end

      def yahoo_finance
        Provider::YahooFinance.new
      end
  end

  def initialize(concept)
    @concept = concept
    validate!
  end

  def providers
    available_providers.map { |p| self.class.send(p) }.compact
  end

  def get_provider(name)
    provider_method = available_providers.find { |p| p == name.to_sym }

    raise Error.new("Provider '#{name}' not found for concept: #{concept}") unless provider_method.present?

    self.class.send(provider_method)
  end

  private
    attr_reader :concept

    def available_providers
      case concept
      when :exchange_rates
        %i[twelve_data yahoo_finance]
      when :securities
        %i[twelve_data yahoo_finance]
      else
        %i[github]
      end
    end
end
