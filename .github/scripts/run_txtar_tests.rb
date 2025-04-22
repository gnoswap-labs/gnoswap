#!/usr/bin/env ruby
require 'optparse'
require 'pathname'
require 'fileutils'
require 'open3'

class TxtarTestRunner
  def initialize(source_dir, gno_dir)
    @source_dir = source_dir
    @gno_dir = gno_dir
    @integration_dir = File.join(gno_dir, "gno.land/pkg/integration/testdata")
    @test_dir = File.join(gno_dir, "gno.land/pkg/integration")
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

  def copy_txtar_files
    puts "Copying txtar files to integration test directory"
    FileUtils.mkdir_p(@integration_dir)
    
    # Find all .txtar files in the source directory
    txtar_files = Dir.glob(File.join(@source_dir, "**", "*.txtar"))
    
    txtar_files.each do |file|
      dest = File.join(@integration_dir, File.basename(file))
      
      # Skip if source and destination are the same file
      next if File.identical?(file, dest)
      
      puts "Copying #{file} to #{dest}"
      FileUtils.cp(file, dest)
    end

    txtar_files.map { |f| File.basename(f, ".txtar") }
  end

  def run_txtar_tests(patterns)
    return if patterns.empty?

    puts "Running txtar tests"
    pattern_arg = patterns.join("|")
    
    Dir.chdir(@test_dir) do
      run_command("go test -v . -run Testdata")
    end
  end

  def run_all
    patterns = copy_txtar_files
    run_txtar_tests(patterns)
  end
end

if __FILE__ == $0
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: run_txtar_tests.rb [options]"

    opts.on("-s", "--source-dir DIR", "Source directory containing txtar files") do |s|
      options[:source_dir] = s
    end

    opts.on("-g", "--gno-dir DIR", "Gno root directory") do |g|
      options[:gno_dir] = g
    end

    opts.on("-h", "--help", "Show this help message") do
      puts opts
      exit
    end
  end.parse!

  if options[:source_dir].nil? || options[:gno_dir].nil?
    puts "Error: Please provide both source directory and gno directory"
    exit 1
  end

  runner = TxtarTestRunner.new(options[:source_dir], options[:gno_dir])
  runner.run_all
end 