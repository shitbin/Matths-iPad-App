import SwiftUI

/// A bounded course → unit → concept browser. Only the selected level is
/// rendered, so the hub never constructs all 220 concept cards at once.
struct LearningPathBrowser: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var availability = CurriculumAvailabilityStore.shared
    @State private var courseID: String?
    @State private var unitID: String?
    @State private var query = ""
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                if proxy.size.width >= 850 && !typeSize.isAccessibilitySize {
                    HStack(spacing: 0) {
                        courseList.frame(width: 240)
                        Divider()
                        unitList.frame(maxWidth: .infinity)
                        if unit != nil { Divider(); conceptList.frame(maxWidth: .infinity) }
                    }
                } else if unit != nil { conceptList }
                else if course != nil { unitList }
                else { courseList }
            }
            .navigationTitle(unit?.title ?? course?.title ?? "과정 찾기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(unit != nil ? "단원 목록" : course != nil ? "과목 목록" : "닫기") {
                        if unit != nil { unitID = nil }
                        else if course != nil { courseID = nil }
                        else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button("학습으로") { dismiss() } }
            }
        }
        .onAppear {
            if let id = store.selectedCourseV2ID, CurriculumPolicy.isAvailable(id) { courseID = id }
        }
        .onChange(of: availability.snapshot) { _, _ in
            if let courseID, !CurriculumPolicy.isAvailable(courseID) { self.courseID = nil; unitID = nil }
        }
    }
    private var course: CourseV2? { courseID.flatMap(CurriculumV2.course) }
    private var unit: UnitV2? { course?.units.first { $0.id == unitID } }
    private var courseList: some View {
        List {
            Section("공개된 과목") {
                ForEach(CurriculumV2.availableCourses) { course in
                    Button {
                        courseID = course.id; unitID = nil; store.selectedCourseV2ID = course.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(course.title).font(.mBodyB)
                                Text("\(course.units.count)개 단원").font(.mCaption).foregroundStyle(Tokens.text2)
                            }
                            Spacer()
                            Image(systemName: courseID == course.id ? "checkmark" : "chevron.right")
                        }.frame(minHeight: 48).foregroundStyle(Tokens.ink)
                    }
                }
            }
            Section("준비 중") {
                ForEach(CurriculumV2.data.courses.filter { !CurriculumPolicy.isAvailable($0.id) }) { course in
                    Label(course.title + " · 준비 중", systemImage: "lock").font(.mCallout).foregroundStyle(Tokens.text2)
                }
            }
        }.listStyle(.insetGrouped)
    }
    private var unitList: some View {
        List {
            if let course {
                Section(course.title) {
                    ForEach(course.units) { unit in
                        Button { unitID = unit.id; query = "" } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(unit.title).font(.mBodyB)
                                    Text("\(unit.concepts.filter { store.progressV2.percent(for: $0) >= 100 }.count) / \(unit.concepts.count)개 완료")
                                        .font(.mCaption).foregroundStyle(Tokens.text2)
                                }
                                Spacer(); Image(systemName: "chevron.right")
                            }.frame(minHeight: 48).foregroundStyle(Tokens.ink)
                        }
                    }
                }
            } else { Text("왼쪽에서 과목을 골라 주세요.").font(.mBody) }
        }.listStyle(.insetGrouped)
    }
    private var conceptList: some View {
        List {
            if let unit {
                Section(unit.title) {
                    let concepts = unit.concepts.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }
                    if concepts.isEmpty { Text("이 단원에서 찾는 개념이 없습니다.").font(.mCallout) }
                    ForEach(concepts) { concept in
                        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                            HStack {
                                Text(concept.title).font(.mBodyB)
                                Spacer()
                                Text("\(store.progressV2.percent(for: concept))%").font(.mCaption).foregroundStyle(Tokens.text2)
                            }
                            if let summary = concept.lesson?.summary { MathInline(text: summary, color: Tokens.text2) }
                            Button("이 개념 학습하기") { store.openConceptV2(concept.id); dismiss() }
                                .frame(minHeight: 44)
                        }.padding(.vertical, Tokens.Space.s2)
                    }
                }
            }
        }.listStyle(.insetGrouped).searchable(text: $query, prompt: "이 단원의 개념 찾기")
    }
}
