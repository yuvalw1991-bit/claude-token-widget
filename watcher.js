'use strict';

const fs   = require('fs');
const path = require('path');
const os   = require('os');

const PROJECTS_DIR = path.join(os.homedir(), '.claude', 'projects');
const DATA_FILE    = path.join(os.tmpdir(), 'claude_tokens.json');
const MAX_TOKENS   = 200000;
const POLL_MS      = 800;
const TAIL_BYTES   = 12288;
const MAX_FILE_MB  = 50;   // skip files larger than this

// State
let lastFile   = '';
let lastSize   = 0;
let lastTokens = -1;

// Resolve symlinks and verify path is inside PROJECTS_DIR
function isSafePath(filePath) {
    try {
        const real    = fs.realpathSync(filePath);
        const realDir = fs.realpathSync(PROJECTS_DIR);
        return real.startsWith(realDir + path.sep) || real.startsWith(realDir + '/');
    } catch {
        return false;
    }
}

// Find the most recently modified .jsonl session file
function findLatestSession() {
    let bestFile = null, bestMs = 0;

    function scan(dir, depth) {
        if (depth > 3) return;
        let entries;
        try { entries = fs.readdirSync(dir, { withFileTypes: true }); }
        catch { return; }

        for (const e of entries) {
            const full = path.join(dir, e.name);
            if (e.isDirectory() && !e.isSymbolicLink()) {
                scan(full, depth + 1);
            } else if (e.name.endsWith('.jsonl') && !e.isSymbolicLink()) {
                try {
                    const st = fs.statSync(full);
                    if (st.mtimeMs > bestMs) {
                        bestMs   = st.mtimeMs;
                        bestFile = { path: full, mtime: st.mtimeMs, size: st.size };
                    }
                } catch { /* skip unreadable */ }
            }
        }
    }

    scan(PROJECTS_DIR, 0);
    return bestFile;
}

// Read tail of file and extract latest token usage
function extractTokens(filePath, fileSize) {
    // Guard: skip unreasonably large files
    if (fileSize > MAX_FILE_MB * 1024 * 1024) return null;

    // Guard: path must be within PROJECTS_DIR (no symlink escape)
    if (!isSafePath(filePath)) return null;

    try {
        const readLen = Math.min(TAIL_BYTES, fileSize);
        const buf = Buffer.alloc(readLen);
        const fd  = fs.openSync(filePath, 'r');
        fs.readSync(fd, buf, 0, readLen, fileSize - readLen);
        fs.closeSync(fd);

        const lines = buf.toString('utf8').split('\n');

        for (let i = lines.length - 1; i >= 0; i--) {
            const line = lines[i].trim();
            if (!line.includes('input_tokens')) continue;

            try {
                const entry = JSON.parse(line);
                const usage = entry?.message?.usage ?? entry?.usage;
                if (!usage) continue;

                const total =
                    (usage.input_tokens                || 0) +
                    (usage.cache_creation_input_tokens || 0) +
                    (usage.cache_read_input_tokens     || 0);

                if (total > 0) return total;
            } catch { /* partial line at chunk boundary */ }
        }
    } catch { /* file read error */ }
    return null;
}

// Write token count to widget data file
function writeData(tokens) {
    try {
        fs.writeFileSync(DATA_FILE, JSON.stringify({ tokens, max: MAX_TOKENS }), 'utf8');
    } catch { /* ignore write errors */ }
}

// Main poll loop
function poll() {
    const session = findLatestSession();
    if (!session) return;

    const { path: filePath, size } = session;

    if (filePath === lastFile && size === lastSize) return;

    const tokens = extractTokens(filePath, size);
    if (tokens === null) return;

    lastFile = filePath;
    lastSize = size;

    if (tokens !== lastTokens) {
        lastTokens = tokens;
        writeData(tokens);
    }
}

// Startup check
if (!fs.existsSync(PROJECTS_DIR)) {
    process.stderr.write('Error: Claude sessions directory not found: ' + PROJECTS_DIR + '\n');
    process.exit(1);
}

// One-shot mode (manual refresh from widget)
if (process.argv.includes('--once')) {
    lastFile = ''; lastSize = 0;
    poll();
    process.exit(0);
}

// Continuous polling mode
poll();
setInterval(poll, POLL_MS);
