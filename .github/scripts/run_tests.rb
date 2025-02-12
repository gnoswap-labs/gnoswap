#!/usr/bin/env ruby
require 'optparse'
require 'pathname'
require 'fileutils'
require 'open3'
require 'json'

class TestRunner
  CACHE_FILE = '.test-cache.json'

  def initialize(folder, root_dir = nil, cache_file = CACHE_FILE)
    @folder = folder
    @root_dir = root_dir || "/home/runner/work/gnoswap/gnoswap/gno"
    @cache_file = cache_file
    @cache = load_cache
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

  def has_tests?
    has_unit_tests = !Dir.glob("./#{@folder}/*_test.gno").empty?
    has_gnoa_tests = !Dir.glob("./#{@folder}/*_test.gnoA").empty?
    has_unit_tests || has_gnoa_tests
  end

  def run_unit_tests
    puts "Running unit tests for #{@folder}"
    run_command("gno test ./#{@folder} -root-dir #{@root_dir} -v")
  end

  def remove_test_files
    puts "Removing temporary test files"
    Dir.glob("./#{@folder}/*_test.gno").each do |file|
      next if File.basename(file) == '_helper_test.gno'
      puts "Removing #{file}"
      File.delete(file)
    end
  end

  def run_gnoa_tests
    Dir.chdir("./#{@folder}") do
      gnoa_files = Dir.glob('*_test.gnoA')

      if gnoa_files.empty?
        return
      end

      gnoa_files.each do |file|
        base = file.sub(/\.gnoA$/, '')
        gno_file = "#{base}.gno"

        FileUtils.mv(file, gno_file)
        begin
          run_command("gno test . -root-dir #{@root_dir} -v")
        ensure
          FileUtils.mv(gno_file, file)
        end
      end
    end
  end

  def load_cache
    if File.exist?(@cache_file)
      JSON.parse(File.read(@cache_file))
    else
      {}
    end
  end

  def save_cache
    File.write(@cache_file, JSON.pretty_generate(@cache))
  end

  def update_cache(has_tests)
    @cache[@folder] = {
      'has_tests' => has_tests,
      'last_checked' => Time.now.iso8601
    }
    save_cache
  end

  def cached_has_tests?
    return nil unless @cache[@folder]
    @cache[@folder]['has_tests']
  end

  def run_all
    cached_result = cached_has_tests?

    if cached_result == false
      puts "Skipping #{@folder} - No tests found (cached result)"
      return
    end

    tests_exist = has_tests?
    update_cache(tests_exist)

    if !tests_exist
      puts "No tests found in #{@folder}"
      return
    end

    run_unit_tests
    remove_test_files
    run_gnoa_tests
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

    opts.on("-c", "--cache-file FILE", "Cache file path") do |c|
      options[:cache_file] = c
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

  runner = TestRunner.new(
    options[:folder], 
    options[:root_dir],
    options[:cache_file]
  )
  runner.run_all
end