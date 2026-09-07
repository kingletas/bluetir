# frozen_string_literal: true

require 'yaml'

module Bluetir
  # What a store looked like when it was known good, and what has changed since.
  #
  # A baseline is how an acceptance run answers the only question that matters
  # after a deployment: is anything different from the last time this store was
  # working? Comparing against a fixed list of expectations cannot answer that,
  # because it only knows what somebody thought to write down.
  #
  # It is silent when nothing has moved. Everything it prints is a difference.
  class Baseline
    Drift = Data.define(:kind, :subject, :was, :now)

    # A selector that used to resolve and no longer does is the whole point.
    # One that has newly appeared is worth knowing and is not a failure.
    REGRESSIONS = %i[selector_lost page_moved text_lost].freeze

    attr_reader :captured_at, :store, :pages, :selectors, :titles

    # The fragment is stripped from a recorded page. Magento's checkout moves
    # between #shipping and #payment as the customer advances, so keeping it
    # would report a regression every time a run got one step further.
    def self.without_fragment(url)
      url.to_s.sub(/#.*\z/, '')
    end

    def self.capture(store:, landings:, sightings:, titles:)
      new(
        'captured_at' => Time.now.utc.iso8601,
        'store' => store,
        'pages' => landings.to_h { |l| [l.label, without_fragment(l.got)] },
        'titles' => titles,
        'selectors' => sightings.to_h { |s| [s.name, s.pages] }
      )
    end

    def self.load(pathname)
      raise ConfigurationError, "baseline not found: #{pathname}" unless pathname.file?

      new(Configuration.read_yaml(pathname))
    end

    def initialize(data)
      @captured_at = data['captured_at']
      @store = data['store']
      @pages = data['pages'] || {}
      @titles = data['titles'] || {}
      @selectors = data['selectors'] || {}
    end

    def to_yaml
      {
        'captured_at' => @captured_at, 'store' => @store, 'pages' => @pages,
        'titles' => @titles, 'selectors' => @selectors
      }.to_yaml
    end

    def write(pathname)
      pathname.dirname.mkpath
      pathname.write(to_yaml)
      pathname
    end

    def summary
      "#{@selectors.size} selector(s), #{@pages.size} page(s), taken #{@captured_at}"
    end

    # Every way the store now differs from this baseline.
    def drift_from(other)
      compare_pages(other) + compare_titles(other) + compare_selectors(other)
    end

    # Whether a drift is a regression rather than merely a change.
    def self.regression?(drift)
      REGRESSIONS.include?(drift.kind)
    end

    private

    def compare_pages(other)
      @pages.filter_map do |label, was|
        now = other.pages[label]
        next if now == was

        Drift.new(kind: :page_moved, subject: "#{label} page", was: was, now: now || 'did not load')
      end
    end

    def compare_titles(other)
      @titles.filter_map do |label, was|
        now = other.titles[label]
        next if now == was

        Drift.new(kind: :title_changed, subject: "#{label} title", was: was, now: now)
      end
    end

    def compare_selectors(other)
      lost = @selectors.filter_map { |name, was| selector_drift(name, was, other) }
      gained = other.selectors.filter_map do |name, now|
        next if @selectors.key?(name) || now.empty?

        Drift.new(kind: :selector_new, subject: name, was: 'not in the baseline', now: now.join(', '))
      end
      lost + gained
    end

    def selector_drift(name, was, other)
      now = other.selectors[name] || []
      return nil if now.sort == was.sort

      kind = was.any? && now.empty? ? :selector_lost : :selector_moved
      Drift.new(kind: kind, subject: name, was: describe(was), now: describe(now))
    end

    def describe(pages)
      pages.empty? ? 'nowhere' : pages.join(', ')
    end
  end
end
