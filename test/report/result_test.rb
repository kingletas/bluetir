# frozen_string_literal: true

require 'test_helper'

class ResultTest < Minitest::Test
  def setup
    @result = Bluetir::Report::Result.new
  end

  def test_a_run_with_no_checks_has_not_passed
    refute_predicate @result, :passed?
    assert_equal 'no checks ran, so nothing was proven', @result.summary
  end

  def test_a_run_with_only_passing_checks_has_passed
    @result.pass('cart', 'added a product')

    assert_predicate @result, :passed?
    assert_equal 0, @result.failed
  end

  def test_one_failure_fails_the_run
    @result.pass('cart', 'added a product')
    @result.fail('success', 'the order was placed', 'the page never said so')

    refute_predicate @result, :passed?
    assert_equal 1, @result.failed
    assert_equal 2, @result.total
  end

  def test_failure_lines_name_the_section_and_the_reason
    @result.fail('success', 'the order was placed', 'the page never said so')

    assert_equal ['success: the order was placed — the page never said so'], @result.failure_lines
  end
end
