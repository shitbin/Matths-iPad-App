#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
node - "$ROOT" <<'NODE'
const fs = require('node:fs');
const assert = require('node:assert/strict');
const root = process.argv[2];
const screens = fs.readFileSync(`${root}/Matths/Screens.swift`, 'utf8');
const academy = fs.readFileSync(`${root}/Matths/AcademyScreen.swift`, 'utf8');
const paper = fs.readFileSync(`${root}/Matths/AssessmentPaperScreen.swift`, 'utf8');
const app = fs.readFileSync(`${root}/Matths/MatthsApp.swift`, 'utf8');
const section = (source, start, end) => {
  const a = source.indexOf(start), b = source.indexOf(end, a + start.length);
  assert(a >= 0 && b > a, `missing source boundary ${start}`);
  return source.slice(a, b);
};
const hub = section(screens, 'struct AssessmentScreen: View', 'struct CourseAssessmentSection: View');
assert(!hub.includes('Picker('), 'official hub must not duplicate subject selection');
assert(!hub.includes('chainSection('), 'unit chains belong to their course');
assert(hub.includes('Text("평가센터").font(.mHeading)'), 'the logo-only shell needs one compact page heading');
assert(!hub.includes('Text("평가센터").font(.mTitle)'), 'do not restore the oversized duplicate heading');
assert.equal((hub.match(/Text\("평가센터"\)/g) || []).length, 1);
assert(hub.includes('WeeklyMockEntryCard') && hub.includes('store.route = .placement'));
assert(hub.includes('$0.serverBacked == true && !$0.isServerCancelled && $0.submittedAt == nil'));
assert(hub.includes('$0.serverBacked == true && !$0.isServerCancelled && $0.submittedAt != nil'));
assert(hub.includes('submittedAttempts.prefix(3)') && hub.includes('submittedAttempts.dropFirst(3)'),
  'condensed recent results must preserve access to earlier results');
assert(hub.includes('current.serverBacked == true, !current.isServerCancelled'));
assert(hub.includes('store.currentAttemptID = current.id') && hub.includes('store.route = .paper'));
assert(hub.includes('store.assessmentReturnRoute = .assess'));
assert(hub.includes('await store.pullServerAssessments()'));
const course = section(screens, 'extension CourseAssessmentSection', '/// 기출 리스트의 학년도 구획');
for (const scope of ['subunit', 'unit', 'course']) assert(course.includes(`store.startPaper(scope: .${scope}`));
assert.equal((course.match(/returnRoute: \.curriculum/g) || []).length, 3);
assert(app.includes('returnRoute: intent.returnRoute'), 'login continuation must preserve course origin');
assert(app.includes('assessmentReturnRoute = .assess'), 'account reset must retire the previous origin');
assert(paper.includes('Button(returnLabel, action: closePaper)'));
assert(paper.includes('store.ownsCurrentAccountSession(account), store.currentAttemptID == attemptID'));
assert(paper.includes('store.route == .paper'));
assert(course.includes('lockDetailSheet') && course.includes('systemInfoSheet'));
assert(course.includes('store.selectedCourseV2ID = courseID'));
assert(!course.includes('Picker("평가 과목"'));
const surface = section(academy, 'private struct AcademyCardSurface', 'private extension View');
assert(surface.indexOf('.frame(maxWidth: .infinity, alignment: .leading)') < surface.indexOf('.background('),
  'card content must stretch BEFORE its background, not add invisible width after it');
const join = section(academy, 'private func joinView(', 'private func weekDetail(');
assert(join.indexOf('Toggle(isOn: $model.consent)') < join.indexOf('inviteCodeCard'),
  'shared consent must appear before the disabled request buttons');
assert(join.includes('Text("학원을 선택해 주세요").tag("")'));
assert(join.includes('.disabled(model.inviteRequestDisabledReason != nil)'));
assert(join.includes('.disabled(model.academyRequestDisabledReason != nil)'));
assert(join.includes('requestRequirement(model.inviteRequestDisabledReason)'));
assert(join.includes('requestRequirement(model.academyRequestDisabledReason)'));
assert(!academy.includes('selectedAcademyID = value.academies.first?.id'));
console.log('PASS: official exam hub/course separation, preserved resume/result routes, full-width academy surfaces and explicit request prerequisites');
NODE
