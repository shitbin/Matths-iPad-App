#!/bin/bash
set -euo pipefail
repo_dir=$(cd "$(dirname "$0")/.." && pwd)
scratch_dir=$(mktemp -d /tmp/matths-attendance-write.XXXXXX)
trap 'rm -rf "$scratch_dir"' EXIT
python3 - "$repo_dir" "$scratch_dir" <<'PY'
from pathlib import Path
import sys
root, out = map(Path, sys.argv[1:])
source = (root / "Matths/ServerAPI.swift").read_text()
screen = (root / "Matths/TeacherAcademyScreen.swift").read_text()
def declaration(marker):
    start = source.index(marker)
    brace = source.index("{", start)
    depth = 0
    for index in range(brace, len(source)):
        if source[index] == "{": depth += 1
        if source[index] == "}":
            depth -= 1
            if depth == 0: return source[start:index + 1]
    raise AssertionError(marker)
selected = [declaration("struct " + name + ":") for name in [
    "TeacherAttendanceSession", "TeacherAttendanceEntry", "TeacherAttendanceCounts",
    "TeacherAttendanceRoster", "TeacherAttendanceRecord"]]
selected.append(declaration("static func changedTeacherAttendanceRecords("))
stubs = """import Foundation
struct ServerAPIError: Error { var message: String; var code: String? }
enum ServerAPI {
struct AcademyPerson: Codable, Equatable { var id: String }
struct AcademyClassSummary: Codable, Equatable { var id: String }
"""
(out / "ProductionAttendanceModels.swift").write_text(stubs + "\n".join(selected) + "\n}\n")
save = screen[screen.index("func saveAttendance() async"):screen.index("func regenerateAttendanceCode() async")]
assert "ServerAPI.changedTeacherAttendanceRecords(" in save
assert "attendance.roster.map" not in save, "full roster must not become a write command"
assert "guard !records.isEmpty" in save
assert '"ATTENDANCE_WRITE_CONFLICT"' in save and "installAttendance(latest)" in save
assert "attendanceDateKey == attendance.dateKey" in save and "self.attendance.map(attendanceKey) == requestedKey" in save
assert "defer { if generation == requestGeneration" in save
assert "records.map(\\.requestBody)" in source
PY
swiftc "$scratch_dir/ProductionAttendanceModels.swift" \
  "$repo_dir/Matths/StaffWorkspaceState.swift" \
  "$repo_dir/tests/TeacherAttendanceWritePlanCases.swift" \
  -o "$scratch_dir/cases"
"$scratch_dir/cases"
