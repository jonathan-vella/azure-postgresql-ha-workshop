#!/usr/bin/env python3
"""Fix indentation in LoadGenerator.csx for dotnet-script compatibility"""

import re

script_path = r'c:\Repos\azure-postgresql-ha-workshop\scripts\LoadGenerator.csx'

print(f"📝 Reading {script_path}...")
with open(script_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

print(f"📊 Total lines: {len(lines)}")

output = []
inside_main = False
inside_worker = False
inside_monitor = False
indent_stack = 0

for i, line in enumerate(lines):
    line_num = i + 1
    stripped = line.lstrip()
    
    # Detect Main function start
    if re.match(r'^async Task<int> Main\(\)', stripped):
        inside_main = True
        indent_stack = 0
        output.append(line)
        continue
    
    # Detect Main function end
    if stripped.startswith('} // End of Main()'):
        inside_main = False
        output.append(line)
        continue
    
    # Before Main or after Main - keep as is
    if not inside_main:
        output.append(line)
        continue
    
    # Inside Main - ensure proper indentation
    # Empty lines - keep as is
    if not stripped:
        output.append(line)
        continue
    
    # Calculate needed indent based on braces
    open_braces = line.count('{')
    close_braces = line.count('}')
    
    # Determine indent level
    current_indent = len(line) - len(stripped)
    
    # If line starts with }, reduce indent first
    if stripped.startswith('}'):
        indent_stack = max(0, indent_stack - 4)
    
    # Apply indent (minimum 4 spaces inside Main)
    needed_indent = 4 + indent_stack
    output.append(' ' * needed_indent + stripped)
    
    # After writing line, adjust stack for next line
    if not stripped.startswith('}'):
        indent_stack += (open_braces * 4)
    indent_stack -= (close_braces * 4)
    indent_stack = max(0, indent_stack)

# Write back
output_text = ''.join(output)
with open(script_path, 'w', encoding='utf-8', newline='') as f:
    f.write(output_text)

print(f"✅ Indentation fixed! Lines processed: {len(lines)}")
