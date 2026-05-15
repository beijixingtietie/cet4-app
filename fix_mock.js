const fs = require('fs');
const path = require('path');

const dartPath = path.join(__dirname, 'cet4_app', 'lib', 'constants', 'app_images.dart');
let content = fs.readFileSync(dartPath, 'utf-8');

content = content.replace(
    "''';\n;\r\n\r\nconst kEmptyStateNoWords",
    "''';\r\n\r\nconst kEmptyStateNoWords"
);

fs.writeFileSync(dartPath, content, 'utf-8');
console.log('Fixed');
