#!/usr/bin/env ruby
require 'optparse'
require 'pathname'
require 'fileutils'
require 'open3'

class TestRunner
  def initialize(folder, root_dir = nil)
    @folder = folder
    @root_dir = root_dir || "/home/runner/work/gnoswap/gnoswap/gno"
  end

  def run_command(command)
    puts "> #{command}"
    stdout, stderr, status = Open3.capture3(command)
    puts stdout unless stdout.empty?
    puts stderr unless stderr.empty?

    unless status.success?
      puts "Error: Command failed with status #{status.exitstatus}"
      exit status.exitstatus
    end
  end

  def run_unit_tests
    puts "Running unit tests for #{@folder}"

    # With gnowork.toml, we can run tests directly from each directory
    # No need to search for workspace root anymore
    test_dir = File.expand_path(@folder)
    
    unless File.directory?(test_dir)
      puts "Error: Directory #{test_dir} does not exist"
      exit 1
    end

    # Change to the test directory
    Dir.chdir(test_dir) do
      puts "Running tests in: #{Dir.pwd}"
      
      # Run gno test -v . to execute all tests in the current directory
      run_command("gno test -v . -root-dir #{@root_dir}")
    end
  end


  def run_all
    run_unit_tests
  end
end

if __FILE__ == $0
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: run_tests.rb [options]"

    opts.on("-f", "--folder FOLDER", "Test folder path") do |f|
      options[:folder] = f
    end

    opts.on("-r", "--root-dir DIR", "Root directory") do |r|
      options[:root_dir] = r
    end

    opts.on("-h", "--help", "Show this help message") do
      puts opts
      exit
    end
  end.parse!

  if options[:folder].nil?
    puts "Error: Please provide a folder path with -f or --folder"
    exit 1
  end

  runner = TestRunner.new(options[:folder], options[:root_dir])
  runner.run_all
end
