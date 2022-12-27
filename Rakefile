require "bundler/gem_tasks"
require "rake/testtask"
require "rubycritic/rake_task"

task default: :test

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = false
end

Rake::TestTask.new(:warn) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

RubyCritic::RakeTask.new(:crit) do |t|
  t.paths = FileList["lib/*.rb",
                     "lib/*/*.rb"]
  t.options = "--no-browser"
end
