//  ProfileScreen.swift
//  Matths
//
//  프로필 — 계정 · 학습 통계 · 설정 · 학교(경쟁전 리그).
//  탭이 아니라 상단 바의 아바타 버튼으로 들어온다 (탭 6개가 인지 한계선).
//
//  구성:
//   계정   아바타 · 이름 · 로그인 수단 · 학년 선택
//   통계   완료 개념 / 푼 문항 / 정답률 / 연속 학습일
//   설정   코치 수위 · 테마 · 복습 리마인더 · 화면 모션 · 왼손잡이 · AI 모델 · Pro 구독
//   데이터 동기화 상태 · 진도 초기화(확인 다이얼로그) · 로그아웃 · 회원 탈퇴
//   정보   버전 · 약관·개인정보 링크 · 오픈소스 고지

import AuthenticationServices
import SwiftUI
import UIKit

struct ProfilePhotoCropPicker: UIViewControllerRepresentable {
    let onCancel: () -> Void
    let onPick: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.mediaTypes = ["public.image"]
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ProfilePhotoCropPicker

        init(parent: ProfilePhotoCropPicker) { self.parent = parent }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage else {
                parent.onCancel()
                return
            }
            parent.onPick(image)
        }
    }
}

struct ProfileScreen: View {
    /// 개념 해설 음성 선택. 기본은 여성 목소리(ConceptNarrationPreference.appDefault).
    @AppStorage(ConceptNarrationPreference.key) private var conceptVoiceRaw = ConceptNarrationPreference.appDefault.rawValue
    private var conceptVoice: Binding<ConceptNarrationVoice> {
        Binding(get: { ConceptNarrationVoice(rawValue: conceptVoiceRaw) ?? ConceptNarrationPreference.appDefault },
                set: { conceptVoiceRaw = $0.rawValue })
    }

    private var serverProfileControls: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            SectionRule(title: "프로필 사진과 튜토리얼")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Tokens.Space.s3) {
                    ForEach(Self.profileAvatarPresets, id: \.0) { code, label in
                        Button {
                            Task { await selectProfileAvatar(code) }
                        } label: {
                            VStack(spacing: 5) {
                                Text(String(label.prefix(1)))
                                    .font(.mHeading)
                                    .frame(width: 46, height: 46)
                                    .background(Tokens.primarySoft, in: Circle())
                                Text(label).font(.mMicro)
                            }
                            .foregroundStyle(
                                serverProfile?.profileAvatar?.code == code
                                    ? Tokens.primary : Tokens.text2)
                        }
                        .buttonStyle(.plain)
                        .disabled(profileMutationInFlight)
                    }

                    Button {
                        showProfilePhotoCropper = true
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: "photo.badge.plus")
                                .font(.mHeading)
                                .frame(width: 46, height: 46)
                                .background(Tokens.paper2, in: Circle())
                            Text("내 사진").font(.mMicro)
                        }
                        .foregroundStyle(Tokens.primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(profileMutationInFlight)
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Tokens.Space.s3) { tutorialButtons }
                VStack(alignment: .leading, spacing: Tokens.Space.s3) { tutorialButtons }
            }

            if let serverProfileError {
                Text(serverProfileError)
                    .font(.mCaption)
                    .foregroundStyle(Tokens.dangerInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var tutorialButtons: some View {
        Button("대시보드 튜토리얼 다시 시작") {
            Task {
                do {
                    _ = try await ServerAPI.updateDashboardTutorial("RESTART")
                    await refreshServerProfile()
                    // 서버 상태만 PENDING으로 바꾸고 프로필에 머물면
                    // 사용자 눈에는 아무 일도 안 일어난다. 웹의 restart가
                    // `/main?tutorialStep=0`으로 돌아가듯 앱도 홈으로 이동한다.
                    store.requestedDashboardTutorial = true
                    store.route = .home
                } catch {
                    serverProfileError = (error as? ServerAPIError)?.errorDescription
                }
            }
        }
        .buttonStyle(SecondaryButtonStyle())

        Menu("GOAT Arena 튜토리얼") {
            ForEach(serverProfile?.arenaTutorial?.availableChapters ?? [], id: \.self) { chapter in
                Button(arenaTutorialLabel(chapter)) {
                    Task {
                        do {
                            _ = try await ServerAPI.updateArenaTutorial(
                                chapter: chapter,
                                action: "RESTART")
                            await refreshServerProfile()
                            // 최신 서버는 의도적으로 autoChapter를 고르지 않는다.
                            // 사용자가 고른 편을 앱 로컬 launch request로 넘기고,
                            // 그 편이 있는 실제 화면으로 즉시 이동한다.
                            store.requestedArenaTutorialChapter = chapter
                            store.route = chapter == "ranked_shop" ? .arenaShop : .rank
                        } catch {
                            serverProfileError = (error as? ServerAPIError)?.errorDescription
                        }
                    }
                }
            }
        }
        .buttonStyle(SecondaryButtonStyle())
    }

    private static let profileAvatarPresets: [(String, String)] = [
        ("NOVA_GOAT", "노바"),
        ("COMET_FOX", "코멧"),
        ("ORBIT_OWL", "오빗"),
        ("NEON_TIGER", "네온"),
        ("COSMIC_BEAR", "코스믹"),
        ("PIXEL_RABBIT", "픽셀"),
    ]

    @MainActor
    private func refreshServerProfile() async {
        guard store.authProvider == "server" else {
            serverProfile = nil
            return
        }
        do {
            await store.refreshServerProfile()
            guard store.authProvider == "server" else { return }
            guard let user = store.serverProfile else {
                throw ServerAPIError(message: "프로필을 불러오지 못했습니다.", code: "PROFILE_UNAVAILABLE")
            }
            serverProfile = user
            if let mode = user.coachMode, let level = SpiceLevel(rawValue: mode) {
                applyingServerProfile = true
                store.coach.level = level
                DispatchQueue.main.async { applyingServerProfile = false }
            }
            serverProfileError = nil
        } catch {
            serverProfileError = (error as? ServerAPIError)?.errorDescription
        }
    }

    @MainActor
    private func selectProfileAvatar(_ code: String) async {
        profileMutationInFlight = true
        defer { profileMutationInFlight = false }
        do {
            _ = try await ServerAPI.updateProfileAvatarPreset(code)
            await refreshServerProfile()
        } catch {
            serverProfileError = (error as? ServerAPIError)?.errorDescription
                ?? "프로필 사진을 저장하지 못했습니다."
        }
    }

    @MainActor
    private func uploadProfilePhoto(_ image: UIImage) async {
        profileMutationInFlight = true
        defer { profileMutationInFlight = false }
        do {
            guard image.size.width > 0,
                  image.size.height > 0,
                  abs(image.size.width - image.size.height) < 2,
                  let jpeg = image.jpegData(compressionQuality: 0.82) else {
                throw ServerAPIError(
                    message: "사진을 1:1로 자른 뒤 저장해 주세요.",
                    code: "PROFILE_AVATAR_IMAGE_INVALID")
            }
            _ = try await ServerAPI.updateProfileAvatarCustom(jpegData: jpeg)
            await refreshServerProfile()
        } catch {
            serverProfileError = (error as? ServerAPIError)?.errorDescription
                ?? "프로필 사진을 저장하지 못했습니다."
        }
    }

    private func arenaTutorialLabel(_ chapter: String) -> String {
        switch chapter {
        case "common": return "GOAT Arena 기본"
        case "unranked": return "Unranked 홈"
        case "unranked_match": return "Unranked 경기"
        case "ranked": return "Ranked 홈"
        case "ranked_battle": return "Ranked 배틀"
        case "ranked_shop": return "Ranked 상점"
        default: return chapter
        }
    }

    @State private var showWithdraw = false
    @EnvironmentObject private var store: AppStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// 기기 이름이 아니라 사이즈 클래스로 판정한다 — Split View, Stage Manager 의
    /// iPad 도 compact 로 들어온다.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var confirmReset = false
    @State private var resetError: String?
    /// 8GB 기기에서 9B 경량판을 쓰겠다는 선택 (UserDefaults 직결)
    @State private var force9B = ModelDownloader.force9BOnSmallDevice
    #if DEBUG
    @State private var debugTier: String? = ModelDownloader.debugForcedTier
    #endif
    /// 티어 전환 다운로드는 이 화면에서만 시작된다 — 진행률도 여기서 보여야 한다
    @ObservedObject private var downloader = ModelDownloader.shared
    /// 동기화 상태 표면화 — pending·lastSyncedAt·lastError 는 지금까지 아무 화면도
    /// 구독하지 않아, 큐가 쌓이거나 서버가 계속 거부해도 기기에서 파일을 꺼내 봐야만
    /// 알 수 있었다("큐에 넣었으니 됐다" 금지). 프로필 데이터 섹션이 그 창구다.
    @ObservedObject private var sync = SyncEngine.shared
    @State private var serverProfile: ServerUser?
    @State private var serverProfileError: String?
    @State private var profileMutationInFlight = false
    @State private var showProfilePhotoCropper = false
    @State private var showNicknameEditor = {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-nicknameEditor")
        #else
        false
        #endif
    }()
    @State private var nicknameDraft = ""
    @State private var nicknameSaving = false
    @State private var nicknameError: String?
    @State private var applyingServerProfile = false

    private let totalConcepts = CurriculumV2.data.courses.reduce(0) { $0 + $1.allConcepts.count }
    private var completedConceptCount: Int {
        CurriculumV2.data.courses
            .flatMap(\.allConcepts)
            .filter { store.progressV2.percent(for: $0) >= 100 }
            .count
    }

    private var compactWidth: Bool { horizontalSizeClass == .compact }
    /// iPhone 가로는 상단바·하단탭·홈 인디케이터를 빼면 본문에 약 280pt 만 남는다.
    /// 섹션 사이 28pt 를 그대로 두면 한 화면에 카드 하나도 못 들어온다.
    private var compactHeight: Bool { verticalSizeClass == .compact }

    private var sectionSpacing: CGFloat {
        if compactHeight { return Tokens.Space.s4 }
        return compactWidth ? Tokens.Space.s5 : Tokens.Space.s7
    }

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            // 헤더
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                Button {
                    store.route = .home
                } label: {
                    Label("홈", systemImage: "chevron.left")
                        .font(.mCaption).foregroundStyle(Tokens.text3)
                        // AX5에서 짧은 탐색 라벨까지 본문처럼 커지면 "홈"이 한 글자씩
                        // 세로로 깨져 계정 카드가 더 아래로 밀린다. 탐색 크롬만 xxxLarge로
                        // 제한하고 VoiceOver 이름과 44pt 표적은 온전히 유지한다.
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .frame(minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(store.progressResetInFlight)
                .accessibilityLabel("홈으로 돌아가기")

                // 세로가 짧은 창에서는 화면 이름도 크롬이다. 28pt 제목을 22pt 로
                // 낮춰 계정 카드가 첫 화면 안에 들어오게 한다(CommerceHubScreen 의
                // 제목과 같은 규칙). 세로 iPhone 과 모든 iPad 는 종전 28pt 그대로다.
                Text("프로필").font(compactHeight ? .mHeading : .mTitle)
                    .foregroundStyle(Tokens.ink)
                ExamRule()
            }
            .entrance(0)

            // 계정 — 이름은 실데이터(홈 인사와 같은 값)이고 여기서 바로 고친다
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                        profileAvatar
                        accountIdentity
                    }
                } else {
                    HStack(spacing: Tokens.Space.s4) {
                        profileAvatar
                        accountIdentity
                        Spacer(minLength: 0)
                    }
                }
            }
            .card()
            .entrance(1)

            if store.authProvider == "server" {
                serverProfileControls
                    .entrance(2)
            }

            // 학년 선택 — 3월 1일 학년도 기준 자동 승급 (웹 생애주기 규칙)
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                SectionRule(title: "학년, GOAT Arena 리그 기준, 매년 3월 1일 자동 승급")
                // **서버 계정은 학년을 앱에서 바꾸지 않는다.**
                //
                // 여기서 고른 값은 UserDefaults 에만 저장되고 서버로 가지 않았다.
                // 그래서 같은 계정이 앱에서는 "N수생", 웹 랭킹·커리큘럼에서는
                // "고등학교 3학년" 으로 갈렸다. 학년은 가입 때 정하고 그 뒤로는
                // 서버의 자동 진급(매년 3월 1일)이 관리하는 값이다.
                //
                // 13(N수생)은 자동 진급으로만 도달한다 — 선택지에서는 뺀다.
                if store.authProvider == "server" {
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            gradeLabel
                            Spacer(minLength: Tokens.Space.s4)
                            gradeCaption.fixedSize(horizontal: true, vertical: false)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            gradeLabel
                            gradeCaption
                        }
                    }
                    .padding(.vertical, Tokens.Space.s2)
                } else {
                    Picker("학년", selection: $store.schoolGrade) {
                        Text("고1").tag(10)
                        Text("고2").tag(11)
                        Text("고3").tag(12)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .entrance(2)

            // 학교 — 경쟁전(학교 리그)의 기반. 전국 2,403개교(나이스) 목록에서만 고른다.
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                SectionRule(title: "내 학교, 학교 리그 기준")
                SchoolPickerRow()
            }
            .entrance(3)

            // 학습 통계
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                SectionRule(title: "학습 통계")
                // 전부 0인 네 칸은 정보가 아니라 빈자리다 — 0 을 네 번 보여주는 대신
                // 다음에 올 것을 한 줄로 말한다.
                if store.progressV2.byConcept.isEmpty,
                   store.solvedTotal == 0,
                   store.streakDays == 0 {
                    Text("첫 학습 후 통계가 표시됩니다")
                        .font(.mCallout).foregroundStyle(Tokens.text3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(padding: Tokens.Space.s4)
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 0) {
                            stat("완료 개념", "\(completedConceptCount)", "/ \(totalConcepts)")
                            divider
                            stat("푼 문항", "\(store.solvedTotal)", "문항")
                            divider
                            stat("정답률", "\(store.accuracy)", "%")
                            divider
                            stat("연속 학습", "\(store.streakDays)", "일")
                        }
                        .frame(minWidth: 420)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: Tokens.Space.s3),
                                           count: 2),
                            spacing: Tokens.Space.s4
                        ) {
                            stat("완료 개념", "\(completedConceptCount)", "/ \(totalConcepts)")
                            stat("푼 문항", "\(store.solvedTotal)", "문항")
                            stat("정답률", "\(store.accuracy)", "%")
                            stat("연속 학습", "\(store.streakDays)", "일")
                        }
                    }
                    .card(padding: Tokens.Space.s4)
                }
            }
            .entrance(4)

            // 설정
            VStack(alignment: .leading, spacing: 0) {
                SectionRule(title: "설정").padding(.bottom, Tokens.Space.s2)

                settingRow("코치 수위", caption: "채점 코멘트의 매운 정도") {
                    Picker("", selection: $store.coach.level) {
                        ForEach(SpiceLevel.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented).frame(maxWidth: 260)
                    .accessibilityLabel("코치 수위")
                    .onChange(of: store.coach.level) { _, level in
                        guard !applyingServerProfile else { return }
                        Task {
                            do {
                                try await ServerAPI.updateCoachMode(level.rawValue)
                                await refreshServerProfile()
                            } catch {
                                serverProfileError = (error as? ServerAPIError)?.errorDescription
                                    ?? "코치 모드를 저장하지 못했습니다."
                            }
                        }
                    }
                }
                DottedRule()
                // 매일 만지는 설정이 아니다 — segmented 상시 노출 대신 메뉴로 강등.
                // 코치 수위(학습 중 자주 조절)와 노출 무게를 달리한다.
                settingRow("화면 테마", caption: "다크 모드는 로고 원판의 근검정 바탕") {
                    Picker("화면 테마", selection: $store.themePreference) {
                        Text("시스템").tag("system")
                        Text("라이트").tag("light")
                        Text("다크").tag("dark")
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(minHeight: 44)   // 메뉴 버튼도 최소 터치 타겟을 지킨다
                }
                DottedRule()
                // 문구는 ReviewReminder(MatthsApp.swift)가 실제로 하는 일과 맞춰 둔다 —
                // 저녁 8시, 그날까지 복습이 걸린 오답이 있는 날에만 기기 로컬 알림.
                // 권한이 거부되면 토글이 스스로 꺼진다(켜진 척하지 않는다).
                settingRow("복습 리마인더", caption: "복습 예정 문항이 있는 날 저녁 8시에 기기 알림") {
                    Toggle("", isOn: $store.reviewReminderOn)
                        .labelsHidden().tint(Tokens.primary)
                        .accessibilityLabel("복습 리마인더")
                }
                DottedRule()
                settingRow("화면 모션", caption: "전환, 등장, 채점 피드백 애니메이션 (기기의 동작 줄이기가 켜져 있으면 항상 꺼짐)") {
                    Toggle("", isOn: $store.motionOn)
                        .labelsHidden().tint(Tokens.primary)
                        .accessibilityLabel("화면 모션")
                }
                DottedRule()
                // 별도 효과음 트랙은 없다. 끄기 상태를 효과음 모드처럼 안내하지 않는다.
                settingRow("개념 해설 음성", caption: "개념 영상의 해설 음성을 끄거나 성우를 고릅니다") {
                    Picker("", selection: conceptVoice) {
                        // allCases 가 아니라 installedCases 다. 번들에 없는 성우를
                        // 고를 수 있으면 소리만 조용히 안 나와 앱이 고장 난 것으로 보인다.
                        ForEach(ConceptNarrationVoice.installedCases) { v in
                            Text(v.label).tag(v)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(Tokens.primary)
                    .accessibilityLabel("개념 해설 음성")
                    .accessibilityIdentifier("setting-concept-voice")
                }
                DottedRule()
                settingRow("왼손잡이 모드", caption: "풀이 화면에서 노트를 왼쪽에 둡니다. 쓰는 손이 문제를 가리지 않게 합니다") {
                    Toggle("", isOn: $store.leftHandedOn)
                        .labelsHidden().tint(Tokens.primary)
                        .accessibilityLabel("왼손잡이 모드")
                }
                DottedRule()
                // 메모리 작은 기기(8GB)에서만 노출 — 큰 기기는 이미 9B 를 쓴다
                if !ModelDownloader.hasLargeMemory {
                    #if DEBUG
                    DebugLocalModelSelector(selection: $debugTier, openModelLabel: nil)
                    DottedRule()
                    #else
                    // 용량은 스펙에서 읽는다 — 하드코딩한 숫자는 모델을 낮춰도 그대로 남아
                    // 화면이 실제 선택 모델과 다른 용량을 말하지 않게 스펙에서 읽는다.
                    settingRow("AI 모델 9B 실험 모드",
                               caption: "기본은 DeepSeek-R1 7B 추론 모델입니다. 켜면 사진 판독이 끝난 뒤 Qwen3.5 9B 3비트 텍스트판(\(ModelDownloader.spec9BLiteText.sizeLabel))으로 바꿉니다. 실제 8GB 기기에서 약 69초에 동작했지만, 메모리 상황에 따라 앱이 종료될 수 있습니다.") {
                        Toggle("", isOn: $force9B)
                            .labelsHidden().tint(Tokens.primary)
                            .accessibilityLabel("AI 모델 9B 실험 모드")
                            .onChange(of: force9B) {
                                ModelDownloader.force9BOnSmallDevice = force9B
                                // 바뀐 티어의 파일이 아직 없으면 여기서 받기 시작한다.
                                // 이 통로가 없어서, 토글을 켜도 옆에 있던 4B 가 그대로
                                // 다시 열리고(AITutor 대체 후보) 다운로드 카드는
                                // .missing 에서만 뜨니 영영 안 떠 — 토글이 무의미했다.
                                // 파일이 이미 있으면 즉시 교체한다.
                                if !ModelDownloader.shared.startForTierSwitch() {
                                    AITutor.shared.loadRecommended()
                                }
                            }
                    }
                    // 티어 전환 다운로드는 채팅 화면 카드(.missing 전용)에 안 잡힌다 —
                    // 시작한 자리에서 끝까지 보여 준다
                    if case .downloading(let p) = downloader.state {
                        Text("\(ModelDownloader.recommended.shortName) 내려받는 중 \(Int(p * 100))%")
                            .font(.mCaption).foregroundStyle(Tokens.text3)
                            .padding(.bottom, Tokens.Space.s3)
                    }
                    if case .failed(let why) = downloader.state {
                        Text("내려받기 실패: \(why)")
                            .font(.mCaption).foregroundStyle(Tokens.dangerInk)
                            .padding(.bottom, Tokens.Space.s3)
                    }
                    DottedRule()
                    #endif
                }
                // 공개 랭킹은 약관·서버 정본과 동일하게 닉네임만 사용한다.
                if store.authProvider == "server" {
                    RankingIdentityRow()
                }

                // 채점 Pro는 기기 내 분석 기능이다. 실제 이용권 상태처럼 보이는
                // 고정 '체험 중' 표시는 제거하고 별도 이용권 허브로 분리한다.
                //
                // 오른쪽 값("분석 도구")과 화살표를 한 줄에 붙여 두면 접근성 글자
                // 크기에서 제목이 설 폭이 남지 않는다. 실측(iPhone 세로 393pt, AX5):
                // "Matths Pro"가 "Ma / tth / s / Pro" 로 한두 글자씩 쪼개졌다.
                // 그럴 때만 값과 화살표를 제목 아래로 내린다. 기본 글자 크기와
                // 모든 iPad 배치는 종전 그대로다.
                Button { store.route = .pro } label: {
                    Group {
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                                proRowCopy
                                HStack(spacing: Tokens.Space.s2) {
                                    proRowValue
                                    disclosureChevron
                                }
                            }
                        } else {
                            HStack(spacing: Tokens.Space.s3) {
                                proRowCopy
                                Spacer()
                                proRowValue
                                disclosureChevron
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Tokens.Space.s3)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                DottedRule()

                // 같은 이유로 아이콘도 접근성 글자 크기에서는 본문 위로 올린다.
                // 30pt 아이콘 옆에 "학원·서비스"가 그려지지 못하고 아이콘
                // 위로 겹쳐 찍혔다(같은 실측).
                Button { store.route = .services } label: {
                    Group {
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                                commerceRowIcon
                                commerceRowCopy
                                disclosureChevron
                            }
                        } else {
                            HStack(spacing: Tokens.Space.s3) {
                                commerceRowIcon
                                commerceRowCopy
                                Spacer(minLength: Tokens.Space.s3)
                                disclosureChevron
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Tokens.Space.s3)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("학원, 자료실, 이용권과 지원 기능을 확인합니다")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
            .entrance(5)

            // 데이터
            VStack(alignment: .leading, spacing: 0) {
                SectionRule(title: "데이터").padding(.bottom, Tokens.Space.s2)

                // 서버 계정만 — 게스트는 큐가 항상 비어 있어 이 줄이 소음이다.
                if store.authProvider == "server" {
                    // 320pt Slide Over 와 iPhone 세로에서는 상태 문장과 버튼이
                    // 한 줄에 못 들어간다. 폭이 판단하게 두고 버튼을 다음 줄로 내린다.
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s4) {
                            syncStatusCopy
                            Spacer(minLength: Tokens.Space.s4)
                            syncNowButton
                        }
                        .frame(minWidth: 360)

                        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                            syncStatusCopy
                            syncNowButton
                        }
                    }
                    .padding(.vertical, Tokens.Space.s3)
                    DottedRule()
                }

                Button { confirmReset = true } label: {
                    dataRow("진도 초기화",
                            tint: Tokens.dangerInk,
                            caption: "완료 개념 \(completedConceptCount)개, 통계 포함")
                }
                .buttonStyle(.plain)
                .confirmationDialog("진도를 초기화할까요?", isPresented: $confirmReset, titleVisibility: .visible) {
                    Button(store.authProvider == "server"
                           ? "계정과 이 기기의 진도 지우기"
                           : "완료 기록과 통계를 모두 지우기", role: .destructive) {
                        // AppStore가 구/v2 진도·통계와 즉시 내구 저장을 한 경계에서 끝낸다.
                        // 호출부가 v2를 한 번 더 비우면 pending 세대 순서가 다시 갈라진다.
                        Task {
                            if !(await store.resetProgress()) {
                                resetError = "초기화 기록을 안전하게 저장하지 못했습니다. 저장 공간을 확인하고 앱을 종료하지 않은 채 다시 시도해주세요."
                            }
                        }
                    }
                    Button("취소", role: .cancel) {}
                } message: {
                    if store.authProvider == "server" {
                        Text("계정과 이 기기에 저장된 완료 기록 \(completedConceptCount)개와 누적 통계가 지워집니다. 오프라인이면 초기화 요청을 보관했다가 연결되는 즉시 계정 진도에 반영합니다. 되돌릴 수 없습니다.")
                    } else {
                        Text("완료한 개념 \(completedConceptCount)개와 누적 통계가 지워집니다. 되돌릴 수 없습니다.")
                    }
                }
                .disabled(store.progressResetInFlight)

                DottedRule()

                Button { store.signOut() } label: {
                    HStack {
                        Text(store.authProvider == "guest" ? "게스트 나가고 로그인하기" : "로그아웃")
                            .font(.mBody).foregroundStyle(Tokens.text1)
                        Spacer()
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.mCaption).foregroundStyle(Tokens.text3)
                    }
                    .padding(.vertical, Tokens.Space.s3)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(store.progressResetInFlight)

                // ── 회원 탈퇴 (명세 2.12 · DELETE /api/v1/me) ──────────────
                // 서버 계정에만 보인다. 게스트는 지울 서버 계정이 없다.
                //
                // **익명 보존 탈퇴다.** 계정을 물리적으로 지우는 게 아니라 개인정보를
                // 무효값으로 치환하고 학습 데이터는 익명으로 남긴다. 그 사실을
                // 버튼 옆이 아니라 **확인 화면에서 분명히 적는다** — 되돌릴 수 없는
                // 동작인데 "탈퇴하면 다 지워진다" 고 오해하게 두면 안 된다.
                if store.authProvider == "server" {
                    DottedRule()
                    Button { showWithdraw = true } label: {
                        dataRow("회원 탈퇴",
                                tint: Tokens.dangerInk,
                                caption: "개인정보 삭제, 학습 데이터는 익명 보존")
                    }
                    .buttonStyle(.plain)
                    .disabled(store.progressResetInFlight)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
            .entrance(6)
            // 계정 삭제는 중간 높이 sheet의 드래그 제스처와 내부 ScrollView가
            // 충돌하면 안 된다. iPhone 가로에서도 끝의 동의/삭제 버튼까지 확실히
            // 도달하도록 독립된 전체 화면 흐름으로 연다.
            .fullScreenCover(isPresented: $showWithdraw) { WithdrawSheet() }

            // 정보
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                SectionRule(title: "정보")
                HStack {
                    Text("버전 \(appVersion)").font(.mCaption).foregroundStyle(Tokens.text3)
                    Spacer()
                }
                // 44pt 를 HStack 에 걸면 줄만 높아지고 정작 링크의 표적은 글자
                // 높이(13pt)에 머문다. 링크마다 각자 44pt 를 갖게 한다.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Tokens.Space.s4) {
                        policyAndSupportLinks
                        Spacer(minLength: 0)
                    }
                    .fixedSize(horizontal: true, vertical: false)

                    VStack(alignment: .leading, spacing: 0) {
                        policyAndSupportLinks
                    }
                }
                .font(.mCaption)
                .foregroundStyle(Tokens.actionPrimary)
                .accessibilityElement(children: .contain)

                // 오픈소스 고지 — 온디바이스 AI 탑재로 필수가 된 항목 (Apache 2.0 고지 의무)
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                        ForEach(Self.licenses, id: \.0) { name, license, url in
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(name) (\(license))")
                                    .font(.mCaption).foregroundStyle(Tokens.text2)
                                Text(url).font(.mMicro).foregroundStyle(Tokens.text4)
                            }
                        }
                        // KICE 원문은 권리 확인 전에 오픈소스 라이선스로 오인되면 안 된다.
                        // 해당 리소스를 명시적으로 복사하는 내부 Debug 빌드에서만
                        // 소유권과 배포 제한을 표시한다. ‘학습 연구 목적’은 사용 허락이 아니다.
                        if !KiceBank.exams.isEmpty {
                            Text("내부 검증 빌드에 포함된 수능과 모의평가 기출 문항의 저작권은 한국교육과정평가원에 있습니다. 사용 허락을 확인하지 않은 기출 원문은 정식 배포 빌드에 포함하지 않습니다.")
                                .font(.mMicro).foregroundStyle(Tokens.text4)
                                .padding(.top, Tokens.Space.s1)
                        }
                    }
                    .padding(.top, Tokens.Space.s2)
                } label: {
                    // "오픈소스"라고 부르지 않는다 — 목록에 OSI 오픈소스가 아닌
                    // GSAP 이 들어 있다. 성격을 잘못 부른 고지는 고지가 아니다.
                    Text(KiceBank.exams.isEmpty ? "서드파티 라이선스" : "서드파티 라이선스 및 저작권 고지")
                        .font(.mCaption).foregroundStyle(Tokens.text3)
                        .frame(minHeight: 44, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .tint(Tokens.text3)
            }
            .entrance(7)
        }
        .alert(
            "진도를 초기화하지 못했습니다",
            isPresented: Binding(
                get: { resetError != nil },
                set: { if !$0 { resetError = nil } })
        ) {
            Button("확인", role: .cancel) { resetError = nil }
        } message: {
            Text(resetError ?? "")
        }
        .task(id: "\(store.authProvider ?? "guest")|\(DataScope.slot)") {
            await refreshServerProfile()
        }
        .compactHeightSheet(isPresented: $showProfilePhotoCropper) {
            ProfilePhotoCropPicker(
                onCancel: { showProfilePhotoCropper = false },
                onPick: { image in
                    showProfilePhotoCropper = false
                    Task { await uploadProfilePhoto(image) }
                })
                .ignoresSafeArea()
        }
        .compactHeightSheet(isPresented: $showNicknameEditor) {
            nicknameEditor
        }
    }

    /// 가입 전 화면과 같은 세 정책·지원 진입점. 큰 글자에서는 부모
    /// ViewThatFits가 세로로 내려 링크의 44pt 조작 영역을 보존한다.
    @ViewBuilder private var policyAndSupportLinks: some View {
        Link("이용약관", destination: ServerAPI.baseURL.appendingPathComponent("terms"))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        Link("개인정보 처리방침", destination: ServerAPI.baseURL.appendingPathComponent("privacy"))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        Link("고객지원", destination: ServerAPI.baseURL.appendingPathComponent("faq"))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }

    /// 고지 대상 — 번들·다운로드로 탑재되는 서드파티 전부.
    ///
    /// **전부가 오픈소스는 아니다.** GSAP 은 "All rights reserved" 인 독자 라이선스로,
    /// 무상으로 쓸 수 있을 뿐 OSI 오픈소스가 아니다. 그래서 이 목록의 제목도
    /// "오픈소스"가 아니라 "서드파티"라고 부른다 — 목록에 넣으면서 성격을 잘못
    /// 부르면 고지를 안 한 것만 못하다.
    ///
    /// 여기 없는데 번들에 들어가는 것이 있으면 그게 곧 결함이다. 폰트·음성처럼
    /// 사용자에게 보이지 않는 자산도 마찬가지다.
    private static let licenses: [(String, String, String)] = [
        ("Qwen3.5 (Alibaba Cloud)", "Apache License 2.0", "huggingface.co/Qwen"),
        ("Qwen2.5-VL 3B (Alibaba Cloud)", "Apache License 2.0", "huggingface.co/Qwen"),
        ("DeepSeek-R1-Distill-Qwen-7B", "MIT License", "huggingface.co/deepseek-ai"),
        ("llama.cpp (ggml-org)", "MIT License", "github.com/ggml-org/llama.cpp"),
        ("KaTeX", "MIT License", "katex.org"),
        ("Pretendard", "SIL Open Font License 1.1", "github.com/orioncactus/pretendard"),
        ("lottie-web (Airbnb)", "MIT License", "github.com/airbnb/lottie-web"),
        // 개념 모션 220편이 GSAP 타임라인 위에서 돈다. 오프라인 교실을 위해
        // vendor/gsap.min.js 사본을 번들에 넣으므로(ConceptMotionWebStage.swift:65)
        // 탑재 대상이다. MIT 가 아니라 GreenSock 독자 라이선스다.
        ("GSAP 3.14.2 (GreenSock)", "GreenSock Standard License", "gsap.com/standard-license"),
    ]

    // MARK: 조각들

    /// Matths Pro 행의 제목 묶음. 제목과 PRO 배지도 폭이 모자라면 위아래로 갈라진다.
    private var proRowCopy: some View {
        VStack(alignment: .leading, spacing: 2) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    proRowTitle
                    proBadge
                }
                VStack(alignment: .leading, spacing: 4) {
                    proRowTitle
                    proBadge
                }
            }
            Text("시험지 사진 채점, 약한 유형 자동 모의고사")
                .font(.mCaption).foregroundStyle(Tokens.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var proRowTitle: some View {
        Text("Matths Pro").font(.mBodyB).foregroundStyle(Tokens.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var proBadge: some View {
        Text("PRO").font(.mMicro)
            .foregroundStyle(Tokens.onBrand)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Tokens.actionPrimary,
                        in: RoundedRectangle(cornerRadius: 5))
    }

    private var proRowValue: some View {
        Text("분석 도구").font(.mCaption).foregroundStyle(Tokens.text3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var commerceRowIcon: some View {
        Image(systemName: "square.grid.2x2")
            .font(.mHeading)
            .foregroundStyle(Tokens.primary)
            .frame(width: 30)
            // 옆의 "학원·서비스"가 같은 말을 한다. 심볼 이름까지 읽히면 소음이다.
            .accessibilityHidden(true)
    }

    private var commerceRowCopy: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("학원·서비스")
                .font(.mBodyB)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("학원, 자료실, 이용권과 고객 지원")
                .font(.mCaption)
                .foregroundStyle(Tokens.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 데이터 섹션의 한 줄. 왼쪽은 동작 이름, 오른쪽은 부연이다. 한 줄에 다 못 들어가면
    /// 부연을 아래로 내린다. 큰 글자에서는 두 문장이 서로를 두 글자 열로 만들었다.
    private func dataRow(_ title: String, tint: Color, caption: String) -> some View {
        let titleText = Text(title).font(.mBody).foregroundStyle(tint)
            .fixedSize(horizontal: false, vertical: true)
        let captionText = Text(caption).font(.mCaption).foregroundStyle(Tokens.text4)
            .fixedSize(horizontal: false, vertical: true)

        return ViewThatFits(in: .horizontal) {
            HStack {
                titleText
                Spacer(minLength: Tokens.Space.s4)
                captionText
            }
            .frame(minWidth: 320)

            VStack(alignment: .leading, spacing: 3) {
                titleText
                captionText
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Tokens.Space.s3)
        .contentShape(Rectangle())
    }

    private var disclosureChevron: some View {
        Image(systemName: "chevron.right")
            .font(.mMicro)
            .foregroundStyle(Tokens.text4)
            .accessibilityHidden(true)
    }

    /// 동기화 상태 문장 — 좁은 폭에서는 버튼과 위아래로 갈라진다.
    private var syncStatusCopy: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("서버 동기화").font(.mBody).foregroundStyle(Tokens.text1)
            Text(syncStatusLine).font(.mCaption).foregroundStyle(Tokens.text3)
                .fixedSize(horizontal: false, vertical: true)
            if let e = sync.lastError {
                // 내부 오류 원문이 아니라 학생이 지금 할 수 있는 복구 행동을 보여준다.
                Text(e).font(.mMicro).foregroundStyle(Tokens.dangerInk)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var syncNowButton: some View {
        Button("지금 동기화") {
            Task { await SyncEngine.shared.syncNow() }
        }
        .font(.mCaption).foregroundStyle(Tokens.primary)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .buttonStyle(.plain)
    }

    private var profileAvatar: some View {
        // 세로가 짧은 창에서는 원판을 줄여 계정 카드가 화면 절반을 먹지 않게 한다.
        let side: CGFloat = compactHeight ? 48 : 62
        return ZStack {
            Circle().fill(Tokens.actionPrimary)
            if let source = serverProfile?.profileAvatar?.imageSrc,
               let url = URL(string: source, relativeTo: ServerAPI.baseURL)?.absoluteURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Text(String(store.userName.prefix(1)))
                            .font(.system(size: compactHeight ? 20 : 24, weight: .heavy))
                            .foregroundStyle(Tokens.onBrand)
                    }
                }
            } else {
                Text(String(store.userName.prefix(1)))
                    .font(.system(size: compactHeight ? 20 : 24, weight: .heavy))
                    .foregroundStyle(Tokens.onBrand)
            }
        }
        .frame(width: side, height: side)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var accountIdentity: some View {
        VStack(alignment: .leading, spacing: 5) {
            // 서버 정본 이름은 읽기 전용이다. 접근성 글자 크기에서는 아바타 아래
            // 전폭을 쓰므로 긴 닉네임도 한 글자 열로 찌그러지지 않는다.
            if store.authProvider == "server" {
                ViewThatFits(in: .horizontal) {
                    Text("\(store.userName)님")
                        .font(.mHeading)
                        .foregroundStyle(Tokens.ink)
                        .fixedSize(horizontal: true, vertical: false)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.userName)
                            .font(.mBodyB)
                            .foregroundStyle(Tokens.ink)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text("님")
                            .font(.mBodyB)
                            .foregroundStyle(Tokens.ink)
                    }
                }
            } else {
                HStack(spacing: 2) {
                    TextField("이름", text: $store.userName)
                        .font(.mHeading).foregroundStyle(Tokens.ink)
                        .textFieldStyle(.plain)
                        .frame(minWidth: 0)
                        .layoutPriority(1)
                        .submitLabel(.done)
                    Text("님").font(.mHeading).foregroundStyle(Tokens.ink)
                    Image(systemName: "pencil").font(.mMicro).foregroundStyle(Tokens.text4)
                }
                // 테두리 없는 입력이라 손가락이 노릴 곳이 글자 높이뿐이었다.
                .frame(minHeight: 44)
            }
            if let level = serverProfile?.arenaActivityLevel {
                Text("Arena Lv.\(level.level) · 누적 \(level.totalMatches)경기")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.primary)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    providerBadge
                    Text(store.gradeLabel).font(.mCaption).foregroundStyle(Tokens.text3)
                }
                VStack(alignment: .leading, spacing: 4) {
                    providerBadge
                    Text(store.gradeLabel).font(.mCaption).foregroundStyle(Tokens.text3)
                }
            }
            if store.authProvider == "server" {
                Button {
                    nicknameDraft = store.userName
                    nicknameError = nil
                    showNicknameEditor = true
                } label: {
                    Label("닉네임 변경", systemImage: "pencil")
                        .font(.mCaption)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Tokens.primary)
                .disabled(nicknameSaving)
            }
            if !store.userEmail.isEmpty {
                Text(store.userEmail)
                    .font(.mMicro).foregroundStyle(Tokens.text4)
                    .lineLimit(1).truncationMode(.middle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nicknameEditor: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("닉네임 변경")
                        .font(.mTitle)
                        .foregroundStyle(Tokens.ink)
                    Text("게시판과 공개 랭킹에 표시되는 이름입니다")
                        .font(.mCaption)
                        .foregroundStyle(Tokens.text3)
                }
                Spacer()
                Button("닫기") { showNicknameEditor = false }
                    .frame(minHeight: 44)
                    .disabled(nicknameSaving)
            }

            TextField("새 닉네임", text: $nicknameDraft)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit { Task { await saveNickname() } }

            HStack {
                Text("2–30자 · 꺾쇠 문자(< >) 제외")
                    .font(.mMicro)
                    .foregroundStyle(Tokens.text3)
                Spacer()
                Text("\(nicknameDraft.count)/30")
                    .font(.mMicro.monospacedDigit())
                    .foregroundStyle(nicknameDraft.count > 30 ? Tokens.danger : Tokens.text3)
            }

            if let nicknameError {
                Label(nicknameError, systemImage: "exclamationmark.circle.fill")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.dangerInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Task { await saveNickname() }
            } label: {
                HStack {
                    if nicknameSaving { ProgressView().tint(Tokens.onPrimary) }
                    Text(nicknameSaving ? "저장 중" : "닉네임 저장")
                }
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(nicknameSaving || !nicknameDraftIsValid)
        }
        .padding(Tokens.Space.s5)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.paper)
        .onAppear {
            if nicknameDraft.isEmpty { nicknameDraft = store.userName }
        }
    }

    private var nicknameDraftIsValid: Bool {
        let value = nicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        return (2...30).contains(value.count) && !value.contains("<") && !value.contains(">")
    }

    @MainActor
    private func saveNickname() async {
        guard nicknameDraftIsValid, !nicknameSaving else { return }
        nicknameSaving = true
        nicknameError = nil
        defer { nicknameSaving = false }
        do {
            let user = try await ServerAPI.updateNickname(nicknameDraft)
            let savedName = user.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !savedName.isEmpty else {
                throw ServerAPIError(message: "저장된 닉네임을 확인하지 못했습니다.", code: "NICKNAME_RESPONSE_INVALID")
            }
            store.userName = savedName
            serverProfile = user
            nicknameDraft = savedName
            showNicknameEditor = false
        } catch {
            nicknameError = (error as? ServerAPIError)?.errorDescription
                ?? "닉네임을 저장하지 못했습니다. 잠시 후 다시 시도해 주세요."
        }
    }

    private var providerBadge: some View {
        let (label, fg, bg): (String, Color, Color) = switch store.authProvider {
        case "kakao":  ("카카오 로그인", Color(hex: 0x191600), Color(hex: 0xFEE500))
        case "google": ("Google 로그인", Color(hex: 0x1F1F1F), Color(hex: 0xF1F3F4))
        case "server": ("Matths 계정", Tokens.onPrimary, Tokens.primary)
        case "debug":  ("DEBUG", Tokens.text2, Tokens.paper2)
        default:       ("게스트", Tokens.text2, Tokens.paper2)
        }
        return Text(label).font(.mMicro).foregroundStyle(fg)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(bg, in: Capsule())
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var gradeLabel: some View {
        Text(store.gradeLabel).font(.mBody).foregroundStyle(Tokens.ink)
    }

    private var gradeCaption: some View {
        Text("서버 기준, 매년 3월 1일 자동 승급")
            .font(.mCaption).foregroundStyle(Tokens.text4)
    }

    private func stat(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.mMicro).foregroundStyle(Tokens.text3)
            (Text(value).font(.mStat).foregroundStyle(Tokens.ink)
             + Text(" \(unit)").font(Font.stat(12)).foregroundStyle(Tokens.text3))
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(Tokens.line).frame(width: 1, height: 40)
    }

    private func settingRow(_ title: String, caption: String,
                            @ViewBuilder control: () -> some View) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Tokens.Space.s4) {
                settingCopy(title, caption: caption)
                    .fixedSize(horizontal: true, vertical: true)
                Spacer(minLength: Tokens.Space.s4)
                control()
            }

            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                settingCopy(title, caption: caption)
                control()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, Tokens.Space.s3)
    }

    private func settingCopy(_ title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.mBodyB).foregroundStyle(Tokens.ink)
            Text(caption).font(.mCaption).foregroundStyle(Tokens.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// "보낼 기록 N건 · 마지막 성공 3분 전" — 대기 큐와 마지막 성공 시각을 한 줄로.
    /// 성공 기록이 아직 없으면 없다고 말한다(있는 척하지 않는다).
    private var syncStatusLine: String {
        let queuePart = sync.pending == 0 ? "보낼 기록 없음" : "보낼 기록 \(sync.pending)건"
        guard let at = sync.lastSyncedAt else {
            return "\(queuePart), 이번 실행에서 아직 동기화 성공 없음"
        }
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.unitsStyle = .short
        return "\(queuePart), 마지막 성공 \(f.localizedString(for: at, relativeTo: Date()))"
    }
}

// MARK: - 학교 선택 (경쟁전 리그)

/// 서버 학교 목록은 앱 번들보다 먼저 갱신될 수 있다. 서버가 검증해 돌려준
/// 학교명까지 계정 슬롯에 보관해야 `Schools.find`에 아직 없는 학교도 재실행 후
/// "학교 미설정"으로 되돌아가지 않는다.
private struct ServerVerifiedSchoolRecord: Codable {
    let region: String
    let code: String
    let name: String
}

private extension AppStore {
    static var serverVerifiedSchoolKey: String {
        AppStore.slotKey("matths.serverVerifiedSchool")
    }

    var profileSchoolName: String? {
        guard let region = schoolRegion, let code = schoolCode else { return nil }
        if let data = UserDefaults.standard.data(forKey: Self.serverVerifiedSchoolKey),
           let record = try? JSONDecoder().decode(ServerVerifiedSchoolRecord.self, from: data),
           record.region == region,
           record.code == code,
           !record.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return record.name
        }
        return schoolName
    }

    func setServerVerifiedSchool(region: String, code: String, name: String) {
        schoolRegion = region
        schoolCode = code
        let record = ServerVerifiedSchoolRecord(region: region, code: code, name: name)
        if let data = try? JSONEncoder().encode(record) {
            UserDefaults.standard.set(data, forKey: Self.serverVerifiedSchoolKey)
        }
    }

    func clearServerVerifiedSchool() {
        schoolRegion = nil
        schoolCode = nil
        UserDefaults.standard.removeObject(forKey: Self.serverVerifiedSchoolKey)
    }
}

struct SchoolPickerRow: View {
    @EnvironmentObject private var store: AppStore
    @State private var showPicker = false
    @State private var saving = false
    @State private var errorText: String?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Tokens.Space.s4) {
                schoolCopy
                Spacer(minLength: Tokens.Space.s4)
                schoolButton
            }
            .frame(minWidth: 360)

            VStack(alignment: .leading, spacing: 3) {
                schoolCopy
                schoolButton
            }
        }
        .padding(.vertical, Tokens.Space.s2)
        .compactHeightSheet(isPresented: $showPicker) {
            APISchoolPickerSheet { region, code, _ in
                chooseSchool(region: region, code: code)
            }
        }
        .onChange(of: DataScope.slot) { _, _ in
            // 계정을 바꾼 뒤 앞 계정 요청의 실패 문구가 새 프로필에 남지 않는다.
            saving = false
            errorText = nil
        }
        .task(id: "\(store.authProvider ?? "guest")|\(DataScope.slot)") {
            await refreshServerSchool()
        }
    }

    private var schoolCopy: some View {
        let displayedSchoolName = store.profileSchoolName
        return VStack(alignment: .leading, spacing: 3) {
            Text(displayedSchoolName ?? "학교 미설정")
                .font(.mBodyB)
                .foregroundStyle(displayedSchoolName == nil ? Tokens.text3 : Tokens.ink)
            Text(store.schoolRegion.map { "\($0), 학교 리그 집계 기준" }
                 ?? "학교를 고르면 학교 리그에 참가합니다")
                .font(.mCaption).foregroundStyle(Tokens.text3)
                .fixedSize(horizontal: false, vertical: true)
            if saving {
                Label("학교 리그 기준을 서버에 반영하는 중", systemImage: "arrow.triangle.2.circlepath")
                    .font(.mMicro)
                    .foregroundStyle(Tokens.text3)
            } else if let errorText {
                Text(errorText)
                    .font(.mMicro)
                    .foregroundStyle(Tokens.dangerInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var schoolButton: some View {
        // 캡슐 테두리는 36pt 그대로 두고(iPad 에서 보던 그 크기), 그 바깥으로
        // 히트 영역만 44pt 까지 넓힌다. 손가락으로 눌러야 하는 표적이다.
        Button(saving ? "반영 중…" : (store.profileSchoolName == nil ? "학교 선택" : "변경")) {
            errorText = nil
            showPicker = true
        }
            .font(.mCaption).foregroundStyle(Tokens.primary)
            .padding(.horizontal, Tokens.Space.s4)
            .frame(minHeight: 36)
            .overlay(Capsule().strokeBorder(Tokens.primary, lineWidth: 1.1))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
            .disabled(saving)
    }

    private func chooseSchool(region: String, code: String) {
        errorText = nil

        // 게스트는 서버 정본이 없으므로 기존 로컬 저장이 맞다.
        guard store.authProvider == "server" else {
            store.setSchool(region: region, code: code)
            return
        }

        let accountSlot = DataScope.slot
        saving = true
        Task {
            do {
                let user = try await ServerAPI.updateSchool(region: region, code: code)
                await MainActor.run {
                    // 요청 중 로그아웃·계정 전환이 일어났다면 앞 계정 응답을 새 계정에
                    // 붙이지 않는다. 서버에는 올바른 앞 계정으로 이미 반영되어 있다.
                    guard store.authProvider == "server", DataScope.slot == accountSlot else {
                        return
                    }
                    guard let school = user.school,
                          let confirmedRegion = school.region,
                          let confirmedCode = school.code,
                          let confirmedName = school.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !confirmedName.isEmpty else {
                        errorText = "서버가 변경된 학교를 확인하지 못했습니다. 다시 시도해 주세요."
                        return
                    }
                    store.setServerVerifiedSchool(
                        region: confirmedRegion,
                        code: confirmedCode,
                        name: confirmedName)
                }
            } catch {
                await MainActor.run {
                    guard store.authProvider == "server", DataScope.slot == accountSlot else {
                        return
                    }
                    errorText = (error as? ServerAPIError)?.errorDescription
                        ?? "학교를 변경하지 못했습니다. 연결을 확인한 뒤 다시 시도해 주세요."
                }
            }
            await MainActor.run {
                if DataScope.slot == accountSlot { saving = false }
            }
        }
    }

    /// 프로필을 열 때 서버 DTO를 다시 받아 다른 기기·웹에서 바꾼 학교도 맞춘다.
    /// 네트워크 실패 때는 마지막 확인값을 유지하고, 서버가 명시적으로 학교 없음으로
    /// 응답했을 때만 로컬 값을 비운다.
    private func refreshServerSchool() async {
        guard store.authProvider == "server" else { return }
        let accountSlot = DataScope.slot
        do {
            let user = try await ServerAPI.me()
            await MainActor.run {
                guard store.authProvider == "server", DataScope.slot == accountSlot else { return }
                guard let school = user.school else {
                    store.clearServerVerifiedSchool()
                    return
                }
                guard let region = school.region,
                      let code = school.code,
                      let name = school.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !name.isEmpty else { return }
                store.setServerVerifiedSchool(region: region, code: code, name: name)
            }
        } catch {
            // 이 동기화는 마지막 확인값을 보강하는 작업이다. 일시적인 오프라인에서
            // 이미 보이는 학교를 지우거나 프로필 진입을 막지 않는다.
        }
    }
}

/// 공개 랭킹은 닉네임 전용이다. 실명은 계정 확인에만 사용하고 노출하지 않는다.
struct RankingIdentityRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    rankingIdentityCopy
                    Spacer(minLength: Tokens.Space.s4)
                    identityBadge
                }

                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    rankingIdentityCopy
                    identityBadge
                }
            }
            Text("가입 시 등록한 실명은 계정 확인에만 사용하며 다른 학생에게 공개하지 않습니다.")
                .font(.mMicro).foregroundStyle(Tokens.text4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Tokens.Space.s2)
    }

    private var rankingIdentityCopy: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("랭킹 공개 이름").font(.mBodyB).foregroundStyle(Tokens.ink)
            Text("GOAT Arena와 랭킹에서 다른 학생에게 보이는 이름")
                .font(.mCaption).foregroundStyle(Tokens.text3)
        }
    }

    private var identityBadge: some View {
        Text("닉네임")
            .font(.mCaption).foregroundStyle(Tokens.primary)
            .padding(.horizontal, Tokens.Space.s3).padding(.vertical, 7)
            .background(Tokens.paper2, in: Capsule())
            .accessibilityLabel("공개 이름: 닉네임")
    }
}

// MARK: - 회원 탈퇴 시트 (명세 2.12)
//
// 서버가 요구하는 세 가지를 **화면에서 그대로 받는다** — 비밀번호, 확인 문구 "탈퇴",
// 익명 보존 동의. 하나라도 빠지면 서버가 400 을 준다. 앱이 미리 막아 주는 편이
// 낫지만, 문구 검사를 앱이 임의로 완화하지는 않는다(서버가 진실원이다).
//
// 이 화면이 하지 않는 것: "정말요?" 를 두 번 묻지 않는다. 확인 문구를 직접 치는 것이
// 이미 그 역할이다. 대신 **무엇이 남고 무엇이 지워지는지**를 숨기지 않고 적는다.
private struct WithdrawSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var password = ""
    @State private var phrase = ""
    @State private var agreed = false
    @State private var busy = false
    @State private var errorText: String?
    @State private var options: ServerAPI.WithdrawalOptions?
    @State private var googleReauthentication:
        ServerAPI.GoogleWithdrawalReauthentication?
    @State private var appleReauthentication:
        ServerAPI.AppleWithdrawalReauthentication?
    @State private var kakaoReauthentication:
        ServerAPI.KakaoWithdrawalReauthentication?
    @State private var googleBusy = false
    @State private var appleBusy = false
    @State private var kakaoBusy = false
    private enum FocusedField { case password, phrase }
    @FocusState private var focusedField: FocusedField?
    /// 서버가 탈퇴 옵션 라우트(/me/withdrawal/options)를 제공하지 않을 때(404) true.
    /// 구버전 서버에서는 소셜 재확인 경로가 없다는 사실을 숨기지 않는다.
    @State private var withdrawalOptionsUnsupported = false
    /// 404가 아닌 조회 실패. 이메일 계정의 비밀번호 탈퇴는 계속 열어 두되,
    /// 소셜 전용 계정이 빈 비밀번호 칸 앞에서 이유 없이 막히지 않게 알린다.
    @State private var withdrawalOptionsLoadError: String?
    @State private var loadingWithdrawalOptions = false
    @StateObject private var google = GoogleSignInCoordinator()
    @StateObject private var apple = AppleSignInCoordinator()
    @StateObject private var kakao = KakaoSignInCoordinator()

    private var canSubmit: Bool {
        (googleReauthentication != nil || appleReauthentication != nil
            || kakaoReauthentication != nil || !password.isEmpty)
            && phrase.trimmingCharacters(in: .whitespaces) == ServerAPI.withdrawConfirmationPhrase
            && agreed && !busy && !googleBusy && !appleBusy && !kakaoBusy
    }

    private var usesCompactHeightActionBar: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                CompactHeightColumns(
                    spacing: Tokens.Space.s5,
                    stackedSpacing: Tokens.Space.s5
                ) {
                    VStack(alignment: .leading,
                           spacing: usesCompactHeightActionBar
                               ? Tokens.Space.s1 : Tokens.Space.s2) {
                        Text("탈퇴하면 이렇게 됩니다")
                            .font(.mBodyB).foregroundStyle(Tokens.ink)
                        // 명세 2.12 를 사용자 말로 옮긴 것. 지어내지 않는다.
                        bullet("이름과 이메일 같은 개인정보는 무효값으로 바뀝니다")
                        bullet("학습 기록은 이름을 지운 채 통계로만 남습니다")
                        bullet("랭킹에서 빠집니다. 순위표에 더 이상 보이지 않습니다")
                        bullet("쓴 글과 댓글은 익명 처리됩니다")
                        bullet("학교는 광역 지역 수준만 남습니다")
                        bullet("지금 로그인된 모든 기기에서 즉시 로그아웃됩니다")

                        Divider().overlay(Tokens.warningInk.opacity(0.28))

                        Text("Apple 구독은 별도로 해지해야 합니다")
                            .font(.mBodyB)
                            .foregroundStyle(Tokens.warningInk)
                        Text("회원 탈퇴만으로 App Store 자동 갱신은 취소되지 않습니다. 다음 청구를 원하지 않으면 탈퇴 전에 구독을 해지해 주세요. 남은 이용기간과 결제 내역은 새 Matths 계정으로 자동 이전되지 않습니다.")
                            .font(.mCaption)
                            .foregroundStyle(Tokens.text2)
                            .fixedSize(horizontal: false, vertical: true)
                        Link(destination: Self.appleSubscriptionsURL) {
                            Label("Apple 구독 관리 열기", systemImage: "arrow.up.right.square")
                                .font(.mCaption)
                                .foregroundStyle(Tokens.warningInk)
                                .frame(minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .accessibilityHint("App Store의 구독 관리 화면을 엽니다")
                    }
                    .padding(usesCompactHeightActionBar
                             ? Tokens.Space.s3 : Tokens.Space.s4)
                    .background(Tokens.dangerSoft,
                                in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                    .accessibilityElement(children: .contain)
                    .accessibilitySortPriority(2)
                } trailing: {
                    VStack(alignment: .leading, spacing: Tokens.Space.s5) {
                        VStack(alignment: .leading,
                               spacing: usesCompactHeightActionBar
                                   ? Tokens.Space.s2 : Tokens.Space.s3) {
                            if usesCompactHeightActionBar {
                                compactReauthenticationControls
                            } else if reauthenticationProviderName != nil {
                                reauthenticationCompletedLabel
                            } else {
                                Text("현재 비밀번호").font(.mCaption).foregroundStyle(Tokens.text3)
                                SecureField("비밀번호", text: $password)
                                    .textContentType(.password)
                                    .textFieldStyle(.roundedBorder)
                                    .focused($focusedField, equals: .password)
                                    .submitLabel(.next)
                                    .onSubmit { focusedField = .phrase }

                                if options?.googleReauthentication.linked == true {
                                    googleButton(fullWidth: true)

                                    if options?.googleReauthentication.available == false {
                                        Text("현재 Google 본인 확인을 시작할 수 없습니다. 아래에서 다시 불러오거나 고객센터로 문의해 주세요.")
                                            .font(.mCaption).foregroundStyle(Tokens.dangerInk)
                                    } else {
                                        Text("Google로 가입해 비밀번호가 없다면 이 방법을 사용해주세요.")
                                            .font(.mCaption).foregroundStyle(Tokens.text3)
                                    }
                                }

                                if options?.appleReauthentication.linked == true {
                                    appleButton(fullWidth: true)
                                    if options?.appleReauthentication.available == false {
                                        Text("현재 Apple 본인 확인을 시작할 수 없습니다. 아래에서 다시 불러오거나 고객센터로 문의해 주세요.")
                                            .font(.mCaption).foregroundStyle(Tokens.dangerInk)
                                    } else {
                                        Text("Apple로 가입해 비밀번호가 없다면 이 방법을 사용해주세요.")
                                            .font(.mCaption).foregroundStyle(Tokens.text3)
                                    }
                                }

                                if options?.kakaoReauthentication.linked == true {
                                    kakaoButton(fullWidth: true)
                                    if options?.kakaoReauthentication.available == false {
                                        Text("현재 카카오 본인 확인을 시작할 수 없습니다. 아래에서 다시 불러오거나 고객센터로 문의해 주세요.")
                                            .font(.mCaption).foregroundStyle(Tokens.dangerInk)
                                    } else {
                                        Text("카카오로 가입해 비밀번호가 없다면 이 방법을 사용해주세요.")
                                            .font(.mCaption).foregroundStyle(Tokens.text3)
                                    }
                                }

                                if withdrawalOptionsUnsupported {
                                    Text("현재 소셜 계정 본인 확인을 시작할 수 없습니다. 비밀번호가 없는 계정은 아래 고객센터로 문의해 주세요.")
                                        .font(.mCaption).foregroundStyle(Tokens.text3)
                                        .fixedSize(horizontal: false, vertical: true)
                                    withdrawalSupportLink
                                }

                                withdrawalOptionsRetry
                            }

                            Text("확인 문구로 \(ServerAPI.withdrawConfirmationPhrase) 라고 입력")
                                .font(.mCaption).foregroundStyle(Tokens.text3)
                            TextField(ServerAPI.withdrawConfirmationPhrase, text: $phrase)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .phrase)
                                .submitLabel(.done)
                                .onSubmit { focusedField = nil }

                            Toggle(isOn: $agreed) {
                                Text("학습 데이터가 익명으로 보존되는 것에 동의합니다")
                                    .font(.mCallout).foregroundStyle(Tokens.text2)
                            }
                            .tint(Tokens.primary)
                        }

                        if let e = errorText {
                            Text(e).font(.mCaption).foregroundStyle(Tokens.dangerInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if !usesCompactHeightActionBar {
                            submitButton
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilitySortPriority(1)
                }
                .padding(.horizontal, Tokens.Space.s5)
                .padding(.vertical, usesCompactHeightActionBar
                         ? Tokens.Space.s2 : Tokens.Space.s5)
            }
            .scrollIndicators(.visible)
            .scrollDismissesKeyboard(.interactively)
            .background(Tokens.paper)
            .navigationTitle("회원 탈퇴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // iPhone 가로에서는 키보드와 고정 탈퇴 버튼을 함께 띄우면 오른쪽 열의
            // 확인 문구 입력칸을 둘이 위아래에서 가린다. 입력 중에는 바를 걷어
            // ScrollView가 포커스된 필드를 키보드 위로 올릴 공간을 돌려준다.
            if usesCompactHeightActionBar && focusedField == nil {
                submitButton
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .safeAreaPadding(.horizontal, Tokens.Space.s5)
                    .padding(.vertical, Tokens.Space.s2)
                    .background(Tokens.surface)
                    .overlay(alignment: .top) { Divider().overlay(Tokens.line) }
            }
        }
        .task { await loadWithdrawalOptions() }
        .onDisappear {
            google.cancel()
            apple.cancel()
            kakao.cancel()
        }
    }

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack {
                if busy { ProgressView().controlSize(.small) }
                Text(busy ? "처리 중…" : "탈퇴하기")
                    .font(.mBodyB)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Tokens.Space.s3)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Tokens.onPrimary)
        .background(canSubmit ? Tokens.danger : Tokens.text4,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        .disabled(!canSubmit)
        .accessibilitySortPriority(-1)
    }

    private static var appleSubscriptionsURL: URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "apps.apple.com"
        components.path = "/account/subscriptions"
        return components.url ?? ServerAPI.baseURL
    }

    /// iPhone 가로에서는 비밀번호와 소셜 대체 확인을 가까이 둔다. 세로 화면의
    /// 긴 설명을 그대로 쌓으면 동의 스위치가 고정 삭제 버튼 뒤로 밀린다.
    @ViewBuilder
    private var compactReauthenticationControls: some View {
        if reauthenticationProviderName != nil {
            reauthenticationCompletedLabel
        } else {
            Text(hasLinkedSocialReauthentication
                 ? "현재 비밀번호 또는 소셜 계정 본인 확인"
                 : "현재 비밀번호")
                .font(.mCaption).foregroundStyle(Tokens.text3)
            SecureField("비밀번호", text: $password)
                .textContentType(.password)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .password)
                .submitLabel(.next)
                .onSubmit { focusedField = .phrase }

            if hasLinkedSocialReauthentication {
                HStack(spacing: Tokens.Space.s2) {
                    if options?.googleReauthentication.linked == true {
                        googleButton(fullWidth: false)
                    }
                    if options?.appleReauthentication.linked == true {
                        appleButton(fullWidth: false)
                    }
                    if options?.kakaoReauthentication.linked == true {
                        kakaoButton(fullWidth: false)
                    }
                }
            }

            if withdrawalOptionsUnsupported {
                Text("비밀번호가 없는 계정은 고객센터에 문의해주세요.")
                    .font(.mCaption).foregroundStyle(Tokens.text3)
                    .fixedSize(horizontal: false, vertical: true)
                withdrawalSupportLink
            }

            withdrawalOptionsRetry
        }
    }

    /// 옵션 조회 실패는 탈퇴 자체의 실패가 아니다. 비밀번호 사용자는 그대로
    /// 진행할 수 있고, 소셜 사용자는 같은 화면에서 조회만 다시 시도할 수 있다.
    @ViewBuilder
    private var withdrawalOptionsRetry: some View {
        if let withdrawalOptionsLoadError {
            Text(withdrawalOptionsLoadError)
                .font(.mCaption)
                .foregroundStyle(Tokens.dangerInk)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Task { await loadWithdrawalOptions() }
            } label: {
                Label(loadingWithdrawalOptions ? "확인 중…" : "본인 확인 방법 다시 불러오기",
                      systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(loadingWithdrawalOptions || busy)
        }
    }

    private var withdrawalSupportLink: some View {
        Link(destination: ServerAPI.baseURL.appendingPathComponent("faq")) {
            Label("고객지원 열기", systemImage: "questionmark.circle")
                .font(.mCaption)
                .foregroundStyle(Tokens.actionPrimary)
                .frame(minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .accessibilityHint("브라우저에서 고객지원 페이지를 엽니다")
    }

    private var hasLinkedSocialReauthentication: Bool {
        options?.googleReauthentication.linked == true
            || options?.appleReauthentication.linked == true
            || options?.kakaoReauthentication.linked == true
    }

    private var reauthenticationProviderName: String? {
        if appleReauthentication != nil { return "Apple" }
        if kakaoReauthentication != nil { return "카카오" }
        if googleReauthentication != nil { return "Google" }
        return nil
    }

    private var reauthenticationCompletedLabel: some View {
        Label("\(reauthenticationProviderName ?? "소셜 계정") 본인 확인 완료, 5분 동안 한 번만 사용 가능",
              systemImage: "checkmark.shield.fill")
            .font(.mCallout)
            .foregroundStyle(Tokens.successInk)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func googleButton(fullWidth: Bool) -> some View {
        Button {
            Task { await verifyWithGoogle() }
        } label: {
            HStack(spacing: Tokens.Space.s2) {
                Image("GoogleGMark")
                    .resizable().scaledToFit()
                    .frame(width: 18, height: 18)
                    .accessibilityHidden(true)
                if googleBusy { ProgressView().controlSize(.small) }
                Text(googleBusy ? "확인 중…" : (fullWidth ? "Google로 본인 확인" : "Google"))
                    .font(.mBodyB)
            }
            .frame(maxWidth: fullWidth ? .infinity : 170, minHeight: 44)
            .padding(.horizontal, Tokens.Space.s2)
            .background(Tokens.surface,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.md)
                .strokeBorder(Tokens.lineStrong, lineWidth: 1.1))
        }
        .buttonStyle(.plain)
        .disabled(googleBusy || appleBusy || kakaoBusy
                  || options?.googleReauthentication.available != true)
        .accessibilityLabel(googleBusy ? "Google 본인 확인 중" : "Google 본인 확인")
        .accessibilityHint("현재 계정에 연결된 Google 계정으로 본인을 확인합니다")
    }

    private func appleButton(fullWidth: Bool) -> some View {
        Button {
            Task { await verifyWithApple() }
        } label: {
            HStack(spacing: Tokens.Space.s2) {
                Image(systemName: "apple.logo")
                    .accessibilityHidden(true)
                if appleBusy { ProgressView().controlSize(.small) }
                Text(appleBusy ? "확인 중…" : (fullWidth ? "Apple로 본인 확인" : "Apple"))
                    .font(.mBodyB)
            }
            .frame(maxWidth: fullWidth ? .infinity : 170, minHeight: 44)
            .padding(.horizontal, Tokens.Space.s2)
            .background(Tokens.surface,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.md)
                .strokeBorder(Tokens.lineStrong, lineWidth: 1.1))
        }
        .buttonStyle(.plain)
        .disabled(appleBusy || googleBusy || kakaoBusy
                  || options?.appleReauthentication.available != true)
        .accessibilityLabel(appleBusy ? "Apple 본인 확인 중" : "Apple 본인 확인")
        .accessibilityHint("현재 계정에 연결된 Apple 계정으로 본인을 확인합니다")
    }

    private func kakaoButton(fullWidth: Bool) -> some View {
        Button {
            Task { await verifyWithKakao() }
        } label: {
            HStack(spacing: Tokens.Space.s2) {
                Image(systemName: "message.fill")
                    .font(.system(size: 15, weight: .bold))
                    .accessibilityHidden(true)
                if kakaoBusy { ProgressView().controlSize(.small) }
                Text(kakaoBusy ? "확인 중…" : (fullWidth ? "카카오로 본인 확인" : "카카오"))
                    .font(.mBodyB)
            }
            .foregroundStyle(Color(hex: 0x191600))
            .frame(maxWidth: fullWidth ? .infinity : 170, minHeight: 44)
            .padding(.horizontal, Tokens.Space.s2)
            .background(Color(hex: 0xFEE500),
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        }
        .buttonStyle(.plain)
        .disabled(kakaoBusy || googleBusy || appleBusy
                  || options?.kakaoReauthentication.available != true)
        .accessibilityLabel(kakaoBusy ? "카카오 본인 확인 중" : "카카오 본인 확인")
        .accessibilityHint("현재 계정에 연결된 카카오 계정으로 본인을 확인합니다")
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.s2) {
            Image(systemName: "circle.fill")
                .font(.system(size: 5))
                .foregroundStyle(Tokens.dangerInk)
                .padding(.top, 7)
                .accessibilityHidden(true)
            Text(text)
                .font(usesCompactHeightActionBar ? .mCaption : .mCallout)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func submit() async {
        busy = true
        errorText = nil
        defer { busy = false }
        // 네트워크 await 전에 탈퇴 요청을 보낸 세션의 owner를 붙잡는다. 응답을 기다리는
        // 동안 401 로그아웃/새 로그인이 끼어도 guest나 새 계정 슬롯을 지우지 않는다.
        let withdrawn = await MainActor.run {
            (
                slot: DataScope.slot,
                directory: DataScope.directory,
                session: store.captureAccountSessionBoundary()
            )
        }
        do {
            if let appleReauthentication {
                _ = try await ServerAPI.withdrawMe(
                    reauthentication: appleReauthentication,
                    acknowledgeAnonymousRetention: agreed)
            } else if let kakaoReauthentication {
                _ = try await ServerAPI.withdrawMe(
                    reauthentication: kakaoReauthentication,
                    acknowledgeAnonymousRetention: agreed)
            } else if let googleReauthentication {
                _ = try await ServerAPI.withdrawMe(
                    reauthentication: googleReauthentication,
                    acknowledgeAnonymousRetention: agreed)
            } else {
                _ = try await ServerAPI.withdrawMe(
                    password: password,
                    acknowledgeAnonymousRetention: agreed)
            }
            // 서버가 토큰 버전을 올렸으므로 이 기기의 토큰도 이미 무효다.
            // 지연 writer를 먼저 cancel-and-drain해야 아래 디렉터리 삭제 뒤에
            // 필기·답안 파일이 다시 생기지 않는다.
            let stillOwnsSession = store.ownsCurrentAccountSession(withdrawn.session)
            if !stillOwnsSession, DataScope.slot == withdrawn.slot {
                // 같은 이메일로 이미 새 세션이 이 물리 슬롯을 재사용 중이면 old/new 파일을
                // 구분할 수 없다. 새 세션 데이터를 파괴하지 않고 명시적으로 로컬 정리를 보류한다.
                errorText = "서버 탈퇴는 완료됐지만 같은 계정 슬롯에 새 세션이 감지되어 이 기기의 로컬 파일은 지우지 않았습니다. 새 세션에서 로그아웃한 뒤 앱을 다시 실행해주세요."
                return
            }
            await store.invalidateLearningPersistence(for: withdrawn.slot)
            // 아직 같은 세션일 때만 로그아웃한다. 이미 다른 계정으로 전환됐다면 그
            // 새 세션은 건드리지 않고, 아래에서 캡처해 둔 old owner 파일만 정리한다.
            if stillOwnsSession {
                guard await store.signOut(discardingCurrentSlot: true) else {
                    errorText = "서버 탈퇴는 완료됐지만 이 기기의 계정 전환을 마치지 못했습니다. 앱을 다시 실행하면 로그아웃 상태로 복구됩니다."
                    return
                }
            }
            await MainActor.run {
                Self.purgeWithdrawnSlot(named: withdrawn.slot, directory: withdrawn.directory)
                dismiss()
            }
        } catch {
            errorText = Self.withdrawalFailureMessage(error)
        }
    }

    private static func withdrawalFailureMessage(_ error: Error) -> String {
        if let api = error as? ServerAPIError,
           let reason = api.message?.trimmingCharacters(in: .whitespacesAndNewlines),
           !reason.isEmpty {
            return "탈퇴하지 못했습니다. \(reason)"
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "인터넷 연결이 끊겨 탈퇴를 완료하지 못했습니다. 연결을 확인한 뒤 다시 시도해 주세요."
            case .timedOut:
                return "탈퇴 요청의 응답이 늦어지고 있습니다. 잠시 후 다시 시도해 주세요."
            default: break
            }
        }
        #if DEBUG
        print("계정 탈퇴 실패:", error)
        #endif
        return "탈퇴를 완료하지 못했습니다. 입력 내용을 확인한 뒤 다시 시도해 주세요. 계속 실패하면 고객지원으로 문의해 주세요."
    }

    private func loadWithdrawalOptions() async {
        guard !loadingWithdrawalOptions else { return }
        loadingWithdrawalOptions = true
        defer { loadingWithdrawalOptions = false }
        do {
            options = try await ServerAPI.withdrawalOptions()
            withdrawalOptionsUnsupported = false
            withdrawalOptionsLoadError = nil
        } catch {
            // 기존 이메일/비밀번호 탈퇴는 options 조회와 독립적으로 유지한다.
            // 구버전 서버나 일시적인 네트워크 오류가 비밀번호 탈퇴까지 막으면 안 된다.
            // 라우트 없음(404)만 "이 서버는 소셜 재확인을 제공하지 않음" 안내로 바꾼다.
            options = nil
            let unsupported = (error as? ServerAPIError)?.statusCode == 404
            withdrawalOptionsUnsupported = unsupported
            withdrawalOptionsLoadError = unsupported ? nil
                : "본인 확인 방법을 불러오지 못했습니다. 이메일 계정은 현재 비밀번호로 계속할 수 있습니다. 소셜 계정은 다시 불러와 주세요."
        }
    }

    private func verifyWithGoogle() async {
        google.cancel()
        googleBusy = true
        errorText = nil
        defer { googleBusy = false }
        do {
            googleReauthentication = try await google
                .reauthenticateForAccountDeletion()
            appleReauthentication = nil
            kakaoReauthentication = nil
            password = ""
        } catch let error as ASWebAuthenticationSessionError
            where error.code == .canceledLogin {
            return
        } catch {
            errorText = (error as? ServerAPIError)?.errorDescription
                ?? "Google 본인 확인을 완료하지 못했습니다."
        }
    }

    private func verifyWithApple() async {
        apple.cancel()
        appleBusy = true
        errorText = nil
        defer { appleBusy = false }
        do {
            appleReauthentication = try await apple
                .reauthenticateForAccountDeletion()
            googleReauthentication = nil
            kakaoReauthentication = nil
            password = ""
        } catch let error as ASAuthorizationError where error.code == .canceled {
            return
        } catch {
            errorText = (error as? ServerAPIError)?.errorDescription
                ?? "Apple 본인 확인을 완료하지 못했습니다."
        }
    }

    private func verifyWithKakao() async {
        kakao.cancel()
        kakaoBusy = true
        errorText = nil
        defer { kakaoBusy = false }
        do {
            kakaoReauthentication = try await kakao
                .reauthenticateForAccountDeletion()
            googleReauthentication = nil
            appleReauthentication = nil
            password = ""
        } catch let error as ASWebAuthenticationSessionError
            where error.code == .canceledLogin {
            return
        } catch {
            errorText = (error as? ServerAPIError)?.errorDescription
                ?? "카카오 본인 확인을 완료하지 못했습니다."
        }
    }

    /// 탈퇴 **확정** 계정의 로컬 잔재 삭제. 서버 2xx 를 받은 뒤에만 부른다 —
    /// 실패한 탈퇴에서 지우면 살아 있는 계정의 데이터를 파괴하는 사고다.
    /// 게스트 슬롯은 계정과 무관한 이 기기 사용자의 기록이므로 절대 지우지 않는다.
    private static func purgeWithdrawnSlot(named slot: String, directory: URL) {
        guard slot != "guest" else { return }
        // 알림 캐시는 Documents 슬롯 밖(Application Support)에 있어 별도 owner 삭제가 필요하다.
        NotificationInboxDisk.clear(slot: slot)
        do {
            try FileManager.default.removeItem(at: directory)
        } catch {
            // 이미 없으면 정상. 그 외 실패는 잔재가 남았다는 뜻이라 흔적을 남긴다
            // (콘솔 로그가 이 앱의 최소 증거 채널이다).
            print("Matths 탈퇴 정리: 슬롯 파일 삭제 실패 — \(error.localizedDescription)")
        }
        // 슬롯 스코프 UserDefaults — AppStore.slotKey 규약("<키>.<슬롯>")과
        // SyncEngine pull 커서("matths.sync.lastPull.<슬롯>") 모두 같은 접미사라
        // 접미사 하나로 걸러 지운다. 전역 키(테마·모션 등)는 접미사가 없어 남는다.
        let defaults = UserDefaults.standard
        let suffix = "." + slot
        for key in defaults.dictionaryRepresentation().keys where key.hasSuffix(suffix) {
            defaults.removeObject(forKey: key)
        }
        print("Matths 탈퇴 정리: 슬롯 \(slot) 로컬 데이터 삭제 완료")
    }
}
