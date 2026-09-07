# frozen_string_literal: true

require 'optparse'
require 'pathname'

module Bluetir
  # The bluetir command: reads the options, runs the suite, sets the exit status.
  class CLI
    SUCCESS = 0
    FAILURE = 1

    def initialize(argv, output: $stdout, error: $stderr)
      @argv = argv
      @output = output
      @error = error
      @options = { mode: 'order', dry_run: false }
    end

    # Runs the suite and returns the exit status the shell should see.
    def run
      parse
      configuration = apply_overrides(Configuration.load(@options[:config]))
      suite = build(configuration)
      return report_plan(suite) if @options[:dry_run]

      result = suite.run
      # A failing persona run is only reproducible if the seed that made it is
      # printed, so it always is.
      @output.puts("  personas ran with seed #{suite.seed}") if @options[:mode] == 'persona'
      report(result)
    rescue Bluetir::Error => e
      @error.puts("[error] #{e.message}")
      FAILURE
    end

    private

    def report_plan(suite)
      @output.puts('Bluetir would run:')
      suite.plan.each { |line| @output.puts("  #{line}") }
      SUCCESS
    end

    def report(result)
      @output.puts(result.summary)
      result.failure_lines.each { |line| @output.puts("  FAIL  #{line}") }
      result.passed? ? SUCCESS : FAILURE
    end

    def build(configuration)
      Suite.new(configuration, mode: @options[:mode], output: @output,
                               seed: @options[:seed], baseline_out: baseline_out)
    end

    def baseline_out
      @options[:baseline] && Pathname.new(@options[:baseline])
    end

    def apply_overrides(configuration)
      configuration.override(base_url: @options[:base_url], runs: @options[:runs],
                             headless: @options[:headless])
    end

    def parse
      parser.parse!(@argv)
    rescue OptionParser::ParseError => e
      @error.puts(e.message)
      @error.puts(parser)
      exit FAILURE
    end

    def parser
      @parser ||= OptionParser.new do |opts|
        opts.banner = 'Usage: bluetir [options]'
        opts.separator ''
        define_options(opts)
        define_common_options(opts)
      end
    end

    def define_options(opts)
      opts.on('-c', '--config FILE', 'Configuration file to use') { |v| @options[:config] = v }
      opts.on('-b', '--base-url URL', 'Store to test, overriding the config') do |v|
        @options[:base_url] = v
      end
      opts.on('-m', '--mode MODE', Suite::MODES, "Run mode: #{Suite::MODES.join(', ')}") do |v|
        @options[:mode] = v
      end
      opts.on('-r', '--runs N', Integer, 'How many times to run') { |v| @options[:runs] = v }
      define_acceptance_options(opts)
    end

    def define_acceptance_options(opts)
      opts.on('--seed N', Integer, 'Seed the personas, to repeat a run exactly') do |v|
        @options[:seed] = v
      end
      opts.on('--baseline FILE', 'Where to write a baseline') { |v| @options[:baseline] = v }
      opts.on('--[no-]headless', 'Run the browser without a window') do |v|
        @options[:headless] = v
      end
    end

    def define_common_options(opts)
      opts.on('-n', '--dry-run', 'Check the configuration and print the plan') do
        @options[:dry_run] = true
      end
      opts.on_tail('-h', '--help', 'Show this message') do
        @output.puts(opts)
        exit SUCCESS
      end
      opts.on_tail('--version', 'Show the version') do
        @output.puts(Bluetir::VERSION)
        exit SUCCESS
      end
    end
  end
end
