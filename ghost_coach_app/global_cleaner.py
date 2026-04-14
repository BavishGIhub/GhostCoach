import os
import re

def clean_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 1. Remove 'const ' before AppColors access if it's on the same line or part of a list/map
    # This is tricky with regex, but let's try common patterns
    
    # Pattern: const AppColors.something
    new_content = content.replace('const AppColors.', 'AppColors.')
    
    # Pattern: const Icon(..., color: AppColors.something)
    # This is usually 'const WidgetName('
    # We should search for any 'const ' and check if 'AppColors' follows it in the same expression
    # Use a simple heuristic: remove 'const' if AppColors appears before the next ';' or ')' or ']' or ','
    
    lines = new_content.splitlines()
    for i in range(len(lines)):
        line = lines[i]
        if 'const ' in line and 'AppColors' in line:
            # Check if AppColors is inside the scope of this const
            # For simplicity, if both are on the same line, just strip 'const '
            lines[i] = line.replace('const ', '')
            
    final_content = '\n'.join(lines)
    
    if final_content != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(final_content)
        return True
    return False

count = 0
for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            if clean_file(os.path.join(root, file)):
                count += 1

print(f'Cleaned {count} files')
