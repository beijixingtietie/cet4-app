const fs = require('fs');
const path = require('path');

const jsonPath = path.join(__dirname, 'generated_cards', 'cards_base64.json');
const dartPath = path.join(__dirname, 'cet4_app', 'lib', 'constants', 'app_images.dart');

const data = JSON.parse(fs.readFileSync(jsonPath, 'utf-8'));
let content = fs.readFileSync(dartPath, 'utf-8');

const replacements = {
    'kCardBackgroundWord': data['card_word'],
    'kCardBackgroundWrong': data['card_wrong'],
    'kCardBackgroundExam': data['card_exam'],
    'kCardBackgroundWordbook': data['card_wordbook'],
    'kCardBackgroundAI': data['card_ai'],
};

for (const [constName, newValue] of Object.entries(replacements)) {
    const regex = new RegExp(
        `(const ${constName} = ''')([\\s\\S]*?)(''';)`
    );
    const match = content.match(regex);
    if (match) {
        content = content.replace(regex, `const ${constName} = '''${newValue}''';`);
        console.log('Replaced: ' + constName);
    } else {
        console.log('NOT FOUND: ' + constName);
    }
}

const mockConst = `\nconst kCardBackgroundMock = '''${data['card_mock']}''';\n`;
const aiEndMarker = "const kCardBackgroundAI = '''";
const aiStartIdx = content.indexOf(aiEndMarker);
if (aiStartIdx !== -1) {
    const afterAi = content.indexOf("'''", aiStartIdx + aiEndMarker.length);
    if (afterAi !== -1) {
        const insertPos = afterAi + 3;
        content = content.slice(0, insertPos) + mockConst + content.slice(insertPos);
        console.log('Added: kCardBackgroundMock');
    }
}

fs.writeFileSync(dartPath, content, 'utf-8');
console.log('File written successfully');
