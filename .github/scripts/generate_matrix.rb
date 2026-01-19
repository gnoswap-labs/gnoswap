#!/usr/bin/env ruby
require 'json'
require 'pathname'
require 'toml'

# To run locally:
# bundle exec ruby .github/scripts/generate_matrix.rb

class GnoModuleManager
  def initialize(contract_dir, scenario_dir = nil)
    @contract_dir = contract_dir
    @scenario_dir = scenario_dir
  end

  TEST_FILE_PATTERNS = ["*_test.gno", "*_filetest.gno"].freeze

  def extract_module_path(file_path)
    begin
      toml = TOML.load_file(file_path)
      toml["module"]
    rescue => e
      puts "Error reading/parsing toml file: #{file_path} - #{e}"
      nil
    end
  end

  # Generate module name based on path structure
  def generate_module_name(path_parts)
    # Skip 'r' prefix and keep the rest of the path structure
    # r/gnoswap/module_name -> gnoswap/module_name
    # r/gnoswap/v1/module_name -> gnoswap/v1/module_name
    # r/gnoswap/v1/gov/module_name -> gnoswap/v1/gov/module_name
    path_parts[1..-1].join('/')
  end

  def has_test_files?(module_dir)
    TEST_FILE_PATTERNS.any? do |pattern|
      Dir.glob(File.join(module_dir, "**", pattern)).any?
    end
  end

  # generate matrix for github actions
  #
  # traverse all directories and find gnomod.toml
  # with gnowork.toml, we can now run tests directly from each module directory
  # include:
  # - name: name of the module
  # - folder: actual folder path of the module (not the symlinked path)
  def generate_matrix
    matrix = { include: [] }

    # Process contract modules
    Dir.glob(File.join(@contract_dir, "**", "gnomod.toml")).each do |mod_file|
      if module_path = extract_module_path(mod_file)
        next unless module_path.start_with?("gno.land/")

        # Get the directory containing gnomod.toml
        module_dir = File.dirname(mod_file)
        # Skip modules without any test files
        next unless has_test_files?(module_dir)

        # Extract relative path after gno.land/
        relative_path = module_path.sub("gno.land/", "")
        
        # Generate name based on path structure
        path_parts = relative_path.split('/')
        name = generate_module_name(path_parts)

        matrix[:include] << {
          name: name,
          folder: module_dir
        }
      end
    end

    # Process scenario modules if scenario directory is provided
    if @scenario_dir && Dir.exist?(@scenario_dir)
      Dir.glob(File.join(@scenario_dir, "**", "gnomod.toml")).each do |mod_file|
        if module_path = extract_module_path(mod_file)
          next unless module_path.start_with?("gno.land/")

          # Get the directory containing gnomod.toml
          module_dir = File.dirname(mod_file)
          # Skip modules without any test files
          next unless has_test_files?(module_dir)
          
          # Extract relative path after gno.land/
          relative_path = module_path.sub("gno.land/", "")
          
          # Generate name for scenario modules
          path_parts = relative_path.split('/')
          name = if path_parts.include?('scenario')
            # Special handling for scenario modules
            "scenario/#{path_parts[-1]}"
          else
            generate_module_name(path_parts)
          end

          matrix[:include] << {
            name: name,
            folder: module_dir
          }
        end
      end
    end

    # Sort by folder path for consistency
    matrix[:include].sort_by! { |entry| entry[:folder] }
    matrix
  end
end

if __FILE__ == $0
  contract_dir = ARGV[0] || File.join(Dir.pwd, "contract")
  scenario_dir = ARGV[1] || File.join(Dir.pwd, "tests", "scenario")

  unless Dir.exist?(contract_dir)
    puts "Error: Contract directory '#{contract_dir}' does not exist"
    exit 1
  end

  manager = GnoModuleManager.new(contract_dir, scenario_dir)
  matrix = manager.generate_matrix

  # Output in GitHub Actions matrix format
  puts JSON.generate(matrix)
end
