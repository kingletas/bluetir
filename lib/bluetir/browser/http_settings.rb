# frozen_string_literal: true

module Bluetir
  module Browser
    # How requests are made: who we say we are, what we carry, and how fast.
    #
    # A store can need any of these before it will behave like the one you meant
    # to test — a staging site behind a header, a store view chosen by cookie, a
    # currency chosen by query parameter, or a bot filter that wants a real user
    # agent. Without them the suite tests a different site and says nothing about
    # it.
    class HttpSettings
      # Identify the tool by default. A storefront owner reading their logs should
      # be able to tell an automated check from a customer, and from an attacker.
      DEFAULT_USER_AGENT = "Bluetir/#{VERSION} (+https://github.com/kingletas/bluetir)".freeze

      # A second between page loads. This drives somebody else's shop, and the
      # polite default costs a run a few seconds.
      DEFAULT_DELAY = 1.0

      attr_reader :user_agent, :headers, :cookies, :params, :delay, :local_storage

      def self.from(data)
        new(data || {})
      end

      def initialize(data)
        @user_agent = data['user_agent'] || DEFAULT_USER_AGENT
        @headers = stringify(data['headers'])
        @cookies = Array(data['cookies']).map { |c| cookie(c) }
        @params = stringify(data['params'])
        @local_storage = stringify(data['local_storage'])
        @delay = Float(data.fetch('delay', DEFAULT_DELAY))
      end

      def headers?
        !@headers.empty?
      end

      def cookies?
        !@cookies.empty?
      end

      def params?
        !@params.empty?
      end

      def local_storage?
        !@local_storage.empty?
      end

      def summary
        parts = ["user agent #{@user_agent.split.first}", "delay #{@delay}s"]
        parts << "#{@headers.size} header(s)" if headers?
        parts << "#{@cookies.size} cookie(s)" if cookies?
        parts << "#{@params.size} param(s)" if params?
        parts << "#{@local_storage.size} stored value(s)" if local_storage?
        parts.join(', ')
      end

      private

      def stringify(pairs)
        (pairs || {}).to_h { |key, value| [key.to_s, value.to_s] }
      end

      # A cookie needs a name and a value; everything else the browser can default.
      def cookie(entry)
        raise ConfigurationError, "a cookie must be a mapping, got #{entry.inspect}" unless
          entry.is_a?(Hash)

        name = entry['name'].to_s
        raise ConfigurationError, 'a cookie needs a name' if name.empty?

        built = { name: name, value: entry['value'].to_s }
        %w[domain path expires secure].each do |key|
          built[key.to_sym] = entry[key] if entry.key?(key)
        end
        built
      end
    end
  end
end
