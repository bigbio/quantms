#!/bin/bash

# Find all .nf files in the modules directory that contain a conda directive
find modules -name "*.nf" -type f -exec grep -l "^\s*conda\s\+" {} \; | while read file; do
  echo "Updating $file"
  # Replace the conda line with a comment
  sed -i 's/^\s*conda\s\+".*"$/    \/\/ Conda is no longer supported/' "$file"
done

echo "All module files updated to remove Conda directives."