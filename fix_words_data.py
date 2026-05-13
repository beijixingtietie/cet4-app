import json

# 读取损坏的单词数据文件
with open('/workspace/cet4_app/assets/data/words.json', 'r', encoding='utf-8') as f:
    words = json.load(f)

# 修复每个单词数据
for word in words:
    # 检查 type 字段是否包含中文字符
    type_field = word.get('type', '')
    meaning_field = word.get('meaning', '')
    
    # 如果 type 包含中文，需要分离出来加到 meaning 中
    chinese_in_type = []
    clean_type = []
    
    for char in type_field:
        if '\u4e00' <= char <= '\u9fff':
            chinese_in_type.append(char)
        else:
            clean_type.append(char)
    
    if chinese_in_type:
        # 把 type 里的中文加到 meaning 开头
        word['meaning'] = ''.join(chinese_in_type) + meaning_field
        word['type'] = ''.join(clean_type)
    
    # 清理 type，确保只包含有效的词性缩写
    word['type'] = word['type'].strip()
    # 确保 type 以句点结尾（如 adj.
    if word['type'] and not word['type'].endswith('.') and len(word['type']) <= 5 and word['type'].isalpha():
        word['type'] = word['type'] + '.'

# 保存修复后的数据
with open('/workspace/cet4_app/assets/data/words.json', 'w', encoding='utf-8') as f:
    json.dump(words, f, ensure_ascii=False, indent=2)

print(f'成功修复了 {len(words)} 个单词数据')
