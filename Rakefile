require 'rubygems'
require 'rake'

task :default => :test

# add spec tasks, if you have rspec installed
begin
  require 'spec/rake/spectask'
 
  SPEC_RUBY_OPTS = [ '-I', File.expand_path('lib') ]
  SPEC_FILES = FileList['test/**/*_spec.rb']
  SPEC_OPTS = ['--color', '--backtrace', '-f n']

  Spec::Rake::SpecTask.new("spec") do |t|
    t.ruby_opts = SPEC_RUBY_OPTS
    t.spec_files = SPEC_FILES
    t.spec_opts = SPEC_OPTS
  end
 
  task :test do
    Rake::Task['spec'].invoke
  end
 
  Spec::Rake::SpecTask.new("rcov_spec") do |t|
    t.spec_files = SPEC_FILES
    t.spec_opts = SPEC_OPTS
    t.rcov = true
    t.rcov_opts = ['--exclude', '^spec,/gems/']
  end
end

