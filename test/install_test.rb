# frozen_string_literal: true

require 'test_helper'
require 'open3'

# `make install` is a claim that a command works. This is the only thing that
# checks it, and it exists because the claim was false: install copied bin/bluetir
# into the prefix, where its `require_relative '../lib/bluetir'` resolved beside
# the prefix rather than beside the checkout. Every test passed, because every
# test ran ./bin/bluetir from the checkout and never the thing being shipped.
class InstallTest < Minitest::Test
  def setup
    @prefix = Dir.mktmpdir('bluetir-prefix')
    @root = File.expand_path('..', __dir__)
  end

  def teardown
    FileUtils.remove_entry(@prefix)
  end

  def test_make_install_puts_a_command_in_the_prefix
    install

    assert File.executable?(File.join(@prefix, 'bluetir')), 'nothing executable was installed'
  end

  # From somewhere else, because the failure only shows outside the checkout.
  def test_the_installed_command_runs_from_anywhere
    install
    out, status = Open3.capture2e(File.join(@prefix, 'bluetir'), '--version', chdir: '/')

    assert_predicate status, :success?, "the installed command failed: #{out}"
    assert_equal Bluetir::VERSION, out.strip
  end

  # The entry point has to set the bundle up itself.
  #
  # Where the gems live decides whether this matters, and on a developer's
  # machine it never does: watir is in the ambient gem environment, so
  # `require "watir"` succeeds however the command was started. A CI runner
  # installs into the project instead, and there the command found nothing —
  # which is how this shipped broken while every local test passed.
  #
  # Asserted against the file rather than by running it, because reproducing
  # the condition means a project-local bundle. **CI is what proves the whole
  # thing works**, on both Ruby versions, and this only catches the mechanism
  # being removed.
  def test_the_entry_point_sets_up_the_bundle_itself
    entry = File.read(File.join(@root, 'bin', 'bluetir'))

    assert_includes entry, 'BUNDLE_GEMFILE'
    assert_includes entry, "require 'bundler/setup'"
  end

  def test_the_installed_command_can_still_find_the_shipped_configuration
    install
    config = File.join(@root, 'etc', 'stores', 'hyva.yml')
    out, status = Open3.capture2e(File.join(@prefix, 'bluetir'), '-n', '-c', config, chdir: '/')

    assert_predicate status, :success?, out
    assert_match(/storefront: Hyvä/, out)
  end

  private

  def install
    out, status = Open3.capture2e('make', '-C', @root, 'install', "PREFIX=#{@prefix}")
    raise "make install failed: #{out}" unless status.success?
  end
end
