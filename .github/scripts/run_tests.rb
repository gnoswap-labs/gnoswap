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
    
    # Find both regular test files and filetest files
    test_files = Dir.glob("./#{@folder}/*_test.gno") + Dir.glob("./#{@folder}/*_filetest.gno")
    
    test_files.each do |file|
      content = File.read(file)
      
      # Check if this is a filetest (has main function)
      # For debug, use this:
      # ruby -e "puts Dir.glob('./tests/scenario/**/*_filetest.gno')"
      if content.include?("func main()")
        puts "Running filetest: #{file}"
        run_command("gno test #{file} -root-dir #{@root_dir} -v")
        next
      end

      # collect test functions from the file
      # we need to run each test function separately
      # because the gno test environment does not separate its test environment
      # which can cause the invalid test result
      test_names = content.scan(/func (Test\w+)/).flatten
      if test_names.empty?
        puts "No test functions found in #{file}"
        next
      end
      test_names.each do |test_name|
        puts "Running #{test_name} in #{file}"
        run_command("gno test #{file} -root-dir #{@root_dir} -run ^#{test_name}$ -v")
      end
    end
  end

  def remove_test_files
    puts "Removing temporary test files"
    Dir.glob("./#{@folder}/*_test.gno").each do |file|
      next if File.basename(file) == '_helper_test.gno'
      puts "Removing #{file}"
      File.delete(file)
    end
  end

  # TODO (notJoon): remove this function after the gno test has been stabilized.
  def run_gnoa_tests
    puts "Running gnoA tests"
    Dir.chdir("./#{@folder}") do
      gnoa_files = Dir.glob('*_test.gnoA')

      if gnoa_files.empty?
        puts "No gnoA test files found"
        return
      end

      gnoa_files.each do |file|
        puts "Testing #{file}"
        base = file.sub(/\.gnoA$/, '')
        gno_file = "#{base}.gno"

        # Rename .gnoA to .gno
        FileUtils.mv(file, gno_file)

        begin
          run_command("gno test . -root-dir #{@root_dir} -v")
        ensure
          # Always move the file back, even if the test fails
          FileUtils.mv(gno_file, file)
        end
      end
    end
  end

  def run_all
    run_unit_tests
    remove_test_files
    # temporary disable gnoa tests
    # run_gnoa_tests
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
