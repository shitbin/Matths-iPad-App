#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/matths-invites.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
python3 - "$root" "$scratch" <<'PY'
from pathlib import Path
import sys
root,out=map(Path,sys.argv[1:])
screen=(root/'Matths/TeacherAcademyScreen.swift').read_text()
api=(root/'Matths/ServerAPI.swift').read_text()
def declaration(source, marker):
    start=source.index(marker); brace=source.index('{', start); depth=0
    for end in range(brace,len(source)):
        if source[end]=='{': depth+=1
        if source[end]=='}':
            depth-=1
            if depth==0: return source[start:end+1]
    raise AssertionError(marker)
methods=[declaration(screen,marker) for marker in ['init(store:', 'private var isMountedOwnerCurrent:', 'var inviteMaxUses:', 'var inviteDraft:', 'var hasInviteDraftChanges:', 'var canUseInvites:', 'func openInviteComposer()', 'func discardInviteDraft()', 'func createInvite()', 'func revoke(', 'private func perform(', 'private func install(']]
# Stored let properties must be initialized in the class declaration, not an
# extension. Inject production methods into the test's explicit DTO/state shell.
harness=(root/'tests/AcademyInviteCases.swift').read_text()
marker='    // Production initializer, ownership guard, compose/create/discard/perform\n    // and install bodies are injected by the runner, not rewritten for tests.'
assert marker in harness
harness=harness.replace(marker,'\n'.join(methods))
(out/'Cases.swift').write_text(harness)
(out/'ProductionInviteAPI.swift').write_text('import Foundation\nextension ServerAPI {\n'+declaration(api,'static func createAcademyInvite(')+'\n}\n')
assert 'ForEach(invites)' in screen and 'ForEach(activeInvites)' not in screen
assert '$model.inviteExpiryDays' in screen and '$model.inviteMaxUses' in screen
composer=screen[screen.index('private var inviteComposer:'):screen.index('private var failureState:')]
assert 'model.errorMessage' in composer and 'confirmsInviteDiscard' in composer
assert 'revokingInvite = invite' in screen and '이 초대를 회수할까요?' in screen
assert '링크 복사' in screen and '코드 복사' in screen and 'ShareLink(item: shareText)' in screen
assert '.onChange(of: model.inviteCreationSequence) { _, _ in inviteFilter = .all }' in screen
assert '.id("invite-history-\\(model.inviteCreationSequence)")' in screen
PY
swiftc -swift-version 5 "$root/Matths/AccountRequestOwner.swift" "$root/Matths/MatthsServiceURLPolicy.swift" \
  "$root/Matths/AcademyInvitePolicy.swift" "$scratch/ProductionInviteAPI.swift" "$scratch/Cases.swift" -o "$scratch/cases"
"$scratch/cases"
