# frozen_string_literal: true

require 'yaml'
require 'pathname'

module Bluetir
  # Everything a run needs to know, read from one YAML file.
  class Configuration
    ROOT = Pathname.new(File.expand_path('../..', __dir__))
    DEFAULT_PATH = ROOT.join('etc', 'bluetir.yml')
    REQUIRED_KEYS = %w[base_url storefront].freeze

    attr_reader :path, :base_url, :storefront_path, :assertions_path, :orders_path,
                :runs, :screenshots_dir, :timeout, :headless, :recipients, :smtp_server, :sender,
                :http, :settle, :personas_path, :baseline_path

    # Reads the file at +path+, or the one named by BLUETIR_CONFIG, or the shipped default.
    def self.load(path = nil)
      chosen = Pathname.new(path || ENV['BLUETIR_CONFIG'] || DEFAULT_PATH)
      raise ConfigurationError, "configuration file not found: #{chosen}" unless chosen.file?

      new(chosen, read_yaml(chosen))
    end

    # Parses YAML without Ruby object tags, which no configuration file needs.
    def self.read_yaml(pathname)
      YAML.safe_load(pathname.read, aliases: true) || {}
    rescue Psych::SyntaxError => e
      raise ConfigurationError, "#{pathname} is not valid YAML: #{e.message}"
    end

    def initialize(path, data)
      @path = Pathname.new(path)
      missing = REQUIRED_KEYS.reject { |key| data[key] }
      raise ConfigurationError, "#{@path} is missing: #{missing.join(', ')}" if missing.any?

      assign(data)
    end

    # Applies command line overrides, ignoring the ones that were not given.
    def override(base_url: nil, runs: nil, headless: nil)
      @base_url = base_url.sub(%r{/+\z}, '') unless base_url.nil?
      @runs = Integer(runs) unless runs.nil?
      @headless = headless unless headless.nil?
      self
    end

    # Resolves a path from the config file relative to the config file's own directory.
    def resolve(relative)
      candidate = Pathname.new(relative)
      candidate.absolute? ? candidate : @path.dirname.join(candidate)
    end

    def storefront
      Storefront.load(resolve(@storefront_path))
    end

    def assertions
      return {} unless @assertions_path

      self.class.read_yaml(existing(@assertions_path, 'assertions'))
    end

    def orders
      self.class.read_yaml(existing(@orders_path, 'orders'))
    end

    def personas
      Persona.roster(self.class.read_yaml(existing(@personas_path, 'personas')))
    end

    def baseline_file
      raise ConfigurationError, 'no baseline file is configured' unless @baseline_path

      resolve(@baseline_path)
    end

    private

    def assign(data)
      assign_store(data)
      assign_run(data)
      assign_email(data)
      assign_http(data)
    end

    def assign_store(data)
      @base_url        = data['base_url'].to_s.sub(%r{/+\z}, '')
      @storefront_path = data['storefront']
      @assertions_path = data['assertions']
      @orders_path     = data['orders'] || 'orders.yml'
      @personas_path   = data['personas'] || 'personas.yml'
      @baseline_path   = data['baseline']
    end

    def assign_http(data)
      @http = Browser::HttpSettings.from(data['http'])
    end

    def assign_run(data)
      @runs            = Integer(data['runs'] || 1)
      @screenshots_dir = data['screenshots_dir'] || 'screenshots'
      @timeout         = Integer(data['timeout'] || 30)
      @settle          = Float(data['settle'] || 0)
      @headless        = data.fetch('headless', true)
    end

    def assign_email(data)
      @recipients  = Array(data['recipients']).map(&:to_s).reject(&:empty?)
      @smtp_server = data['smtp_server']
      @sender      = data['sender'] || 'bluetir@localhost'
    end

    def existing(relative, label)
      candidate = resolve(relative)
      raise ConfigurationError, "#{label} file not found: #{candidate}" unless candidate.file?

      candidate
    end
  end
end
