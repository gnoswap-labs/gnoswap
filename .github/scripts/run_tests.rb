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

    # First, find the parent directory containing gnowork.toml
    current_path = Pathname.new(File.expand_path(@folder))
    workspace_root = nil

    while current_path.parent != current_path
      if File.exist?(File.join(current_path, 'gnowork.toml'))
        workspace_root = current_path
        break
      end
      current_path = current_path.parent
    end

    if workspace_root.nil?
      puts "Warning: gnowork.toml not found in any parent directory"
    else
      puts "Found gnowork.toml at: #{workspace_root}"
    end

    # Change to the workspace root (where gnowork.toml is located)
    Dir.chdir(workspace_root || '.') do
      # Calculate relative path from workspace root to the test folder
      folder_path = Pathname.new(File.expand_path(@folder))
      
      # Check if folder_path exists, if not, it might be because we're using relative paths
      if File.exist?(folder_path)
        # folder_path exists as absolute path
        if workspace_root && folder_path.to_s.start_with?(workspace_root.to_s)
          relative_folder = folder_path.relative_path_from(workspace_root).to_s
        else
          relative_folder = @folder
        end
      else
        # folder_path doesn't exist, might be a relative path issue
        if @folder.start_with?('contract/')
          # Remove 'contract/' prefix since we're already in contract directory
          relative_folder = @folder.sub(/^contract\//, '')
        else
          relative_folder = @folder
        end
      end

      # Find both regular test files and filetest files
      test_files = Dir.glob("#{relative_folder}/*_test.gno") + Dir.glob("#{relative_folder}/*_filetest.gno")
        content = File.read(file)
        
        # Check if this is a filetest (has main function)
        # For debug, use this:
        # ruby -e "puts Dir.glob('./tests/scenario/**/*_filetest.gno')"
        if content.include?("func main()")
          puts "Running filetest: #{file}"
          run_command("gno test #{file} -root-dir #{@root_dir}")
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
          run_command("gno test #{file} -root-dir #{@root_dir} -run ^#{test_name}$")
        end
      end
    end
  end

  def remove_test_files
    puts "Removing temporary test files"

    # Find the parent directory containing gnowork.toml
    current_path = Pathname.new(File.expand_path(@folder))
    workspace_root = nil

    while current_path.parent != current_path
      if File.exist?(File.join(current_path, 'gnowork.toml'))
        workspace_root = current_path
        break
      end
      current_path = current_path.parent
    end

    Dir.chdir(workspace_root || '.') do
      # Calculate relative path from workspace root to the test folder
      folder_path = Pathname.new(File.expand_path(@folder))
      
      # If folder_path is under workspace_root, calculate relative path
      # Otherwise, check if @folder starts with 'contract/' and remove it
      if workspace_root && folder_path.to_s.start_with?(workspace_root.to_s)
        relative_folder = folder_path.relative_path_from(workspace_root).to_s
      elsif @folder.start_with?('contract/')
        # Remove 'contract/' prefix since we're already in contract directory
        relative_folder = @folder.sub(/^contract\//, '')
      else
        relative_folder = @folder
      end

      Dir.glob("#{relative_folder}/*_test.gno").each do |file|
        next if File.basename(file) == '_helper_test.gno'
        puts "Removing #{file}"
        File.delete(file)
      end
    end
  end

  def run_all
    run_unit_tests
    remove_test_files
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
