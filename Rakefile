# frozen_string_literal: true

require 'rake/testtask'
require 'rubocop/rake_task'

# Globbed rather than listed, so a new subdirectory of tests runs without
# anyone remembering to add it here.
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib' << 'test'
  t.test_files = FileList['test/**/*_test.rb'].exclude('test/integration/*_test.rb')
  t.warning = false
end

# Kept out of the default suite so a commit never waits on a browser.
Rake::TestTask.new('test:browser') do |t|
  t.libs << 'lib' << 'test'
  t.test_files = FileList['test/integration/*_test.rb']
  t.warning = false
end

RuboCop::RakeTask.new(:lint)

task check: %i[lint test]
task default: :check
