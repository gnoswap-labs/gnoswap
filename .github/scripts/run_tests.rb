#!/usr/bin/env ruby
require 'optparse'
require 'pathname'
require 'fileutils'
require 'open3'

class TestRunner
  # Same flow as Makefile test: run from gno/examples with package path (e.g. gno.land/r/gnoswap/access)
  def initialize(pkg, root_dir = nil)
    @pkg = pkg
    @root_dir = (root_dir || "/home/runner/work/gnoswap/gnoswap/gno").to_s
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
    puts "Running unit tests for #{@pkg}"

    examples_dir = File.join(@root_dir, "examples")
    unless File.directory?(examples_dir)
      puts "Error: Examples directory #{examples_dir} does not exist (run setup.py -w . first)"
      exit 1
    end

    Dir.chdir(examples_dir) do
      puts "Running tests in: #{Dir.pwd}"
      run_command("gno test -v ./#{@pkg}")
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

    opts.on("-p", "--pkg PKG", "Package path (e.g. gno.land/r/gnoswap/access)") do |p|
      options[:pkg] = p
    end

    opts.on("-r", "--root-dir DIR", "Gno repo root (default: .../gno)") do |r|
      options[:root_dir] = r
    end

    opts.on("-h", "--help", "Show this help message") do
      puts opts
      exit
    end
  end.parse!

  if options[:pkg].nil?
    puts "Error: Please provide a package path with -p or --pkg"
    exit 1
  end

  runner = TestRunner.new(options[:pkg], options[:root_dir])
  runner.run_all
end
