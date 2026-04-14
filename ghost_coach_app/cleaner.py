import json
import urllib.parse
import os

log_path = r'C:\Users\Haris\.gemini\antigravity\brain\208bdc19-f67a-447c-a820-bebccaccc903\.system_generated\steps\3690\output.txt'
with open(log_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

file_edits = {}
for line in lines:
    try:
        data = json.loads(line)
        if data.get('code') in ('invalid_constant', 'non_constant_list_element', 'non_constant_map_key', 'missing_return'):
            uri = data['uri'].replace('file:///', '')
            uri = urllib.parse.unquote(uri)
            uri = os.path.normpath(uri)
            if uri not in file_edits:
                file_edits[uri] = []
            file_edits[uri].append(data['range'])
    except:
        pass

for filepath, ranges in file_edits.items():
    if not os.path.exists(filepath): continue
    with open(filepath, 'r', encoding='utf-8') as f:
        file_lines = f.readlines()
    
    ranges.sort(key=lambda r: (r['start']['line'], r['start']['character']), reverse=True)
    
    for r in ranges:
        line_idx = r['start']['line']
        start_char = r['start']['character']
        line_str = file_lines[line_idx]
        const_idx = line_str.rfind('const ', 0, start_char + 1)
        if const_idx != -1:
            file_lines[line_idx] = line_str[:const_idx] + line_str[const_idx+6:]
        else:
            file_lines[line_idx] = line_str.replace('const ', '')
            
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(file_lines)
print('Done fixing consts 2!')
