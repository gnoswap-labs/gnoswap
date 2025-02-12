#!/usr/bin/env ruby
require 'json'
require 'pathname'

class GnoModuleManager
  def initialize(contract_dir)
    @contract_dir = contract_dir
  end

  def extract_module_path(file_path)
    content = File.read(file_path)
    if content =~ /module\s+([\w.\/]+)/
      $1
    end
  rescue
    puts "Error reading file: #{file_path}"
    nil
  end

  def generate_matrix
    matrix = { include: [] }
    
    Dir.glob(File.join(@contract_dir, "**", "gno.mod")).each do |mod_file|
      if module_path = extract_module_path(mod_file)
        next unless module_path.start_with?("gno.land/")

        # Extract relative path after gno.land/
        relative_path = module_path.sub("gno.land/", "")
        folder = "gno/examples/gno.land/#{relative_path}"

        # Generate name from the last component of the path
        name = relative_path.split('/')[-1]
        if relative_path.include?('gov/')
          # Special handling for governance modules to match the format in the example
          name = "gov/#{name}"
        end

        matrix[:include] << {
          name: name,
          folder: folder
        }
      end
    end

    # Sort by folder path for consistency
    matrix[:include].sort_by! { |entry| entry[:folder] }
    matrix
  end
end

if __FILE__ == $0
  contract_dir = ARGV[0] || File.join(Dir.pwd, "contract")

  unless Dir.exist?(contract_dir)
    puts "Error: Contract directory '#{contract_dir}' does not exist"
    exit 1
  end

  manager = GnoModuleManager.new(contract_dir)
  matrix = manager.generate_matrix

  # Output in GitHub Actions matrix format
  puts JSON.generate(matrix)
end
