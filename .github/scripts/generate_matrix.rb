#!/usr/bin/env ruby
require 'json'

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
matrix = {
  'include' => folders.map { |f| {
    'name' => f.split('/')[-2..-1].join('/'),  # Get last two parts of path
    'folder' => f
  }}
}

# Output JSON to stdout
puts JSON.generate(matrix)