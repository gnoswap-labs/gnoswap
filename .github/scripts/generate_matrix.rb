#!usr/bin/env ruby
# .github/scripts/generate_matrix.rb

require 'json'

# Configuration
BASE_PATH = 'gno/examples/gno.land'
PATTERNS = [
  '*/p/gnoswap/*',
  '*/r/gnoswap/*'
]

# Find all matching directories
folders = Dir.glob("#{BASE_PATH}/**/*")
  .select { |f| File.directory?(f) }
  .select { |f| PATTERNS.any? { |p| File.fnmatch(p, f) } }

# Generate matrix data
matrix = folders.map { |f| {
  'name' => File.basename(f),
  'folder' => f
}}

# Output JSON to stdout
puts JSON.generate(matrix)
