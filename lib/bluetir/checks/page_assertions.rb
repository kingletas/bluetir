# frozen_string_literal: true

module Bluetir
  module Checks
    # Checks that each page carries the text it is supposed to carry.
    #
    # Matching ignores case, and that is not laziness. A theme that sets
    # text-transform: uppercase makes the browser report IN STOCK for markup that
    # says "In stock", so an expectation written by reading the page source fails
    # against the rendered page. Case is almost never the thing under test here,
    # and a rule that fails for a reason nobody can see is the one that gets
    # switched off wholesale.
    #
    # A section with no entry here runs no assertions and records nothing, which is the
    # quiet case. An assertions file that parses to no expectations at all is refused,
    # because a file that can never fail looks exactly like a file that always passes.
    class PageAssertions
      # How long a string gets to arrive before it is called missing.
      #
      # A storefront that renders its cart in JavaScript puts the text on the page
      # after the document is done, so checking once and immediately fails on
      # timing rather than on content — and it fails intermittently, which is
      # worse than failing. Only a string that is NOT there costs this wait, so a
      # passing run is not slowed by it — but a test of the missing case pays it
      # every time, which is why the caller can set it.
      ARRIVAL_TIMEOUT = 10

      def initialize(data, screenshots: nil, arrival_timeout: ARRIVAL_TIMEOUT)
        @sections = normalise(data || {})
        @screenshots = screenshots
        @arrival_timeout = arrival_timeout
      end

      def sections
        @sections.keys
      end

      def expectations
        @sections.values.flatten(1).sum { |entry| entry[:expect].size }
      end

      def configured?
        expectations.positive?
      end

      def summary
        "#{expectations} expectations over #{sections.size} sections"
      end

      # Checks the page currently loaded against the expectations for +section+.
      #
      # Only the entries with no url of their own. An entry that names a url is
      # about THAT page, and a flow reaching this section is not necessarily on
      # it — a shopper buying three products visits three product pages, and
      # asserting the first one's name on all three is a failure that says nothing
      # about the store.
      def verify(browser, section, result)
        entries = wherever_the_flow_is(@sections[section.to_s])
        return if entries.empty?

        @screenshots&.capture(browser, section)
        entries.each do |entry|
          entry[:expect].each { |expected| record(result, section, expected, browser) }
        end
      end

      # Visits every url named in the assertions file and checks the page it lands on.
      #
      # An entry with no `url` key is checked in place by whichever flow reaches
      # that page. Sweeping it would load the home page and test it for text that
      # only ever appears somewhere else — a failure that says nothing.
      #
      # `url: ""` is not the same thing: it is the home page, declared.
      def sweep(browser, navigator, result)
        @sections.each do |section, entries|
          entries.reject { |entry| entry[:url].nil? }.each do |entry|
            navigator.go(entry[:url])
            @screenshots&.capture(browser, section)
            entry[:expect].each { |expected| record(result, section, expected, browser) }
          end
        end
      end

      private

      def wherever_the_flow_is(entries)
        Array(entries).select { |entry| entry[:url].nil? }
      end

      def record(result, section, expected, browser)
        if arrives?(browser, expected)
          result.pass(section, "page contains #{expected.inspect}")
        else
          result.fail(section, "page contains #{expected.inspect}",
                      "it was not on the page within #{ARRIVAL_TIMEOUT}s" \
                      "#{on_page(browser)}#{what_was_there(browser)}")
        end
      end

      # What the page did say. A missing string and a page that never painted look
      # identical in a report, and they are completely different problems.
      def what_was_there(browser)
        seen = page_text(browser).split("\n").map(&:strip).reject(&:empty?).first(3).join(' / ')
        return ' — the page had no text at all' if seen.empty?

        " — the page said: #{seen[0, 140].inspect}"
      rescue StandardError
        ''
      end

      # An assertion that does not say which page it failed on is a mystery, and
      # the commonest answer is that the browser was somewhere else entirely.
      def on_page(browser)
        " (on #{browser.url})"
      rescue StandardError
        ''
      end

      # Whether the text is there, or turns up shortly.
      def arrives?(browser, expected)
        wanted = expected.downcase
        return true if page_text(browser).downcase.include?(wanted)

        deadline = Time.now + @arrival_timeout
        until Time.now >= deadline
          sleep 0.5
          return true if page_text(browser).downcase.include?(wanted)
        end
        false
      end

      def page_text(browser)
        browser.text
      rescue StandardError => e
        ''.tap { warn "[warn] could not read the page text: #{e.message}" }
      end

      # Accepts both a list of entries and a bare list of strings per section.
      def normalise(data)
        data.each_with_object({}) do |(section, entries), built|
          built[section.to_s] = Array(entries).map { |entry| normalise_entry(entry) }
        end
      end

      def normalise_entry(entry)
        return { url: nil, expect: [entry.to_s] } unless entry.is_a?(Hash)

        { url: entry['url'], expect: Array(entry['expect']).map(&:to_s) }
      end
    end
  end
end
