#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d /tmp/matths-profile-cache.XXXXXX)
node - "$root" "$scratch" <<'JS'
const fs=require('node:fs'), assert=require('node:assert/strict');
const [root,out]=process.argv.slice(2);
const source=fs.readFileSync(root+'/Matths/MatthsApp.swift','utf8');
const begin=source.indexOf('    func acceptProfileAvatar(');
const end=source.indexOf('    @MainActor\n    func refreshServerProfile(',begin);
assert(begin>=0 && end>begin);
const view=fs.readFileSync(root+'/Matths/ProfileScreen.swift','utf8');
assert(view.includes('let avatar = try await ServerAPI.updateProfileAvatarPreset'));
assert(view.includes('let avatar = try await ServerAPI.updateProfileAvatarCustom'));
assert(view.includes('store.coach.level = previousLevel'));
fs.writeFileSync(out+'/main.swift',`
import Foundation
enum SpiceLevel: String { case mild, spicy, silent }
struct ServerProfileAvatar: Equatable { let code: String }
struct ServerUser { var profileAvatar: ServerProfileAvatar?; var coachMode: String? }
struct AccountRequestOwner { let generation: Int; func isCurrent(in store: Store) -> Bool { generation == store.generation } }
final class Store {
 var generation = 1
 var serverProfile: ServerUser? = ServerUser(coachMode: "mild")
 var revision = 0
 func applyServerProfile(_ user: ServerUser) { serverProfile = user; revision += 1 }
`+source.slice(begin,end)+`
}
let store = Store()
let owner = AccountRequestOwner(generation: 1)
store.acceptProfileAvatar(ServerProfileAvatar(code: "CUSTOM"), owner: owner)
precondition(store.serverProfile?.profileAvatar?.code == "CUSTOM" && store.revision == 1)
store.acceptCoachMode(.spicy, owner: owner)
precondition(store.serverProfile?.coachMode == "spicy" && store.revision == 2)
precondition(store.serverProfile?.profileAvatar?.code == "CUSTOM")
store.generation = 2
store.acceptProfileAvatar(ServerProfileAvatar(code: "OLD"), owner: owner)
store.acceptCoachMode(.silent, owner: owner)
precondition(store.revision == 2 && store.serverProfile?.coachMode == "spicy")
precondition(store.serverProfile?.profileAvatar?.code == "CUSTOM")
print("PASS actual profile mutation cache: immediate updates, revision advances, cross-account late responses rejected")
`);
JS
swiftc "$scratch/main.swift" -o "$scratch/cases"
"$scratch/cases"
