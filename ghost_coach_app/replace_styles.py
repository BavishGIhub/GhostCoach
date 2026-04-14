import os
import re

def update_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original = content
    
    # ensure import
    if 'import \'../../../core/theme/app_colors.dart\';' in content and 'import \'../../../core/theme/app_text_styles.dart\';' not in content:
        content = content.replace("import '../../../core/theme/app_colors.dart';", "import '../../../core/theme/app_colors.dart';\nimport '../../../core/theme/app_text_styles.dart';")
    if 'import \'../../core/theme/app_colors.dart\';' in content and 'import \'../../core/theme/app_text_styles.dart\';' not in content:
        content = content.replace("import '../../core/theme/app_colors.dart';", "import '../../core/theme/app_colors.dart';\nimport '../../core/theme/app_text_styles.dart';")

    # App bar titles
    content = re.sub(
        r"style:\s*const\s*TextStyle\([^)]*fontFamily:\s*'Space Grotesk'[^)]*\)",
        r"style: AppTextStyles.brandSmall",
        content
    )
    content = re.sub(
        r"style:\s*TextStyle\([^)]*fontFamily:\s*'Space Grotesk'[^)]*\)",
        r"style: AppTextStyles.brandSmall",
        content
    )

    if original != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Updated {filepath}")

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            update_file(filepath)
