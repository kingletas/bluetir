# frozen_string_literal: true

module Bluetir
  # The selectors and paths for one storefront, so the flows hold no markup knowledge.
  class Storefront
    attr_reader :name, :platform, :paths

    def self.load(pathname)
      raise ConfigurationError, "storefront profile not found: #{pathname}" unless pathname.file?

      new(Configuration.read_yaml(pathname), pathname)
    end

    def initialize(data, source = nil)
      @source = source
      @name = data['name'] || 'unnamed'
      @platform = data['platform'] || 'unknown'
      @paths = data['paths'] || {}
      @selectors = build_selectors(data['selectors'] || {})
      @texts = data['texts'] || {}
    end

    # Returns the named selector, or explains which profile is missing it.
    def [](name)
      @selectors.fetch(name.to_s) do
        raise MissingSelectorError, "storefront '#{@name}' has no selector '#{name}'#{source_hint}"
      end
    end

    def key?(name)
      @selectors.key?(name.to_s)
    end

    # A string the store is expected to print, such as the order confirmation.
    def text(name)
      @texts.fetch(name.to_s) do
        raise ConfigurationError, "storefront '#{@name}' has no text '#{name}'#{source_hint}"
      end
    end

    def text?(name)
      @texts.key?(name.to_s)
    end

    def path(name)
      @paths.fetch(name.to_s) do
        raise ConfigurationError, "storefront '#{@name}' has no path '#{name}'#{source_hint}"
      end
    end

    def selector_names
      @selectors.keys.sort
    end

    def summary
      "#{@name} (#{@platform}), #{@selectors.size} selectors"
    end

    def stage_of(name)
      @selectors[name.to_s]&.stage
    end

    private

    def build_selectors(raw)
      raw.each_with_object({}) do |(name, definition), built|
        built[name] = Browser::Selector.new(name, definition)
      end
    end

    def source_hint
      @source ? " (#{@source})" : ''
    end
  end
end
