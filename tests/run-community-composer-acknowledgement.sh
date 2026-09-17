#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matths-community-ack.XXXXXX")"
cleanup() {
    case "$TEST_DIR" in
        */matths-community-ack.*) rm -rf -- "$TEST_DIR" ;;
        *) echo 'Refusing to clean an unexpected test directory' >&2 ;;
    esac
}
trap cleanup EXIT HUP INT TERM

# Compile the production composer functions verbatim. Only SwiftUI storage and
# transport/disk dependencies are replaced, not the acknowledgement decisions.
node - "$ROOT" "$TEST_DIR" <<'JS'
const fs = require('node:fs');
const [root, out] = process.argv.slice(2);
const source = fs.readFileSync(root + '/Matths/NativeCommunityScreen.swift', 'utf8');
const start = source.indexOf('private struct NativeCommunityComposerSheet: View {');
const end = source.indexOf('private struct NativeCommunityBlockedUsersSheet: View {', start);
if (start < 0 || end < start) throw new Error('Production composer boundary changed');
const composer = source.slice(start, end);
function between(text, a, b) {
    const i = text.indexOf(a), j = text.indexOf(b, i);
    if (i < 0 || j < i) throw new Error('Production boundary changed: ' + a);
    return text.slice(i, j);
}
function block(text, marker) {
    const start = text.indexOf(marker);
    if (start < 0) throw new Error('Production member missing: ' + marker);
    const open = text.indexOf('{', start);
    let depth = 0, string = false, escaped = false, comment = false, multiline = 0;
    for (let i = open; i < text.length; i++) {
        const c = text[i], next = text[i + 1];
        if (comment) { if (c === '\n') comment = false; continue; }
        if (multiline) {
            if (c === '/' && next === '*') { multiline++; i++; }
            else if (c === '*' && next === '/') { multiline--; i++; }
            continue;
        }
        if (string) {
            if (escaped) escaped = false;
            else if (c === '\\') escaped = true;
            else if (c === '"') string = false;
            continue;
        }
        if (c === '/' && next === '/') { comment = true; i++; continue; }
        if (c === '/' && next === '*') { multiline = 1; i++; continue; }
        if (c === '"') { string = true; continue; }
        if (c === '{') depth++;
        if (c === '}' && --depth === 0) return text.slice(start, i + 1);
    }
    throw new Error('Unterminated production member: ' + marker);
}
const storage = between(composer, '    let initialBoard:', '    init(initialBoard:')
    .replace(/@State /g, '');
const members = [
    '    private var valid:',
    '    private var ownsDraft:',
    '    private var draftFields:',
    '    @discardableResult private func saveDraft()',
    '    @MainActor private func save() async',
    '    @MainActor private func finishAcknowledgedSave() async',
    '    private func cleanup()'
].map(marker => block(composer, marker)).join('\n');
// The UI must not offer a new POST or destructive dismissal after success while
// the still-visible local draft needs recovery. These checks complement, not
// replace, the executable control-flow cases below.
for (const contract of [
    '.disabled(completionFinalized)',
    '.interactiveDismissDisabled(isSaving || isImporting || acknowledgedSubmission != nil)',
    'else if saveDraft() { dismiss() }',
    'acknowledgedSubmission == nil && (!valid',
    'if acknowledgedSubmission != nil { Task { await save() } }'
]) if (!composer.includes(contract)) throw new Error('Acknowledgement UI recovery gate missing: ' + contract);

const draft = fs.readFileSync(root + '/Matths/NativeServiceDraft.swift', 'utf8');
fs.writeFileSync(out + '/draft.swift', draft.slice(0, draft.indexOf('enum NativeServiceDraftDisk {')));
fs.writeFileSync(out + '/flow.swift', `import Foundation
@MainActor final class CommunityComposerHarness {
    let store: AppStore
${storage}
    init(store: AppStore, board: String = "school", onCreated: @escaping (ServerAPI.CommunityPost, String) -> Void) {
        self.store = store
        self.initialBoard = board
        self.board = board
        self.onCreated = onCreated
        owner = store.captureAccountSessionBoundary()
        draft = NativeServiceDraft(slot: accountSlot, resource: "community-composer")
        access = .init(remainingPosts: 5, canUploadFiles: true)
        isLoading = false
    }
${members}
    func seed(title: String = "원본 제목", content: String = "원본 내용", files: [URL] = []) {
        self.title = title; self.content = content; self.files = files
        originalNames = Dictionary(uniqueKeysWithValues: files.map { ($0.lastPathComponent, "원본-" + $0.lastPathComponent) })
        precondition(saveDraft(), "Synthetic initial draft must be durable")
    }
    func edit(board: String? = nil, title: String? = nil, content: String? = nil, anonymous: Bool? = nil) {
        if let board { self.board = board }; if let title { self.title = title }
        if let content { self.content = content }; if let anonymous { self.anonymous = anonymous }
    }
    func replaceFilesForQueuedEvent(_ value: [URL]) {
        files = value
        originalNames = Dictionary(uniqueKeysWithValues: value.map { ($0.lastPathComponent, $0.lastPathComponent) })
    }
    // Deliberately isolate the attachment-array guard: even originalNames must
    // remain unchanged so draftFields equality cannot make the case pass.
    func replaceOnlyAttachmentListForQueuedEvent(_ value: [URL]) { files = value }
    func denyNewPosts() { access = .init(remainingPosts: 0, canUploadFiles: false) }
    func saveForTest() async { await save() }
    func finishForTest() async { await finishAcknowledgedSave() }
    @discardableResult func persistForTest() -> Bool { saveDraft() }
    var currentFields: [String: String] { draftFields }
    var currentFiles: [URL] { files }
    var currentDraft: NativeServiceDraft? { draft }
    var hasAcknowledgement: Bool { acknowledgedSubmission != nil }
    var finalized: Bool { completionFinalized }
    var saving: Bool { isSaving }
    var error: String? { errorMessage }
}
`);
JS

xcrun swiftc -swift-version 5 "$TEST_DIR/draft.swift" "$TEST_DIR/flow.swift" \
    "$ROOT/tests/CommunityComposerAcknowledgementCases.swift" -o "$TEST_DIR/cases"
"$TEST_DIR/cases"

# Optional negative control: reintroduce disk-only acknowledgement decisions in
# the generated scratch source, never in the product. The regression suite must
# fail specifically on preserving the newer unsent draft.
if [ "${COMMUNITY_COMPOSER_MUTATION_CHECK:-0}" = "1" ]; then
    node - "$TEST_DIR" <<'JS'
const fs = require('node:fs');
const dir = process.argv[2];
const source = fs.readFileSync(dir + '/flow.swift', 'utf8');
const original = 'let unchanged = currentFields == acknowledged.fields && currentAttachments == acknowledged.attachments';
if (!source.includes(original)) throw new Error('RAM comparison mutation target changed');
fs.writeFileSync(dir + '/mutant.swift', source.replace(original, 'let unchanged = true // negative control: ignore later RAM edits'));
fs.writeFileSync(dir + '/mutant-attachments.swift', source.replace(original, 'let unchanged = currentFields == acknowledged.fields // negative control: ignore attachment-array edits'));
JS
    xcrun swiftc -swift-version 5 "$TEST_DIR/draft.swift" "$TEST_DIR/mutant.swift" \
        "$ROOT/tests/CommunityComposerAcknowledgementCases.swift" -o "$TEST_DIR/mutant-cases"
    if "$TEST_DIR/mutant-cases" > "$TEST_DIR/mutant.log" 2>&1; then
        echo 'FAIL: disk-only acknowledgement mutation escaped the regression suite' >&2
        exit 1
    fi
    if ! grep -Fq 'FAIL: latest draft and selected board are durable before close' "$TEST_DIR/mutant.log"; then
        sed -n '1,30p' "$TEST_DIR/mutant.log" >&2
        echo 'FAIL: mutation stopped for an unexpected reason' >&2
        exit 1
    fi
    echo 'Community composer negative control: disk-only RAM-loss regression detected PASS.'

    xcrun swiftc -swift-version 5 "$TEST_DIR/draft.swift" "$TEST_DIR/mutant-attachments.swift" \
        "$ROOT/tests/CommunityComposerAcknowledgementCases.swift" -o "$TEST_DIR/mutant-attachment-cases"
    if "$TEST_DIR/mutant-attachment-cases" > "$TEST_DIR/mutant-attachments.log" 2>&1; then
        echo 'FAIL: missing attachment comparison escaped the regression suite' >&2
        exit 1
    fi
    if ! grep -Fq 'FAIL: attachment-only local retry persists exact new attachment list' "$TEST_DIR/mutant-attachments.log"; then
        sed -n '1,30p' "$TEST_DIR/mutant-attachments.log" >&2
        echo 'FAIL: attachment mutation stopped for an unexpected reason' >&2
        exit 1
    fi
    echo 'Community composer negative control: attachment-only loss regression detected PASS.'
fi
