# frozen_string_literal: true

require 'fileutils'

module Bluetir
  # Writes screenshots into the configured directory, one subdirectory per section.
  class Screenshots
    def initialize(directory)
      @directory = Pathname.new(directory)
    end

    # Saves a screenshot and returns its path, or nil if the browser could not produce one.
    def capture(browser, section)
      target = @directory.join(section.to_s)
      FileUtils.mkdir_p(target)
      file = target.join("#{section}-#{timestamp}.png")
      browser.screenshot.save(file.to_s)
      file
    rescue StandardError => e
      warn "[warn] could not save a screenshot for #{section}: #{e.message}"
      nil
    end

    private

    def timestamp
      Time.now.strftime('%Y%m%d-%H%M%S-%L')
    end
  end
end
