import json
import re

# 读取单词数据
with open('/workspace/cet4_app/assets/data/words.json', 'r', encoding='utf-8') as f:
    words = json.load(f)

# 完整修复逻辑（根据 offline_wordbank_test.dart 中的正确逻辑）
fixed_count = 0
for word in words:
    type_field = word.get('type', '')
    meaning_field = word.get('meaning', '')
    
    # 寻找 type 中中文的起始位置
    chinese_match = re.search(r'[\u4e00-\u9fff]', type_field)
    if chinese_match:
        split_idx = chinese_match.start()
        trailing = type_field[split_idx:]
        type_field = type_field[:split_idx]
        
        # 把 type 中的中文移到 meaning 开头
        if not meaning_field.startswith(trailing):
            meaning_field = trailing + meaning_field
        fixed_count += 1
    
    # 清理 type
    type_field = re.sub(r'[\.\s]+$', '', type_field).strip()
    # 移除 type 中残留的中文分号
    type_field = type_field.replace('；', '')
    type_field = type_field.strip()
    
    # 如果 type 不为空且符合条件，确保以点结尾
    if type_field and not type_field.endswith('.') and len(type_field) <= 5 and re.match(r'^[a-z]+(?:\s*/\s*[a-z]+)*$', type_field):
        type_field = type_field + '.'
    
    # 更新单词
    word['type'] = type_field
    word['meaning'] = meaning_field

# 保存修复后的数据
with open('/workspace/cet4_app/assets/data/words.json', 'w', encoding='utf-8') as f:
    json.dump(words, f, ensure_ascii=False, indent=2)

print(f'成功修复了 {fixed_count} 个单词的数据')
