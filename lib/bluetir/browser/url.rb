# frozen_string_literal: true

require 'uri'

module Bluetir
  module Browser
    # Builds every URL the suite visits, so custom parameters cannot be forgotten
    # on one code path and remembered on another.
    class Url
      def initialize(base, params: {})
        @base = base.to_s.sub(%r{/+\z}, '')
        @params = params || {}
      end

      attr_reader :base

      # The absolute URL for a store-relative path, carrying the configured params.
      def for(path)
        joined = join(path)
        return joined if @params.empty?

        uri = URI.parse(joined)
        existing = URI.decode_www_form(uri.query || '')
        uri.query = URI.encode_www_form(existing + @params.to_a)
        uri.to_s
      end

      private

      def join(path)
        text = path.to_s
        return @base if text.empty?
        return text if text.start_with?('http://', 'https://')

        "#{@base}/#{text.sub(%r{\A/+}, '')}"
      end
    end
  end
end
