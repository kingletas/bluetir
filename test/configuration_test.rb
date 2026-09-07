# frozen_string_literal: true

require 'test_helper'

class ConfigurationTest < Minitest::Test
  def test_it_reads_a_complete_configuration
    in_config_dir do |path|
      config = Bluetir::Configuration.load(path)

      assert_equal 'https://store.test', config.base_url
      assert_equal 1, config.runs
      assert_equal 30, config.timeout
    end
  end

  def test_it_strips_the_trailing_slash_from_the_base_url
    in_config_dir do |path|
      assert_equal 'https://store.test', Bluetir::Configuration.load(path).base_url
    end
  end

  def test_a_missing_file_says_which_file
    error = assert_raises(Bluetir::ConfigurationError) do
      Bluetir::Configuration.load('/nowhere/bluetir.yml')
    end

    assert_match(%r{/nowhere/bluetir.yml}, error.message)
  end

  def test_it_names_every_missing_required_key
    Dir.mktmpdir do |dir|
      path = ConfigFixture.write(dir, 'bluetir.yml' => "runs: 2\n")
      error = assert_raises(Bluetir::ConfigurationError) { Bluetir::Configuration.load(path) }

      assert_match(/base_url/, error.message)
      assert_match(/storefront/, error.message)
    end
  end

  def test_it_refuses_ruby_object_tags_in_yaml
    Dir.mktmpdir do |dir|
      path = ConfigFixture.write(dir, 'bluetir.yml' => "base_url: x\nstorefront: !ruby/symbol foo\n")

      assert_raises(Psych::DisallowedClass) { Bluetir::Configuration.load(path) }
    end
  end

  def test_overrides_replace_only_what_they_are_given
    in_config_dir do |path|
      config = Bluetir::Configuration.load(path).override(runs: 5)

      assert_equal 5, config.runs
      assert_equal 'https://store.test', config.base_url
    end
  end

  def test_it_resolves_paths_against_the_config_file
    in_config_dir do |path|
      config = Bluetir::Configuration.load(path)

      assert_equal 'Test store', config.storefront.name
      assert_equal 1, config.orders['products'].size
    end
  end

  private

  def in_config_dir
    Dir.mktmpdir do |dir|
      path = ConfigFixture.write(dir,
                                 'bluetir.yml' => ConfigFixture.config,
                                 'storefronts/test.yml' => ConfigFixture.storefront,
                                 'orders/test.yml' => ConfigFixture.orders)
      yield path
    end
  end
end
