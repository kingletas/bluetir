# frozen_string_literal: true

module Bluetir
  module Browser
    # One element on a page, described in YAML rather than in Ruby.
    class Selector
      ELEMENT_TYPES = %w[
        element button link text_field textarea select_list radio checkbox div span
      ].freeze
      LOCATOR_KEYS = %w[id css name text title value class label index xpath visible_text].freeze

      # Watir's collection method for each element type. Only `checkbox` is
      # irregular, and getting it wrong would silently find nothing.
      PLURALS = { 'checkbox' => 'checkboxes' }.freeze

      attr_reader :name, :type, :locator, :stage

      # Builds a selector from a YAML hash such as { "type" => "button", "css" => "#go" }.
      def initialize(name, definition)
        @name = name
        @type = definition['type'] || 'element'
        @stage = definition['stage']
        @locator = extract_locator(definition)
        validate
      end

      # Returns the Watir element this selector describes, without touching the page.
      def on(browser)
        browser.public_send(@type, @locator)
      end

      # Every element it matches. A storefront that lists three delivery options
      # under one class needs all three, because the first is not always the one
      # a customer can pick.
      def all_on(browser)
        browser.public_send(PLURALS.fetch(@type, "#{@type}s"), @locator).to_a
      end

      def to_s
        "#{@name} (#{@type} #{@locator.inspect})"
      end

      private

      def extract_locator(definition)
        definition.slice(*LOCATOR_KEYS).transform_keys(&:to_sym)
      end

      def validate
        raise ConfigurationError, "selector '#{@name}' has an unknown type: #{@type}" unless
          ELEMENT_TYPES.include?(@type)
        raise ConfigurationError, "selector '#{@name}' has no locator" if @locator.empty?
      end
    end
  end
end
