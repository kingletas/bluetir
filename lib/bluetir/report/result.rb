# frozen_string_literal: true

module Bluetir
  module Report
    # Running tally of every check a suite performed, and the outcome it reports.
    class Result
      Check = Struct.new(:section, :description, :passed, :detail, keyword_init: true)

      attr_reader :checks, :started_at

      def initialize(clock: Time)
        @checks = []
        @clock = clock
        @started_at = clock.now
      end

      # Records a check that succeeded.
      def pass(section, description)
        @checks << Check.new(section: section, description: description, passed: true)
      end

      # Records a check that failed, with the reason it failed.
      def fail(section, description, detail)
        @checks << Check.new(section: section, description: description, passed: false, detail: detail)
      end

      def failures
        @checks.reject(&:passed)
      end

      def total
        @checks.size
      end

      def failed
        failures.size
      end

      def passed
        total - failed
      end

      # A run with no checks at all is a failure: it proves nothing.
      def passed?
        total.positive? && failed.zero?
      end

      def duration
        @clock.now - @started_at
      end

      # One line per failure, for a log or an email body.
      def failure_lines
        failures.map { |check| "#{check.section}: #{check.description} — #{check.detail}" }
      end

      def summary
        return 'no checks ran, so nothing was proven' if total.zero?

        format('%<passed>d of %<total>d checks passed in %<duration>.1fs',
               passed: passed, total: total, duration: duration)
      end
    end
  end
end
