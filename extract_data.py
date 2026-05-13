import fitz, json, re, sys, os

# ============ Extract vocabulary ============
doc = fitz.open(r'D:\BaiduNetdiskDownload\2026年6月英语四级1500核心词.pdf')
words = []
word_id = 1

for page_num in range(doc.page_count):
    text = doc[page_num].get_text()
    lines = text.strip().split('\n')
    for line in lines:
        line = line.strip()
        # Pattern: "123. word [phonetic] type. meaning"
        match = re.match(r'^(\d+)\.\s*(\S+)\s*\[([^\]]+)\]\s*(\S+)\.?\s*(.+)', line)
        if not match:
            # Relaxed pattern
            match = re.match(r'(\d+)[\.\s]+(\S+)\s*\[([^\]]+)\]\s*(\S+?)\.?\s*(.+)', line)
        if match:
            word = match.group(2).strip()
            if len(word) < 2 or len(word) > 30 or re.match(r'^\d+$', word):
                continue
            phonetic_raw = match.group(3).strip()
            phonetic = '/' + phonetic_raw.replace('/', '') + '/'
            pos_type = match.group(4).strip().rstrip('.')
            meaning = match.group(5).strip()
            if len(meaning) > 200:
                continue

            words.append({
                'id': word_id,
                'word': word,
                'phonetic_uk': phonetic,
                'phonetic_us': phonetic,
                'type': pos_type,
                'meaning': meaning,
                'example': '',
                'example_translation': '',
                'collocation': '',
                'level': '高频核心词'
            })
            word_id += 1

doc.close()
print(f'Words extracted: {len(words)}')

# ============ Extract exam questions ============
questions = []
qid = 1
seen_content = set()

for pdf_path, years_label in [
    (r'D:\BaiduNetdiskDownload\四级真题2017-2020一键打印版.pdf', '2017-2020'),
    (r'D:\BaiduNetdiskDownload\四级真题2021-2025.12月一键打印版.pdf', '2021-2025'),
]:
    doc2 = fitz.open(pdf_path)
    total_pages = doc2.page_count

    for page_num in range(total_pages):
        if page_num % 50 == 0:
            print(f'  Processing {years_label}: page {page_num}/{total_pages}, questions: {len(questions)}')

        text = doc2[page_num].get_text()
        if len(text) < 20:
            continue

        # Extract year from page text
        year_match = re.search(r'(20\d{2})年', text[:200])
        year = year_match.group(1) if year_match else years_label[:4]

        # Extract Writing topics
        write_match = re.search(
            r'(?:Directions?\s*:?\s*)?(?:For this part,?\s*)?you are (?:allowed|required|supposed).*?write\s+(?:a(?:n)?|an?|the)\s+.*?([\s\S]{20,300}?)You should write',
            text, re.IGNORECASE
        )
        if write_match:
            topic = write_match.group(1).strip()[:300]
            content = 'Directions: ' + topic
            key = ('写作', content[:80])
            if key not in seen_content:
                seen_content.add(key)
                questions.append({
                    'id': qid, 'type': '写作', 'year': year,
                    'content': content,
                    'answer': '(参考范文请查阅真题解析)',
                    'explanation': f'{year}年6月/12月四级真题写作'
                })
                qid += 1

        # Extract Translation (Chinese text)
        trans_matches = re.finditer(
            r'(?:Translation|翻译|Part\s*IV).*?(?:Directions?\s*:?\s*)?([一-鿿][\s\S]{30,300}?)(?=You have|Part\s*[IV]|Section|Questions?\s*\d+)',
            text
        )
        for m in trans_matches:
            content = m.group(1).strip()
            has_chinese = bool(re.search(r'[一-鿿]', content))
            if has_chinese and len(content) >= 20:
                key = ('翻译', content[:60])
                if key not in seen_content:
                    seen_content.add(key)
                    questions.append({
                        'id': qid, 'type': '翻译', 'year': year,
                        'content': content,
                        'answer': '(参考译文请查阅真题解析)',
                        'explanation': f'{year}年四级真题翻译'
                    })
                    qid += 1

        # Extract Reading Comprehension questions
        q_matches = re.findall(
            r'(\d+)\.\s*(What\s[^?\n]{10,80}\??|Why\s[^?\n]{10,80}\??|How\s[^?\n]{10,80}\??|Which\s[^?\n]{10,80}\??|According\s[^?\n]{10,80}\??|The\s(?:word|phrase|author|passage|writer)[^?\n]{10,80}\??)',
            text
        )
        for num, qtext in q_matches:
            key = ('仔细阅读', qtext[:50])
            if key not in seen_content:
                seen_content.add(key)
                questions.append({
                    'id': qid, 'type': '仔细阅读', 'year': year,
                    'content': qtext.strip(),
                    'passage': '',
                    'options': ['A', 'B', 'C', 'D'],
                    'answer': '(参考答案请查阅真题解析)',
                    'explanation': f'{year}年6月/12月四级真题仔细阅读'
                })
                qid += 1

    doc2.close()
    print(f'{years_label} done. Total questions so far: {len(questions)}')

# Limit to reasonable count while ensuring good coverage
if len(questions) > 100:
    # Keep diverse set: at least some of each type
    by_type = {}
    for q in questions:
        by_type.setdefault(q['type'], []).append(q)
    selected = []
    per_type = max(10, 100 // len(by_type))
    for t, qs in by_type.items():
        selected.extend(qs[:per_type])
    questions = selected[:100]

# Save questions
qpath = r'C:\Users\10713\Desktop\CET4_English\cet4_app\assets\data\questions.json'
with open(qpath, 'w', encoding='utf-8') as f:
    json.dump(questions, f, ensure_ascii=False, indent=2)
print(f'Questions extracted: {len(questions)} → {qpath}')

# Save words
wpath = r'C:\Users\10713\Desktop\CET4_English\cet4_app\assets\data\words.json'
with open(wpath, 'w', encoding='utf-8') as f:
    json.dump(words, f, ensure_ascii=False, indent=2)
print(f'Words saved: {len(words)} → {wpath}')

print('Done!')
