const fs = require('fs');
const stats = fs.statSync('mort-antigravity-fullstack-revenuecat-ai.zip');
console.log('Zip size in bytes:', stats.size);
