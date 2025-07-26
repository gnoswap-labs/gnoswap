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

  def extract_module_path(file_path)
    begin
      toml = TOML.load_file(file_path)
      toml["module"]
    rescue => e
      puts "Error reading/parsing toml file: #{file_path} - #{e}"
      nil
    end
  end

  # generate matrix for github actions
  #
  # traverse all directories and find gnomod.toml
  # extract module path from gnomod.toml
  # if generate matrix for github actions
  # include:
  # - name: name of the module
  # - folder: folder path of the module
  # - gno: gno version of the module
  def generate_matrix
    matrix = { include: [] }

    # Process contract modules
    Dir.glob(File.join(@contract_dir, "**", "gnomod.toml")).each do |mod_file|
      if module_path = extract_module_path(mod_file)
        next unless module_path.start_with?("gno.land/")

        # Extract relative path after gno.land/
        relative_path = module_path.sub("gno.land/", "")
        folder = "gno/examples/gno.land/#{relative_path}"

        # Generate name by combining the first and last parts of the path
        path_parts = relative_path.split('/')
        name = if path_parts.include?('gov')
          # Special handling for governance modules
          "#{path_parts[0]}/gov/#{path_parts[-1]}"
        else
          "#{path_parts[0]}/#{path_parts[-1]}"
        end

        matrix[:include] << {
          name: name,
          folder: folder
        }
      end
    end

    # Process scenario modules if scenario directory is provided
    if @scenario_dir && Dir.exist?(@scenario_dir)
      Dir.glob(File.join(@scenario_dir, "**", "gnomod.toml")).each do |mod_file|
        if module_path = extract_module_path(mod_file)
          next unless module_path.start_with?("gno.land/")

          # Extract relative path after gno.land/
          relative_path = module_path.sub("gno.land/", "")
          folder = "gno/examples/gno.land/#{relative_path}"

          # Generate name for scenario modules
          path_parts = relative_path.split('/')
          name = if path_parts.include?('scenario')
            # Special handling for scenario modules
            "scenario/#{path_parts[-1]}"
          else
            "#{path_parts[0]}/#{path_parts[-1]}"
          end

          matrix[:include] << {
            name: name,
            folder: folder
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
