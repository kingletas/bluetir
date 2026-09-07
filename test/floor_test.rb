# frozen_string_literal: true

require 'test_helper'
require 'yaml'

# What Ruby version this actually needs, checked rather than claimed.
#
# The gemspec said 3.2 and CI ran a 3.2 leg, so the claim and the test agreed
# with each other and both were wrong: selenium-webdriver requires 3.3, and
# `bundle install` on 3.2 cannot even resolve. A local run that was supposed to
# prove the floor had silently executed on 3.4, because `bundle exec` re-execs
# under the bundler's own interpreter.
#
# These read the metadata instead, so they need no second interpreter and cannot
# be fooled by which one is on PATH.
class FloorTest < Minitest::Test
  def test_no_dependency_needs_a_newer_ruby_than_this_gem_claims
    too_new = locked_specs.reject { |spec| spec.required_ruby_version.satisfied_by?(floor) }
    named = too_new.map { |s| "#{s.name} #{s.version} needs ruby #{s.required_ruby_version}" }

    assert_empty named, "the gemspec claims ruby >= #{floor}, but:"
  end

  # The matrix is the only thing that checks the claim, so the two have to say
  # the same number.
  def test_ci_runs_the_floor_the_gemspec_claims
    lowest = ci_ruby_versions.min_by { |v| Gem::Version.new(v) }

    assert_equal floor.to_s, lowest
  end

  def test_ci_also_runs_something_newer_than_the_floor
    assert_operator ci_ruby_versions.size, :>, 1, 'a matrix of one tests nothing about the range'
  end

  private

  def gemspec
    @gemspec ||= Gem::Specification.load(File.expand_path('../bluetir.gemspec', __dir__))
  end

  def floor
    Gem::Version.new(gemspec.required_ruby_version.requirements.first.last.to_s)
  end

  # Every gem the lockfile pins, as its installed spec. A gem that is not
  # installed is skipped rather than failed: this checks the dependencies this
  # machine actually has, and `bundle install` is what proves the rest.
  def locked_specs
    locked_names.filter_map do |name, version|
      Gem::Specification.find_by_name(name, version)
    rescue Gem::MissingSpecError
      nil
    end
  end

  def locked_names
    lock = File.read(File.expand_path('../Gemfile.lock', __dir__))
    lock.scan(/^ {4}([a-z0-9_-]+) \(([0-9][^)]*)\)$/i).uniq
  end

  def ci_ruby_versions
    workflow = YAML.safe_load_file(File.expand_path('../.github/workflows/ci.yml', __dir__))
    workflow.dig('jobs', 'check', 'strategy', 'matrix', 'ruby').map(&:to_s)
  end
end
