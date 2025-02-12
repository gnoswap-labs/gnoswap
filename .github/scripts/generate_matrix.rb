#!/usr/bin/env ruby
require 'json'
require 'pathname'

class GnoModule
  def initialize
    @base_path = 'contract'
  end

  def extract_module_path(file_path)
    content = File.read(file_path)
    content.match(/module\s+([\w.\/]+)/)&.captures&.first
  rescue
    nil
  end

  def find_gno_modules
    modules = []
    
    Dir.glob("#{@base_path}/**/*.mod").each do |mod_file|
      next unless File.basename(mod_file) == 'gno.mod'

      module_path = extract_module_path(mod_file)
      next unless module_path&.start_with?('gno.land/')

      dir_path = File.dirname(mod_file)
      relative_path = module_path.sub('gno.land/', '')

      # Determine correct name based on the module path
      name_parts = relative_path.split('/')
      name = if name_parts.size >= 3 && ['p', 'r'].include?(name_parts[0])
        [name_parts[0], name_parts[2]].join('/')
      else
        File.basename(dir_path)
      end

      modules << {
        'name' => name,
        'folder' => "gno/examples/#{module_path}"
      }
    end

    modules
  end

  def generate_matrix
    {
      'include' => find_gno_modules
    }
  end
end

# Generate and output matrix
module_finder = GnoModule.new
matrix = module_finder.generate_matrix
puts JSON.generate(matrix)
