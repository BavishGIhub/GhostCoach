import json

log_path = r'C:\Users\Haris\.gemini\antigravity\brain\208bdc19-f67a-447c-a820-bebccaccc903\.system_generated\steps\3690\output.txt'
with open(log_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

for line in lines:
    try:
        data = json.loads(line)
        if data.get('code') in ('invalid_constant', 'non_constant_list_element', 'non_constant_map_key', 'missing_return'):
            uri = data['uri'].split('/')[-1]
            print(f\"{uri}:{data['range']['start']['line']+1} {data['code']}\")
    except:
        pass
