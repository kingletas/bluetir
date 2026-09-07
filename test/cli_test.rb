# frozen_string_literal: true

require 'test_helper'

class CLITest < Minitest::Test
  def test_a_dry_run_describes_the_plan_and_succeeds
    in_config_dir do |path|
      out = StringIO.new
      status = Bluetir::CLI.new(['-n', '-c', path.to_s], output: out).run

      assert_equal 0, status
      assert_match(%r{store:\s+https://store\.test}, out.string)
      assert_match(/products:\s+1/, out.string)
    end
  end

  def test_a_dry_run_honours_the_base_url_override
    in_config_dir do |path|
      out = StringIO.new
      Bluetir::CLI.new(['-n', '-c', path.to_s, '-b', 'https://other.test/'], output: out).run

      assert_match(%r{https://other\.test$}, out.string.lines.grep(/store:/).first.strip)
    end
  end

  def test_a_broken_configuration_exits_non_zero_and_says_why
    err = StringIO.new
    status = Bluetir::CLI.new(['-c', '/nowhere.yml'], output: StringIO.new, error: err).run

    assert_equal 1, status
    assert_match(/configuration file not found/, err.string)
  end

  def test_it_refuses_a_mode_it_does_not_have
    err = StringIO.new
    assert_raises(SystemExit) do
      Bluetir::CLI.new(['-m', 'wombat'], output: StringIO.new, error: err).run
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
