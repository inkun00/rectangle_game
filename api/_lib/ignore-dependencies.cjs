'use strict';

const fs = require('node:fs');
const path = require('node:path');

// Godot must not import server dependencies into its editor cache or game packs.
fs.writeFileSync(path.resolve(__dirname, '../../node_modules/.gdignore'), '');
