#!/bin/bash
set -euo pipefail
repo_dir=$(cd "$(dirname "$0")/.." && pwd)
scratch_dir=$(mktemp -d /tmp/matths-staff-workspace.XXXXXX)
swiftc "$repo_dir/Matths/StaffWorkspaceState.swift" "$repo_dir/tests/StaffWorkspaceCases.swift" -o "$scratch_dir/cases"
"$scratch_dir/cases"
for source in TeacherAcademyScreen AdminAcademyScreen; do
  grep -Fq 'StaffWorkspaceContainer(' "$repo_dir/Matths/$source.swift"
done
grep -Fq 'attendanceConflicts.isEmpty' "$repo_dir/Matths/TeacherAcademyScreen.swift"
grep -Fq 'ServerAPI.isCurrentAuthorization(authorization)' "$repo_dir/Matths/TeacherAcademyScreen.swift"
grep -Fq 'requestID == detailRequestID' "$repo_dir/Matths/AdminUsersScreen.swift"
grep -Fq 'StaffChangeReview(' "$repo_dir/Matths/AdminAcademyExplorer.swift"
grep -Fq 'reasonIsRecorded: true' "$repo_dir/Matths/AdminAcademyExplorer.swift"
grep -Fq 'onSave: (AdminClassOperationsInput) async -> String?' "$repo_dir/Matths/AdminAcademyExplorer.swift"
grep -Fq 'account == DataScope.slot, isCurrentAuthorization(authorization)' "$repo_dir/Matths/ServerAPI.swift"
echo 'staff state retention, authorization, review integration guards passed'
