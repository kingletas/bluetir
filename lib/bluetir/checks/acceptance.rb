# frozen_string_literal: true

module Bluetir
  module Checks
    # Captures what a working store looks like, and reports what has moved since.
    #
    # This is the half of acceptance testing a list of expectations cannot do. An
    # assertions file only knows what somebody thought to write down; a baseline
    # knows what was actually there, so it catches the selector nobody remembered
    # to assert on.
    class Acceptance
      def initialize(context, orders, output)
        @context = context
        @orders = orders
        @output = output
      end

      # Records the store as it is now and writes it out.
      def capture(store:, to:)
        baseline = snapshot(store)
        written = baseline.write(to)
        say "  wrote #{written} — #{baseline.summary}"
        @context.result.pass('baseline', "captured #{baseline.selectors.size} selectors")
        baseline
      end

      # Compares the store with a baseline. Silent when nothing has moved.
      def compare(store:, against:)
        was = Checks::Baseline.load(against)
        drift = was.drift_from(snapshot(store))
        return unchanged(was) if drift.empty?

        drift.each { |one| record(one) }
      end

      private

      def snapshot(store)
        probe = Checks::Probe.new(@context, @orders)
        sightings = probe.run
        Checks::Baseline.capture(store: store, landings: probe.landings, sightings: sightings,
                                 titles: probe.titles)
      end

      def unchanged(was)
        say "  nothing has changed since #{was.captured_at}"
        @context.result.pass('acceptance', 'the store matches its baseline')
      end

      def record(drift)
        regression = Checks::Baseline.regression?(drift)
        say format('  %<label>-11s %<subject>-26s %<was>s -> %<now>s',
                   label: regression ? 'REGRESSION' : 'changed', subject: drift.subject,
                   was: drift.was, now: drift.now)
        description = "#{drift.subject} matches the baseline"
        return @context.result.pass('acceptance', description) unless regression

        @context.result.fail('acceptance', description, "was #{drift.was}, now #{drift.now}")
      end

      def say(message)
        @output.puts(message)
      end
    end
  end
end
