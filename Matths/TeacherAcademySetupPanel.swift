import SwiftUI

/// 학원 소속이 아직 없는 교사가 오류 화면에서 막히지 않고 학원 생성 또는 참여 승인까지
/// 이어 가는 첫 진입 흐름. 승인 전에는 학생 정보 API를 호출하지 않는다.
struct TeacherAcademySetupPanel: View {
    let setup: ServerAPI.TeacherAcademySetup
    @ObservedObject var model: TeacherAcademyScreenModel

    @EnvironmentObject private var store: AppStore
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var academyName = ""
    @State private var selectedAcademyID = ""
    @State private var confirmsCancellation = false

    private var compactLandscape: Bool {
        verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: compactLandscape ? Tokens.Space.s2 : Tokens.Space.s4) {
                heading
                feedback
                if let pending = setup.pendingAcademy {
                    pendingAcademy(pending)
                } else if let pending = setup.pendingRequest {
                    pendingJoin(pending)
                } else {
                    if let rejected = setup.rejectedAcademy {
                        rejectedNotice(rejected)
                    }
                    choiceGrid
                }
                policyNote
            }
            .readableWidth(1180)
            .adaptiveHPadding()
            .padding(.vertical, compactLandscape ? Tokens.Space.s2 : Tokens.Space.s4)
            .padding(.bottom, compactLandscape ? Tokens.Space.s2 : Tokens.Space.s4)
        }
        .refreshable { await model.load() }
        .confirmationDialog(
            "학원 참여 요청을 취소할까요?",
            isPresented: $confirmsCancellation,
            titleVisibility: .visible
        ) {
            Button("참여 요청 취소", role: .destructive) {
                Task { _ = await model.cancelAcademyJoin() }
            }
            Button("계속 기다리기", role: .cancel) {}
        } message: {
            Text("취소 후 다른 학원을 선택하거나 새 학원 등록을 요청할 수 있습니다.")
        }
    }

    private var heading: some View {
        HStack(alignment: .top, spacing: Tokens.Space.s3) {
            Image(systemName: "building.2.crop.circle")
                .font(.system(size: compactLandscape ? 32 : 54, weight: .semibold))
                .foregroundStyle(Tokens.primary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("학원 페이지 시작")
                    .font(compactLandscape ? .mHeading : .mTitle).foregroundStyle(Tokens.ink)
                Text("새 학원을 등록하거나 이미 등록된 학원에 참여해 주세요. 승인 전에는 학생 정보가 공개되지 않습니다.")
                    .font(compactLandscape ? .mMicro : .mCaption).foregroundStyle(Tokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button {
                Task { await model.load() }
            } label: {
                Image(systemName: "arrow.clockwise").frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)
            .disabled(model.isLoading || model.actionID != nil)
            .accessibilityLabel("승인 상태 새로고침")
        }
    }

    @ViewBuilder
    private var feedback: some View {
        if let notice = model.noticeMessage {
            Label(notice, systemImage: "checkmark.circle.fill")
                .font(.mCaption).foregroundStyle(Tokens.successInk)
                .padding(Tokens.Space.s2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Tokens.successSoft,
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
        }
        if let error = model.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.mCaption).foregroundStyle(Tokens.dangerInk)
                .padding(Tokens.Space.s2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Tokens.dangerSoft,
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
        }
    }

    private func pendingAcademy(_ academy: ServerAPI.AcademySummary) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Label("운영자 검토 대기", systemImage: "hourglass.circle.fill")
                .font(.mCaption).foregroundStyle(Tokens.warningInk)
            Text("\(academy.name) 등록 요청을 확인하고 있습니다")
                .font(.mHeading).foregroundStyle(Tokens.ink)
            Text("승인 전에는 학원이 검색 목록에 표시되지 않고 학생·교사도 참여할 수 없습니다. 승인되면 새로고침 후 관리 화면이 열립니다.")
                .font(.mCaption).foregroundStyle(Tokens.text2)
            Button("승인 상태 확인") { Task { await model.load() } }
                .buttonStyle(PrimaryButtonStyle()).frame(maxWidth: compactLandscape ? 340 : .infinity)
                .disabled(model.isLoading)
        }
        .setupSurface(fill: Tokens.warningSoft, compact: compactLandscape)
    }

    private func pendingJoin(_ request: ServerAPI.TeacherAcademySetup.PendingRequest) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Label("원장 승인 대기", systemImage: "person.crop.circle.badge.clock")
                .font(.mCaption).foregroundStyle(Tokens.warningInk)
            Text("\(request.academy.name) 참여 요청을 보냈습니다")
                .font(.mHeading).foregroundStyle(Tokens.ink)
            Text("원장이 승인하면 학생 현황과 수업 도구가 열립니다. 기다리는 동안에는 학생 이름이나 학습 기록을 볼 수 없습니다.")
                .font(.mCaption).foregroundStyle(Tokens.text2)
            HStack(spacing: Tokens.Space.s2) {
                Button("승인 상태 확인") { Task { await model.load() } }
                    .buttonStyle(PrimaryButtonStyle())
                Button("요청 취소", role: .destructive) { confirmsCancellation = true }
                    .buttonStyle(.bordered).tint(Tokens.dangerInk).frame(minHeight: 44)
            }
            .frame(maxWidth: compactLandscape ? 560 : .infinity)
            .disabled(model.isLoading || model.actionID != nil)
        }
        .setupSurface(fill: Tokens.warningSoft, compact: compactLandscape)
    }

    private func rejectedNotice(_ academy: ServerAPI.AcademySummary) -> some View {
        Label(
            "\(academy.name) 등록 요청이 승인되지 않았습니다. 이름을 확인해 다시 요청하거나 지원팀에 문의해 주세요.",
            systemImage: "exclamationmark.triangle.fill")
            .font(.mCaption).foregroundStyle(Tokens.dangerInk)
            .padding(Tokens.Space.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.dangerSoft,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
    }

    @ViewBuilder
    private var choiceGrid: some View {
        if compactLandscape {
            HStack(alignment: .top, spacing: Tokens.Space.s3) {
                createCard.frame(maxWidth: .infinity)
                joinCard.frame(maxWidth: .infinity)
            }
        } else {
            VStack(spacing: Tokens.Space.s3) {
                createCard
                joinCard
            }
        }
    }

    private var createCard: some View {
        VStack(alignment: .leading, spacing: compactLandscape ? Tokens.Space.s2 : Tokens.Space.s3) {
            Label("새 학원 만들기", systemImage: "plus.circle.fill")
                .font(compactLandscape ? .mBodyB : .mHeading).foregroundStyle(Tokens.ink)
            Text("학원 이름을 등록하면 Matths 운영자가 계약과 교사 권한을 확인합니다.")
                .font(compactLandscape ? .mMicro : .mCaption).foregroundStyle(Tokens.text2)
            VStack(alignment: .leading, spacing: 5) {
                Text("학원 이름").font(.mMicro).foregroundStyle(Tokens.text3)
                TextField("예: 평촌 하이수학", text: $academyName)
                    .textInputAutocapitalization(.never)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, Tokens.Space.s2)
                    .frame(minHeight: compactLandscape ? 40 : 48)
                    .background(Tokens.paper2,
                                in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
                    .accessibilityHint("2자 이상 80자 이하")
            }
            Button("학원 등록 요청") {
                Task {
                    if await model.createAcademy(name: academyName) { academyName = "" }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(model.actionID != nil)
        }
        .setupSurface(compact: compactLandscape)
    }

    private var joinCard: some View {
        VStack(alignment: .leading, spacing: compactLandscape ? Tokens.Space.s2 : Tokens.Space.s3) {
            Label("기존 학원 들어가기", systemImage: "arrow.right.circle.fill")
                .font(compactLandscape ? .mBodyB : .mHeading).foregroundStyle(Tokens.ink)
            Text("등록된 학원을 선택하면 해당 학원 원장에게 참여 승인을 요청합니다.")
                .font(compactLandscape ? .mMicro : .mCaption).foregroundStyle(Tokens.text2)
            VStack(alignment: .leading, spacing: 5) {
                Text("학원 선택").font(.mMicro).foregroundStyle(Tokens.text3)
                Menu {
                    ForEach(setup.academies) { academy in
                        Button {
                            selectedAcademyID = academy.id
                        } label: {
                            if selectedAcademyID == academy.id {
                                Label(academy.name, systemImage: "checkmark")
                            } else {
                                Text(academy.name)
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedAcademyName).lineLimit(1)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.up.chevron.down")
                    }
                    .font(.mCaption).foregroundStyle(Tokens.ink)
                    .padding(.horizontal, Tokens.Space.s2)
                    .frame(maxWidth: .infinity, minHeight: compactLandscape ? 40 : 48)
                    .background(Tokens.paper2,
                                in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
                }
                .disabled(setup.academies.isEmpty)
            }
            if setup.academies.isEmpty {
                Text("현재 참여할 수 있는 학원이 없습니다. 새 학원을 등록하거나 지원팀에 상태를 확인해 주세요.")
                    .font(.mMicro).foregroundStyle(Tokens.text3)
            }
            Button("학원 참여 요청") {
                Task { _ = await model.requestAcademyJoin(academyID: selectedAcademyID) }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(setup.academies.isEmpty || selectedAcademyID.isEmpty || model.actionID != nil)
        }
        .setupSurface(compact: compactLandscape)
    }

    private var policyNote: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text("승인과 개인정보").font(.mBodyB).foregroundStyle(Tokens.ink)
            Text("새 학원은 운영자 승인, 기존 학원 참여는 원장 승인을 거칩니다. 승인 전에는 내부 학생 정보와 학습 기록이 앱에 내려오지 않습니다.")
                .font(.mCaption).foregroundStyle(Tokens.text2)
            Button("학원 정보·교사 권한 문의") { store.route = .support }
                .font(.mCaption).foregroundStyle(Tokens.primary)
        }
        .setupSurface(fill: Tokens.primarySoft, compact: compactLandscape)
    }

    private var selectedAcademyName: String {
        setup.academies.first(where: { $0.id == selectedAcademyID })?.name
            ?? (setup.academies.isEmpty ? "참여 가능한 학원 없음" : "학원을 선택해 주세요")
    }
}

private struct TeacherSetupSurface: ViewModifier {
    let fill: Color
    let compact: Bool

    func body(content: Content) -> some View {
        content
            .padding(compact ? Tokens.Space.s2 : Tokens.Space.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                    .strokeBorder(Tokens.line, lineWidth: 1)
            }
    }
}

private extension View {
    func setupSurface(fill: Color = Tokens.paper, compact: Bool = false) -> some View {
        modifier(TeacherSetupSurface(fill: fill, compact: compact))
    }
}
