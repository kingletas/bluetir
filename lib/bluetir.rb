# frozen_string_literal: true

require_relative 'bluetir/version'
require_relative 'bluetir/http_settings'
require_relative 'bluetir/url'
require_relative 'bluetir/navigator'
require_relative 'bluetir/result'
require_relative 'bluetir/configuration'
require_relative 'bluetir/selector'
require_relative 'bluetir/field'
require_relative 'bluetir/storefront'
require_relative 'bluetir/screenshots'
require_relative 'bluetir/page_assertions'
require_relative 'bluetir/browser_session'
require_relative 'bluetir/notifier'
require_relative 'bluetir/flows/add_to_cart'
require_relative 'bluetir/flows/shipping_quote'
require_relative 'bluetir/flows/checkout'
require_relative 'bluetir/flows/persona_run'
require_relative 'bluetir/persona'
require_relative 'bluetir/probe'
require_relative 'bluetir/baseline'
require_relative 'bluetir/acceptance'
require_relative 'bluetir/shoppers'
require_relative 'bluetir/suite'
require_relative 'bluetir/cli'

# A black-box deployment test suite for Magento, driven by YAML.
module Bluetir
  class Error < StandardError
  end

  # Raised when a configuration file is missing, unreadable or incomplete.
  class ConfigurationError < Error
  end

  # Raised when the storefront profile has no selector for something a flow needs.
  class MissingSelectorError < Error
  end

  # Raised when the store asks us to stop.
  #
  # A throttled run proves nothing about the store, and carrying on makes it
  # worse for whoever else is using it. This ends the run rather than filling a
  # report with failures that are ours rather than theirs.
  class RateLimited < Error
  end
end
