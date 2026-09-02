//  RootView.swift
//  Matths
//
//  앱 셸 — 상단 슬림바 + 하단 탭바.
//
//  탭은 동급 목적지 6개만 둔다(홈·커리큘럼·평가센터·오답노트·게시판·GOAT Arena).
//  도구는 탭이 아니다: AI 튜터는 상단바 sparkles 버튼, 채점 Pro 는 평가센터의
//  진입 카드로 들어간다. Route 와 화면은 그대로 두고 진입점만 옮겼다.
//
//  사이드바를 걷어낸 이유:
//   1. 목적지가 5개다. 사이드바를 쓸 만큼 깊지 않다.
//   2. Split View 1/2(13인치 가로에서 약 507pt)에서 260pt 사이드바를 빼면
//      본문에 247pt만 남는다. 필기 캔버스가 들어가는 화면에서는 못 쓴다.
//   3. 폭에 따라 사이드바/탭바로 갈리면 내비게이션이 두 벌이 된다.
//      학생이 창 크기를 바꿀 때마다 "메뉴가 어디 갔지"를 다시 배워야 한다.
//
//  그래서 어떤 폭에서도 하단 바 하나로 간다.
//  Slide Over(320pt)든 13인치 전체화면(1366pt)이든 같은 자리에 같은 메뉴가 있다.
//
//  세션 모드(문제 풀이/결과)에서는 두 바를 모두 걷어낸다.
//  푸는 동안 화면에 남는 것은 문제와 캔버스뿐이다.

import Foundation
import SwiftUI

/// 현재 앱 본문이 실제로 받은 창 크기. 화면 기종/회전 이름 대신 이 값으로
/// iPad Split View·Stage Manager·iPhone 가로를 같은 규칙에서 판정한다.
private struct MatthsBrowseViewportSizeKey: EnvironmentKey {
    static let defaultValue = CGSize.zero
}

extension EnvironmentValues {
    var matthsBrowseViewportSize: CGSize {
        get { self[MatthsBrowseViewportSizeKey.self] }
        set { self[MatthsBrowseViewportSizeKey.self] = newValue }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: AppStore

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    /// 두 바가 지금 접혀 있는지 (사파리형 자동 숨김).
    @State private var chromeHidden = false
    /// 직전 측정값. nil 이면 "다음 측정을 새 기준점으로 삼는다" — 화면 전환 직후다.
    @State private var chromeLastOffset: CGFloat?
    /// 같은 방향으로 쌓인 이동량. 방향이 바뀌면 0 부터 다시 센다(손 떨림 차단).
    @State private var chromeTravel: CGFloat = 0
    /// 소프트웨어 키보드가 떠 있을 때 커스텀 탭바까지 그대로 남기면 시스템 키보드와
    /// 합쳐 세로 공간을 두 번 차지한다. 특히 iPhone 가로에서는 문제를 읽을 높이가
    /// 거의 0이 된다. 입력 중에는 하단바를 숨기고, 세로가 짧을 때만 상단바도 접는다.
    @State private var keyboardVisible = false

    private var academyRole: String {
        #if DEBUG
        if DemoMode.isOn { return DemoMode.demoUser.role?.lowercased() ?? "student" }
        #endif
        return store.serverProfile?.role?.lowercased() ?? "student"
    }

    @ViewBuilder private var roleAcademyScreen: some View {
        switch academyRole {
        case "admin": AdminAcademyScreen()
        case "teacher": TeacherAcademyScreen()
        default: AcademyScreen()
        }
    }

    var body: some View {
        Group {
            if store.isSessionMode {
                sessionContent
            } else {
                browseContent
                    // 본문 스크롤이 올려 보내는 위치 — 두 바를 접고 펴는 유일한 입력이다.
                    // 자체 스크롤을 가진 route(채팅·커리큘럼·상점·이용권)는 이 값을 올리지
                    // 않으므로 빈 값이 흘러 들어오고, 그때 두 바는 늘 펴진 채로 남는다.
                    .onPreferenceChange(MatthsBrowseScrollStateKey.self) { state in
                        updateChrome(with: state)
                    }
                    .safeAreaInset(edge: .top, spacing: 0) {
                        if !(keyboardVisible && verticalSizeClass == .compact) { topChrome }
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if !keyboardVisible { bottomChrome }
                    }
            }
        }
        .background(store.isArenaRoute ? Tokens.brandNavy : Tokens.paper)
        // GOAT Arena는 시스템이 라이트 모드여도 독립된 다크 경기장으로 전환한다.
        // 탭을 벗어나면 nil로 되돌려 사용자의 원래 외관 설정을 즉시 복원한다.
        .preferredColorScheme(store.isArenaRoute ? .dark : nil)
        .environment(\.colorScheme, store.isArenaRoute ? .dark : systemColorScheme)
        // 페이지 전환 애니메이션 — 모션 꺼짐/동작 줄이기에서는 nil 로 즉시 전환
        .animation(store.motionOn && !reduceMotion
                   ? .spring(response: 0.35, dampingFraction: 0.9) : nil,
                   value: store.route)
        // 화면이 바뀌면 접힘을 푼다. 새 화면의 스크롤 위치와 무관하게, 도착하자마자
        // 탭바가 없는 화면을 만나면 "메뉴가 어디 갔지" 가 된다.
        .onChange(of: store.route) { _, _ in resetChrome() }
        #if DEBUG
        .onAppear {
            if DemoMode.isOn,
               ProcessInfo.processInfo.arguments.contains("-profileFixture") {
                store.route = .profile
            } else if DemoMode.isOn,
                      (ProcessInfo.processInfo.arguments.contains("-teacherClassworkFixture")
                || ProcessInfo.processInfo.arguments.contains("-teacherStaffFixture")
                || ProcessInfo.processInfo.arguments.contains("-teacherAttendanceFixture")
                || ProcessInfo.processInfo.arguments.contains("-teacherAnalyticsFixture")
                || ProcessInfo.processInfo.arguments.contains("-teacherProfileFixture")
                || ProcessInfo.processInfo.arguments.contains("-teacherForensicsFixture")
                || ProcessInfo.processInfo.arguments.contains("-teacherStudentsFixture")
                || ProcessInfo.processInfo.arguments.contains("-teacherSetupFixture")
                || ProcessInfo.processInfo.arguments.contains("-teacherClassesFixture")
                || ProcessInfo.processInfo.arguments.contains("-teacherClassesEditorFixture")
                || ProcessInfo.processInfo.arguments.contains("-teacherClassTeachersFixture")
                || ProcessInfo.processInfo.arguments.contains("-adminAcademyExplorer")
                || ProcessInfo.processInfo.arguments.contains("-adminOperations")
                || ProcessInfo.processInfo.arguments.contains("-adminUsers")
                || ProcessInfo.processInfo.arguments.contains("-adminUserActivity")
                || ProcessInfo.processInfo.arguments.contains("-adminUserAssessment")
                || ProcessInfo.processInfo.arguments.contains("-adminSanctions")
                || ProcessInfo.processInfo.arguments.contains("-adminAudit")
                || ProcessInfo.processInfo.arguments.contains("-adminFinance")
                || ProcessInfo.processInfo.arguments.contains("-adminRefunds")
                || ProcessInfo.processInfo.arguments.contains("-adminPaybacks")
                || ProcessInfo.processInfo.arguments.contains("-adminCommunity")
                || ProcessInfo.processInfo.arguments.contains("-adminWeeklyMock")
                || ProcessInfo.processInfo.arguments.contains("-adminArchive")
                || ProcessInfo.processInfo.arguments.contains("-adminStore")
                || ProcessInfo.processInfo.arguments.contains("-adminArena")
                || ProcessInfo.processInfo.arguments.contains("-adminDataAnalysis")
                || ProcessInfo.processInfo.arguments.contains("-adminPdfForensics")
                || ProcessInfo.processInfo.arguments.contains("-adminArenaPolicies")
                || ProcessInfo.processInfo.arguments.contains("-adminProblemBanks")
                || ProcessInfo.processInfo.arguments.contains("-adminCoachSuggestions")
                || ProcessInfo.processInfo.arguments.contains("-adminOperationsGuide")
                || ProcessInfo.processInfo.arguments.contains("-adminToolHub")
                || ProcessInfo.processInfo.arguments.contains("-adminAcademyFixture")) {
                store.route = .academy
            }
        }
        #endif
        .onReceive(NotificationCenter.default.publisher(for: .matthsRouteRequest)) { request in
            guard let route = request.object as? AppStore.Route else { return }
            // 게시판도 네이티브 화면이므로 알림함을 먼저 홈으로 해제할 이유가 없다.
            // 목적지로 곧바로 바꿔 화면 깜빡임과 VoiceOver 포커스 유실을 피한다.
            store.route = route
        }
        // 회전·VoiceOver 로 자동 숨김 문맥을 벗어나면 즉시 원래대로 편다.
        .onChange(of: autoHidesChrome) { _, enabled in if !enabled { resetChrome() } }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
        // 시험지 웹뷰 코디네이터가 스토어에 닿는 통로 (파일 하단 AppStoreLocator 주석 참조)
        .onAppear { AppStoreLocator.shared = store; store.wireSyncCallbacks() }
    }

    // MARK: 스크롤 연동 크롬 (사파리형 자동 숨김)
    //
    // iPhone 세로는 상단바 50 + 탭바 50 에 시스템 인셋까지 빼면 본문이 화면의 3/4 이고,
    // 가로는 가용 높이 약 390pt 중 두 바가 88pt 를 가져간다. 그렇다고 바를 더 낮출 수는
    // 없다 — 두 바 모두 44pt 최소 터치 타깃이 바닥이다(AppTopBar·MainTabBar 주석).
    // 그래서 크기를 줄이는 대신 **읽는 동안만** 접는다. 사파리와 같은 규칙이다:
    //   · 아래로 읽어 내려가면 접히고, 위로 조금만 되돌리면 즉시 나온다(탭 이동 보장).
    //   · 스크롤 맨 위에서는 언제나 보인다.
    //   · 본문 끝 근처에서도 보인다 — 거기서 접으면 뷰포트가 커지면서 스크롤이 끝으로
    //     당겨지고, 그 당김이 다시 "위로 올림" 으로 읽혀 폈다 접었다 진동한다.
    //   · 화면(route)이 바뀌면 항상 펴진 상태로 시작한다.
    //   · VoiceOver 중에는 접지 않는다 — 바가 사라지면 로터 탐색이 끊긴다.
    //
    // 세션 모드(문제 풀이/결과)는 애초에 두 바가 없어 이 규칙과 무관하다.

    private var deviceClass: MatthsDeviceClass {
        UIDevice.current.userInterfaceIdiom == .phone ? .phone : .pad
    }

    private var verticalLayoutClass: MatthsLayoutClass {
        switch verticalSizeClass {
        case .compact: .compact
        case .regular: .regular
        default: .unspecified
        }
    }

    /// 스크롤에 따라 두 바를 접을 문맥인지.
    ///
    /// 판정은 이미 있는 정책 하나를 그대로 쓴다 — "상단 크롬을 좁혀야 하는 문맥"
    /// (iPhone 전부 + 세로가 짧은 창)이 곧 "세로가 모자라 접어야 하는 문맥"이다.
    /// 여기서만 쓰는 새 판정을 만들면 iPhone 가로(폭이 regular 인 Max 기종 포함)와
    /// Stage Manager 납작창에서 두 규칙이 어긋난다.
    /// iPad 전체화면·Split View(세로 regular)는 종전 그대로 언제나 두 바를 세운다.
    private var autoHidesChrome: Bool {
        guard !voiceOverEnabled else { return false }
        return UniversalLayoutPolicy.usesCompactTopChrome(
            on: deviceClass,
            vertical: verticalLayoutClass)
    }

    /// 두 바가 깔고 앉는 면. 바 자신의 배경과 **같은 색**이어야 한다 —
    /// 루트 배경(Tokens.paper)을 쓰면 라이트 모드에서 상태바 자리만 회색으로 뜬다.
    private var chromeSurface: Color {
        store.isArenaRoute ? Tokens.brandNavy : Color(uiColor: .systemBackground)
    }

    // MARK: 안전영역을 메우는 바 배경 (상단 잘림·하단 비침의 원인)
    //
    // safeAreaInset 은 인셋 뷰를 **안전영역 안쪽**에 놓는다. 그래서 두 바의 배경은
    // 상태바/다이나믹 아일랜드(상단 62pt)와 홈 인디케이터(하단 34pt) 자리를 덮지
    // 못하고, 그 띠에는 뒤에서 스크롤 중인 본문이 그대로 비친다. 실측(iPhone 17
    // 시뮬, 3x): 하단 y=2520~2622px(=34pt)에 아레나 카드가 그대로 보였고, 상단은
    // 홈을 스크롤하면 미션 버튼이 "9:41" 과 다이나믹 아일랜드 위로 올라왔다.
    //
    // 그래서 접히는 부분(CollapsibleChrome)의 **바깥에** 같은 색 배경을 한 겹 깔고
    // 그 배경만 안전영역을 무시한다. 바깥에 두는 이유는 CollapsibleChrome 이
    // `.clipped()` 로 자기 프레임을 자르기 때문이다 — 안쪽에 넣으면 늘린 만큼 잘린다.
    // 바가 접혀 높이가 0 이 되어도 이 배경은 남아, 접힌 동안에도 본문이 상태바
    // 밑으로 흘러 들어가지 않는다.

    @ViewBuilder private var topChrome: some View {
        Group {
            if autoHidesChrome {
                AppTopBar().modifier(CollapsibleChrome(hidden: chromeHidden, anchor: .bottom))
            } else {
                AppTopBar()
            }
        }
        .background(alignment: .top) {
            // 가로 iPhone 은 노치 쪽 좌우에도 59pt 인셋이 붙는다. 세로 방향만 메우면
            // 그 두 줄만 루트 배경(paper)으로 남아 바 색과 이가 맞지 않는다.
            chromeSurface.ignoresSafeArea(edges: [.top, .horizontal])
        }
    }

    @ViewBuilder private var bottomChrome: some View {
        Group {
            if autoHidesChrome {
                MainTabBar().modifier(CollapsibleChrome(hidden: chromeHidden, anchor: .top))
            } else {
                MainTabBar()
            }
        }
        .background(alignment: .bottom) {
            // 키보드까지 무시한다 — 탭바 본체가 이미 키보드를 무시하므로(아래 MainTabBar
            // 주석) 배경만 따라 올라오면 바와 배경이 어긋난 채 두 겹으로 보인다.
            // 좌우는 상단바와 같은 이유(가로 iPhone 노치 인셋).
            chromeSurface.ignoresSafeArea(.all, edges: [.bottom, .horizontal])
        }
    }

    private func updateChrome(with state: MatthsBrowseScrollState) {
        // 위치를 알려 주지 않는 화면(자체 스크롤 route)과 접지 않는 문맥(iPad·VoiceOver)은
        // 언제나 펴 둔다.
        guard autoHidesChrome,
              let offset = state.offset,
              let bottomDistance = state.bottomDistance else {
            resetChrome()
            return
        }
        defer { chromeLastOffset = offset }

        // 맨 위·본문 끝 근처는 방향과 무관하게 무조건 펴진다.
        if offset >= -ChromeAutoHide.topSlack
            || bottomDistance <= ChromeAutoHide.bottomReveal {
            chromeTravel = 0
            setChromeHidden(false)
            return
        }

        guard let last = chromeLastOffset else { return }   // 첫 측정은 기준점만 잡는다
        let delta = offset - last
        guard delta != 0 else { return }
        // 방향이 바뀌면 누적을 버린다 — 작은 흔들림이 임계값까지 쌓이지 못한다.
        chromeTravel = chromeTravel * delta > 0 ? chromeTravel + delta : delta

        if chromeTravel <= -ChromeAutoHide.hideTravel {
            // 접고 나면 뷰포트가 두 바 높이만큼 커진다. 그만큼 스크롤이 남아 있을 때만
            // 접어야 끝으로 당겨지지 않는다(bottomReveal 과 값이 다른 이유 = 히스테리시스).
            if bottomDistance >= ChromeAutoHide.bottomHideRoom {
                setChromeHidden(true)
            }
        } else if chromeTravel >= ChromeAutoHide.revealTravel {
            setChromeHidden(false)
        }
    }

    private func resetChrome() {
        chromeLastOffset = nil
        chromeTravel = 0
        setChromeHidden(false)
    }

    private func setChromeHidden(_ hidden: Bool) {
        guard chromeHidden != hidden else { return }
        // 동작 줄이기 / 앱 모션 꺼짐에서는 애니메이션 없이 즉시 전환한다
        // (route 전환 애니메이션과 같은 판정 축).
        if store.motionOn && !reduceMotion {
            withAnimation(ChromeAutoHide.animation) { chromeHidden = hidden }
        } else {
            chromeHidden = hidden
        }
    }

    @ViewBuilder private var browseContent: some View {
        if store.route == .chat {
            // 채팅은 자체 스크롤 + 하단 입력바 — 바깥 ScrollView 에 넣으면
            // 키보드/스크롤이 이중이 된다
            ChatScreen()
                .routeTransition(store.route)
        } else if store.route == .curriculum {
            // 학습 맵도 자체 세로 스크롤(경로 앵커링)을 가진다 — 채팅과 같은 특례
            CurriculumV2MapScreen()
                .routeTransition(store.route)
        } else if store.route == .arenaShop {
            // Ranked 상점은 자체 스크롤과 확인 다이얼로그를 가진다. 바깥 ScrollView에 넣으면
            // 새로고침과 큰 글씨에서 스크롤이 이중으로 잡힌다.
            ArenaShopScreen()
                .routeTransition(store.route)
        } else if store.route == .commerce {
            // 이용권 허브도 결제 브라우저·새로고침을 소유한다.
            CommerceHubScreen()
                .routeTransition(store.route)
        } else if store.route == .community {
            // 네이티브 게시판은 목록·검색·상세 시트가 각자 스크롤과 새로고침을
            // 소유한다. 바깥 문서 스크롤에 다시 넣지 않아 가로모드의 압축 헤더와
            // 인기 글/최신 글 목록이 하나의 뷰포트 높이를 정확히 나눠 갖게 한다.
            NativeCommunityScreen()
                .routeTransition(store.route)
        } else if store.route == .academy {
            // 학생 교실·교사 작업대·운영 승인함 모두 가로 2열과 내부 목록을 직접 소유한다.
            roleAcademyScreen
                .routeTransition(store.route)
        } else if store.route == .coachSuggestions {
            // 입력창과 상태 목록이 각각 자기 스크롤을 소유한다. iPhone 가로에서는
            // 좌우를 동시에 보여 주므로 바깥 문서 ScrollView에 다시 넣지 않는다.
            CoachSuggestionsScreen()
                .routeTransition(store.route)
        } else if store.route == .support {
            // 문의 작성과 처리 내역도 가로에서 좌우로 나뉘며 각각 스크롤을 소유한다.
            SupportInquiryScreen()
                .routeTransition(store.route)
        } else if store.route == .archive {
            // 폴더와 파일 목록은 가로 좌우 패널의 내부 스크롤을 직접 소유한다.
            ArchiveLibraryScreen()
                .routeTransition(store.route)
        } else if store.route == .studyHall {
            // 콘텐츠 목록과 답안지는 가로 분할·세로 단일 탐색을 자체 소유한다.
            StudyHallScreen()
                .routeTransition(store.route)
        } else if store.route == .storeCatalog {
            // 무료 자료 카탈로그와 상세 이미지·다운로드가 각자 내부 스크롤을 소유한다.
            StoreCatalogScreen()
                .routeTransition(store.route)
        } else if store.route == .faq {
            // 검색 결과와 답변은 가로에서 좌우 패널의 독립 스크롤을 소유한다.
            FaqScreen()
                .routeTransition(store.route)
        } else if store.route == .hostedPortal {
            // 학원·관리자 등 서버 세션 화면은 WKWebView가 자체 스크롤과 파일
            // 미리보기를 소유한다. 바깥 ScrollView에 넣으면 높이가 0으로 접힌다.
            HostedServicePortalScreen(destination: store.hostedPortalDestination)
                .routeTransition(store.route)
        } else {
            browseScroll
        }
    }

    @ViewBuilder private var browseScroll: some View {
        GeometryReader { viewport in
            ScrollView {
                Group {
                    switch store.route {
                    case .home:       HomeScreen()
                    case .curriculum: CurriculumV2MapScreen()   // 특례 분기가 먼저 잡는다 — 방어용
                    case .concept:    ConceptScreenV2()
                    case .assess:     AssessmentScreen()
                    case .wrongNotes: WrongNotesScreen()
                    case .rank:
                        // 비로그인은 죽은 게이트 대신 순위표 미리보기(RankArenaScreen) —
                        // 로그인하면 기존 GOAT Arena 풀 화면 그대로
                        if store.authProvider == "server" { GoatArenaScreen() }
                        else { RankArenaScreen() }
                    case .community:  NativeCommunityScreen()
                    case .arenaShop: ArenaShopScreen() // 특례 분기가 먼저 잡는다 — 방어용
                    case .commerce:  CommerceHubScreen() // 특례 분기가 먼저 잡는다 — 방어용
                    case .pro:        ProScreen()
                    case .chat:       ChatScreen()
                    case .quickPractice: QuickPracticeScreen()
                    case .profile:    ProfileScreen()
                    case .notifications: NotificationInboxScreen()
                    case .services:    ServiceHubScreen()
                    case .academy:
                        roleAcademyScreen
                    case .coachSuggestions:
                        CoachSuggestionsScreen()
                    case .support:
                        SupportInquiryScreen()
                    case .archive:
                        ArchiveLibraryScreen()
                    case .studyHall:
                        StudyHallScreen()
                    case .storeCatalog:
                        StoreCatalogScreen()
                    case .faq:
                        FaqScreen()
                    case .hostedPortal:
                        HostedServicePortalScreen(destination: store.hostedPortalDestination)
                    default:          HomeScreen()
                    }
                }
                .routeTransition(store.route)
                .frame(maxWidth: .infinity, alignment: .leading)
                // 개념 수업은 1080px 모션판과 설명판을 함께 쓰는 시각 작업대다.
                // 일반 문서의 900pt 행 길이 제한을 그대로 걸면 iPad 가로에서 좌우가
                // 비고 수학판만 다시 작아진다. 개념 route만 1280pt까지 열고, 실제
                // 문장 폭은 각 카드/자막이 스스로 제한한다.
                .readableWidth(store.route == .concept ? 1280 : Tokens.readableWidth)
                .adaptiveHPadding()
                .adaptiveVPadding()
                .environment(\.matthsBrowseViewportSize, viewport.size)
                // 사파리형 자동 숨김의 유일한 입력. 배포 타깃이 iOS 17 이라
                // onScrollGeometryChange(18+)를 쓸 수 없어 preference 로 올린다.
                //
                // 두 값 모두 **ScrollView 자기 좌표계** 하나로만 잰다: 좌표계 원점과
                // 뷰포트 높이가 같은 프레임에서 나오므로, 바가 접혀 안전영역이 바뀌어도
                // 둘의 관계는 그대로다. 안전영역 값을 섞으면 접는 순간 그 변화량이
                // 스크롤로 오독돼 스스로 다시 펴는 되먹임이 생긴다.
                .background {
                    GeometryReader { content in
                        let frame = content.frame(in: .named(Self.browseScrollSpace))
                        Color.clear.preference(
                            key: MatthsBrowseScrollStateKey.self,
                            value: MatthsBrowseScrollState(
                                offset: frame.minY,
                                bottomDistance: frame.maxY - viewport.size.height))
                    }
                    .accessibilityHidden(true)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .coordinateSpace(.named(Self.browseScrollSpace))
        }
    }

    /// 본문 스크롤 좌표계 이름 — 위치를 재는 쪽과 기준을 세우는 쪽이 같은 문자열을 쓴다.
    private static let browseScrollSpace = "matths.browseScroll"

    @ViewBuilder private var sessionContent: some View {
        Group {
            switch store.route {
            case .solve:  SolveScreen()
            case .result: ResultScreen()
            case .kice:
                KiceExamScreen()
                    .protectedAssessmentSurface("kice-exam")
            case .paper:
                AssessmentPaperScreen()
                    .protectedAssessmentSurface("assessment-paper")
            case .placement:
                PlacementExamScreen()
                    .protectedAssessmentSurface("placement-exam")
            case .weeklyMock:
                WeeklyMockScreen()
                    .protectedAssessmentSurface("weekly-mock")
            default:      EmptyView()
            }
        }
        .routeTransition(store.route)
    }
}

// MARK: - 접히는 크롬의 부품
//
// 규칙과 판정은 RootView 안에 있다(위 "스크롤 연동 크롬" 주석). 여기 있는 것은
// 그 규칙이 쓰는 숫자·전달 통로·표시 방법 셋뿐이다.

private enum ChromeAutoHide {
    /// 이만큼 아래로 읽어 내려가야 접힌다. 목록을 훑을 때의 손 떨림(2~3pt)으로는 못 넘는다.
    static let hideTravel: CGFloat = 14
    /// 되돌아 올라올 때는 절반 이하면 나온다 — "위로 조금만 올려도 바로" 가 탭 이동의 출구다.
    static let revealTravel: CGFloat = 6
    /// 스크롤 맨 위 판정 여유. ScrollView 는 안전영역만큼 콘텐츠를 밀어 두므로 쉬는 자리의
    /// 값은 0 이상이다 — 즉 이 판정은 "맨 위 + 상단 인셋만큼" 을 넉넉히 덮는다.
    static let topSlack: CGFloat = 8
    /// 본문 끝이 이보다 가까우면 무조건 편다.
    static let bottomReveal: CGFloat = 90
    /// 접으려면 본문 끝까지 이만큼은 남아 있어야 한다. 두 바를 접으면 뷰포트가 최대
    /// 100pt 커지는데, 남은 스크롤이 그보다 짧으면 접는 순간 끝으로 당겨지고
    /// 그 당김이 다시 "위로 올림" 으로 읽혀 진동한다. bottomReveal 과 값을 벌려
    /// 히스테리시스를 만든다 — 접기 200, 펴기 90.
    static let bottomHideRoom: CGFloat = 200
    /// 사파리와 같은 짧은 감속. 길면 스크롤을 따라오지 못하고 뒤늦게 움직인다.
    static let animation: Animation = .easeOut(duration: 0.22)
}

/// 본문 스크롤의 현재 위치 — browseScroll 이 올리고 RootView 가 읽는 유일한 신호.
/// 둘 다 nil 인 값은 "이 화면은 위치를 알려 주지 않는다" 는 뜻이다(자체 스크롤을 가진
/// 채팅·커리큘럼·상점·이용권 route). 그때 두 바는 언제나 펴진 채로 남는다.
private struct MatthsBrowseScrollState: Equatable {
    /// 스크롤 좌표계에서 본문 상단의 y. 아래로 읽어 내려가면 작아진다.
    var offset: CGFloat?
    /// 본문 하단이 뷰포트 하단보다 얼마나 더 남았는가. 0 이면 끝까지 온 것이다.
    var bottomDistance: CGFloat?
}

private struct MatthsBrowseScrollStateKey: PreferenceKey {
    static var defaultValue = MatthsBrowseScrollState()

    /// 값을 통째로 덮어쓰지 않고 **채워 넣는다**. 이 키를 세우는 뷰는 본문 안에 하나뿐이지만
    /// 형제 노드들도 저마다 기본값을 들고 올라오기 때문에, `value = nextValue()` 로 쓰면
    /// 실제 측정값이 뒤따라온 기본값에 지워진다(실측: 콜백이 늘 빈 값이었다).
    static func reduce(value: inout MatthsBrowseScrollState,
                       nextValue: () -> MatthsBrowseScrollState) {
        let next = nextValue()
        if let offset = next.offset { value.offset = offset }
        if let bottomDistance = next.bottomDistance { value.bottomDistance = bottomDistance }
    }
}

private struct ChromeHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// 접히는 크롬 한 장.
///
/// safeAreaInset 은 이 뷰의 **레이아웃 높이**만큼 본문 뷰포트를 줄인다. 그래서 offset
/// 으로 밀면 바만 화면 밖으로 나가고 본문은 그대로라 되찾는 공간이 0 이다. 높이를 0 으로
/// 접고 콘텐츠를 바깥쪽 가장자리(상단바는 아래, 탭바는 위)에 붙여 두면, 바가 화면 밖으로
/// 미끄러져 나가는 모양 그대로 본문이 그 자리를 받는다. clipped 가 잘린 부분과 히트
/// 영역을 함께 지우므로 접힌 바는 눌리지 않는다.
///
/// 높이를 nil↔0 으로 바꾸지 않고 실측값을 재서 CGFloat↔0 으로 바꾸는 이유는 애니메이션이다 —
/// nil 은 보간할 값이 없다. 측정 전(첫 프레임)만 nil 로 자연 높이를 쓴다.
private struct CollapsibleChrome: ViewModifier {
    let hidden: Bool
    /// 접힐 때 콘텐츠가 붙어 있을 가장자리.
    let anchor: Alignment

    @State private var naturalHeight: CGFloat?

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: ChromeHeightKey.self, value: proxy.size.height)
                }
                .accessibilityHidden(true)
            }
            .onPreferenceChange(ChromeHeightKey.self) { height in
                // 접힌 동안에도 바 자신의 최소 높이(minHeight)는 살아 있어 같은 값이 온다.
                // 0 만 걸러 내면 접었다 펼 때 되돌아갈 높이를 잃지 않는다.
                guard height > 0, height != naturalHeight else { return }
                naturalHeight = height
            }
            .frame(height: hidden ? 0 : naturalHeight, alignment: anchor)
            .clipped()
    }
}

// MARK: - 폭과 높이 적응
//
// iPad 는 320pt(Slide Over)부터 1366pt(13인치 가로)까지 온다.
// 가로 iPhone 은 여기에 "가용 높이 약 390pt" 라는 축을 하나 더 얹는다.
// 양 끝을 모두 견디게 하는 규칙을 한 곳에 모아둔다.

private struct ReadableWidth: ViewModifier {
    /// 한 줄이 이보다 길어지면 눈이 다음 줄 첫 글자를 못 찾는다.
    var limit: CGFloat = Tokens.readableWidth

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: limit, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct AdaptiveHPadding: ViewModifier {
    @Environment(\.horizontalSizeClass) private var hSize

    func body(content: Content) -> some View {
        // 좁을 때 32pt 를 그대로 두면 본문이 설 자리가 없다.
        content.padding(.horizontal, hSize == .compact ? Tokens.Space.s4 : Tokens.Space.s8)
    }
}

/// 본문 스크롤의 상하 여백. 세로가 짧으면(가로 iPhone) 숨통을 줄인다.
///
/// 판정은 verticalSizeClass 다. 기기 이름으로 가르면 Stage Manager 로 납작해진
/// iPad 를 놓치고, 세로로 되돌린 iPhone 까지 계속 좁은 값에 묶인다.
///
/// 왜 바 높이보다 여기가 먼저인가. 가로 iPhone 의 가용 높이는 약 390pt 이고
/// 그중 상단바 44 + 탭바 46 + 홈 인디케이터 21 을 빼면 본문 뷰포트가 약 279pt 다.
/// 그 안에서 종전 값(상하 32 에 하단 76 을 더해 상 32 / 하 108)은 140pt,
/// 즉 뷰포트의 절반을 글자 없는 여백으로 썼다. 바에서 깎을 수 있는 몇 pt 보다
/// 여기서 되찾는 양이 훨씬 크고, 터치 타깃을 하나도 건드리지 않는다.
///
/// 세로가 짧지 않아도 **폭이 좁으면**(iPhone 세로) 한 단계 줄인다. 종전 값 상 32 /
/// 하 108(32+76)은 iPad 기준이라, 874pt 짜리 iPhone 세로 화면에서 140pt —
/// 뷰포트의 5분의 1 — 을 글자 없는 여백으로 썼다. 상 20 / 하 60 이면 마지막 섹션과
/// 탭바 사이 숨통(60pt)은 그대로 남는다. 이 값 뒤에 탭바 높이는 safeAreaInset 이
/// 따로 잡아 두므로 여기서 두 번 셀 필요가 없다.
///
/// regular 폭·regular 높이(모든 iPad)의 값은 종전 그대로다.
private struct AdaptiveVPadding: ViewModifier {
    @Environment(\.verticalSizeClass) private var vSize
    @Environment(\.horizontalSizeClass) private var hSize

    func body(content: Content) -> some View {
        let short = vSize == .compact
        let narrow = hSize == .compact
        content
            .padding(.vertical, short ? Tokens.Space.s3
                     : (narrow ? Tokens.Space.s5 : Tokens.Space.s8))
            // safeAreaInset이 스크롤 뷰포트는 줄여도 마지막 섹션 자체의 여백은
            // 만들지 않는다. 320pt Split View에서 제목이 탭바 바로 뒤에 멈추지 않게 한다.
            .padding(.bottom, short ? Tokens.Space.s6
                     : (narrow ? Tokens.Space.s10 : 76))
    }
}

extension View {
    func readableWidth(_ limit: CGFloat = Tokens.readableWidth) -> some View {
        modifier(ReadableWidth(limit: limit))
    }

    /// 좌우 여백. 본문과 상단바가 **같은 순서로** 이걸 쓰기 때문에
    /// 브랜드 로고와 본문 첫 글자의 왼쪽 끝이 정확히 맞는다.
    /// 순서를 바꾸면(패딩을 폭 제한 안쪽에 넣으면) 그만큼 어긋난다.
    func adaptiveHPadding() -> some View {
        modifier(AdaptiveHPadding())
    }

    /// 상하 여백. 가로 iPhone 처럼 세로가 짧은 문맥에서만 줄어든다.
    func adaptiveVPadding() -> some View {
        modifier(AdaptiveVPadding())
    }
}

// MARK: - 상단 슬림바

struct AppTopBar: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// 종 배지의 유일한 근거. 화면(알림함)과 같은 저장소를 구독해야 목록을 읽자마자
    /// 배지가 같이 줄어든다 — 각자 세면 둘이 다른 수를 말한다.
    @ObservedObject private var notificationInbox = NotificationInboxStore.shared

    /// 오늘 학습했는지 — 홈 스트릭 칩과 같은 판정 축(학습일 기록).
    /// 스트릭은 보상 지표라 경고색(warning)을 쓰지 않는다 (0408 — 보상/경고 팔레트 분리).
    private var studiedToday: Bool {
        store.activityDays.contains(ActivityLog.dayString())
    }

    private var isArena: Bool {
        store.isArenaRoute
    }

    private var deviceClass: MatthsDeviceClass {
        UIDevice.current.userInterfaceIdiom == .phone ? .phone : .pad
    }

    private var verticalLayoutClass: MatthsLayoutClass {
        switch verticalSizeClass {
        case .compact: .compact
        case .regular: .regular
        default: .unspecified
        }
    }

    private var compactChrome: Bool {
        UniversalLayoutPolicy.usesCompactTopChrome(
            on: deviceClass,
            vertical: verticalLayoutClass)
    }

    var body: some View {
        HStack(spacing: Tokens.Space.s3) {
            // 밝은 셸의 브랜드 식별은 심볼+텍스트 재조합이 아니라 CI 원본
            // Primary Identity를 그대로 쓴다. Arena 네이비는 icon-only 문맥으로
            // 공식 심볼 타일을 유지한다.
            if isArena || compactChrome {
                BrandMark(tile: true)
                    .frame(width: 28, height: 28)
                    .accessibilityLabel("Matths")
            } else {
                PrimaryBrandIdentity()
                    .frame(width: 120, height: 37)
                    .accessibilityLabel("Matths")
            }

            Spacer(minLength: Tokens.Space.s2)

            // 연속 학습일. 끊기는 게 아까워서 다시 열게 만드는 숫자이므로
            // 학습 화면 어디서나 보이는 상단 상태로 유지한다.
            // 알약 배경 없이 불꽃과 세리프 숫자만 둔다.
            // 색은 홈 스트릭 칩과 같은 문법 — 오늘 학습했으면 rewardGold, 아니면 중립.
            HStack(spacing: 4) {
                Image(systemName: studiedToday ? "flame.fill" : "flame")
                    .font(dynamicTypeSize.isAccessibilitySize
                          ? .system(size: 18, weight: .semibold)
                          : .mCaption)
                Text("\(store.streakDays)")
                    .font(dynamicTypeSize.isAccessibilitySize
                          ? .system(size: 20, weight: .bold, design: .rounded)
                          : .mStat)
            }
            .foregroundStyle(studiedToday
                ? Tokens.rewardGold
                : (isArena ? Tokens.onNavy.opacity(0.58) : Tokens.text3))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(studiedToday
                ? "\(store.streakDays)일 연속 학습, 오늘 학습 완료"
                : "\(store.streakDays)일 연속 학습, 오늘은 아직 학습 전")

            // AI 튜터 — 탭바에서 옮겨 온 진입점 (탭은 동급 목적지 5개만 남긴다).
            // 화면(ChatScreen)과 라우트는 그대로, 문은 여기 하나다.
            Button { store.route = .chat } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(store.route == .chat
                        ? Tokens.primary
                        : (isArena ? Tokens.onNavy.opacity(0.74) : Tokens.text2))
                    .frame(width: 44, height: 44)   // 최소 터치 타겟
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("AI 튜터")

            // 알림함 — 경고·공지·답글 알림이 여기로 온다.
            //
            // 왜 탭이 아니라 상단인가: 하단 탭 6칸이 이미 꽉 찼고(아이폰에서 이미
            // 빠듯하다), 알림은 "다녀오는 곳" 이지 머무는 곳이 아니다. 튜터·프로필과
            // 같은 줄에 두면 학생이 화면 어디에 있든 같은 자리에서 찾는다.
            //
            // 배지는 **안 읽은 수**를 그대로 말한다. 점 하나로 줄이면 경고 1건과
            // 공지 20건이 같아 보인다.
            Button { store.route = .notifications } label: {
                Image(systemName: notificationInbox.unreadCount > 0 ? "bell.badge.fill" : "bell")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(store.route == .notifications
                        ? Tokens.primary
                        : (isArena ? Tokens.onNavy.opacity(0.74) : Tokens.text2))
                    .frame(width: 44, height: 44)   // 최소 터치 타겟
                    .overlay(alignment: .topTrailing) {
                        if let badge = notificationInbox.badgeText {
                            Text(badge)
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(Tokens.onBrand)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(
                                    notificationInbox.urgentUnreadCount > 0
                                        ? Tokens.danger : Tokens.actionPrimary,
                                    in: Capsule())
                                .offset(x: -2, y: 4)
                        }
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(notificationInbox.unreadCount > 0
                ? "알림함, 안 읽음 \(notificationInbox.unreadCount)건"
                : "알림함")

            // 프로필 — 탭을 늘리는 대신 아바타 버튼으로
            Button { store.route = .profile } label: {
                ZStack {
                    Circle().fill(isArena ? Tokens.arenaAccent : Tokens.actionPrimary)
                    if let profileAvatarURL {
                        AsyncImage(url: profileAvatarURL) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                profileAvatarFallback
                            }
                        }
                    } else {
                        profileAvatarFallback
                    }
                }
                .frame(width: 30, height: 30)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(
                    store.route == .profile ? Tokens.primary : .clear, lineWidth: 2))
                // 시각은 30pt 아바타 그대로, 히트 영역만 44×44 로 확장 (1261·1240)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("프로필")
        }
        // 본문과 같은 폭·같은 여백으로 묶는다. 순서까지 본문과 같아야 왼쪽 끝이 맞는다.
        .readableWidth()
        .adaptiveHPadding()
        // compact 높이(가로 iPhone)에서 이 바는 44pt 다. 40pt 로 더 내리지 않는다:
        // 이 줄에 있는 튜터/프로필 버튼이 44x44 히트 영역을 갖고 있어서,
        // 바를 40 으로 묶으면 그 두 개가 같이 눌린다. 시각 크기는 이미 최소치고
        // (마크 28, 아바타 30) 더 줄일 여지도 없다. 짧은 높이에서 되찾을 공간은
        // 바가 아니라 본문 여백에 있다(AdaptiveVPadding 참조).
        .frame(minHeight: UniversalLayoutPolicy.topBarMinimumHeight(
            on: deviceClass,
            vertical: verticalLayoutClass,
            accessibilityText: dynamicTypeSize.isAccessibilitySize))
        // 접근성 글씨의 숨통 4pt. compact 높이에서는 붙이지 않는다.
        // 그쪽 minHeight 는 이미 68pt 라 글자가 눌리지 않고, 390pt 화면에서
        // 8pt 를 더 얹으면 상단바가 화면의 5분의 1에 닿는다. 글자 크기는 그대로다.
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize && verticalLayoutClass != .compact
                 ? Tokens.Space.s1 : 0)
        .background(isArena ? Tokens.brandNavy : Color(uiColor: .systemBackground))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(isArena ? Tokens.brandCyan.opacity(0.42) : Tokens.line)
                .frame(height: isArena ? 1 : 0.5)
        }
    }

    private var profileAvatarURL: URL? {
        guard let source = store.serverProfile?.profileAvatar?.imageSrc else { return nil }
        return URL(string: source, relativeTo: ServerAPI.baseURL)?.absoluteURL
    }

    private var profileAvatarFallback: some View {
        Text(String(store.userName.prefix(1)))
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(Tokens.onBrand)
    }
}

// MARK: - 서버 동기화 튜토리얼

private struct NativeTutorialStep: Identifiable {
    /// 웹의 CSS selector를 iPad 화면에 그대로 복사할 수는 없다.
    /// 대신 앱의 정보 구조(상·중·하 작업 영역, 실제 탭, 프로필)를
    /// 안정적인 의미 타겟으로 삼는다. 회전·Split View에서도 다시 계산된다.
    enum Spotlight {
        case header
        case contentTop
        case contentMiddle
        case contentBottom
        case tab(AppStore.Route)
        case topAction(AppStore.Route)
        case profile
    }
    let id: String
    let section: String
    let route: AppStore.Route
    let title: String
    let message: String
    let spotlight: Spotlight
}

private enum NativeTutorialRun {
    case dashboard
    case arena(String)

    var chapter: String? {
        if case .arena(let chapter) = self { return chapter }
        return nil
    }
}

private struct TutorialDimShape: Shape {
    let spotlight: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addRoundedRect(
            in: spotlight,
            cornerSize: CGSize(width: 18, height: 18))
        return path
    }
}

/// 웹과 같은 계정 상태를 쓰는 네이티브 튜토리얼.
/// 다음 버튼 전에는 자동 진행하지 않고, 라우트 변경 뒤 layout이 안정된 다음 spotlight를 연다.
struct NativeTutorialOverlay: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var run: NativeTutorialRun?
    @State private var stepIndex = 0
    @State private var spotlightVisible = false
    @State private var mutationInFlight = false
    @State private var mutationError: String?
    @State private var coachFrame = 1
    #if DEBUG
    @State private var consumedDebugFixture = false
    #endif

    private var triggerKey: String {
        let profile = store.serverProfile
        let dashboard = profile?.dashboardTutorial?.status ?? ""
        let arena = profile?.arenaTutorial
        let chapterStates = arena?.chapters
            .map { "\($0.key):\($0.value.status)" }
            .sorted().joined(separator: "|") ?? ""
        return [store.authProvider ?? "", String(describing: store.route), dashboard,
                String(store.requestedDashboardTutorial),
                store.requestedArenaTutorialChapter ?? "", chapterStates].joined(separator: "#")
    }

    private var steps: [NativeTutorialStep] {
        guard let run else { return [] }
        switch run {
        case .dashboard:
            return Self.dashboardSteps
        case .arena(let chapter):
            return Self.arenaSteps[chapter] ?? Self.arenaSteps["common"] ?? []
        }
    }

    /// 최신 웹 `onboarding-tutorial.js`의 42개 selector 단계를 앱의 실제 IA에
    /// 맞게 합친 31단계. 앱에 없는 웹 전용 페이지를 가짜로 설명하지 않고,
    /// 학습 홈→커리큘럼→퀵 연습→평가→오답→게시판→Arena와
    /// 상단 AI 튜터·시험지 채점 PRO·프로필의 실제 진입점을 빠짐없이 따른다.
    private static let dashboardSteps: [NativeTutorialStep] = [
        .init(id: "home-welcome", section: "학습 홈", route: .home,
              title: "학습 홈에서 오늘 상태를 확인합니다.",
              message: "연속 학습일, 새 알림과 오늘 이어 할 공부가 첫 화면에 모입니다.", spotlight: .header),
        .init(id: "home-coach", section: "학습 홈", route: .home,
              title: "오늘의 코치가 시작을 돕습니다.",
              message: "프로필의 순한맛·매운맛 설정에 맞춰 다음 행동을 짧게 알려줍니다.", spotlight: .contentTop),
        .init(id: "home-plan", section: "학습 홈", route: .home,
              title: "이용 중인 학습권과 오늘 할 일을 보세요.",
              message: "남은 학습일수와 이용 기간, 지금 시작할 수 있는 학습이 함께 표시됩니다.", spotlight: .contentMiddle),
        .init(id: "home-record", section: "학습 홈", route: .home,
              title: "학습 기록은 자동으로 쌓입니다.",
              message: "최근 활동, 풀이 수와 정답률을 보고 공부 흐름이 끊긴 지점을 찾습니다.", spotlight: .contentBottom),
        .init(id: "to-curriculum", section: "내 학습", route: .home,
              title: "이제 커리큘럼으로 이동합니다.",
              message: "과목과 개념을 직접 골라 공부하는 곳입니다.", spotlight: .tab(.curriculum)),
        .init(id: "curriculum-overview", section: "내 학습", route: .curriculum,
              title: "교육과정 전체와 내 완성도를 확인합니다.",
              message: "2022 개정 교육과정의 과목, 완료 개념과 남은 개념을 한 눈에 봅니다.", spotlight: .contentTop),
        .init(id: "curriculum-course", section: "내 학습", route: .curriculum,
              title: "과목과 대단원을 선택합니다.",
              message: "왼쪽에서 과목을 고르고, 대단원을 펼쳐 성취기준과 학습 주제를 확인합니다.", spotlight: .contentMiddle),
        .init(id: "curriculum-concept", section: "내 학습", route: .curriculum,
              title: "개념 카드에서 학습을 시작합니다.",
              message: "이어 보기와 새로 시작하기 모두 여기서 열리고, 완료 기록은 진도에 반영됩니다.", spotlight: .contentBottom),
        .init(id: "to-quick", section: "40초 눈풀이", route: .curriculum,
              title: "다음은 40초 퀵 연습입니다.",
              message: "기본 유형을 짧게 반복해 계산 속도와 정확도를 훈련합니다.", spotlight: .contentBottom),
        .init(id: "quick-overview", section: "40초 눈풀이", route: .quickPractice,
              title: "먼저 반복 기록을 확인합니다.",
              message: "누적 풀이 수, 정답률과 평균 풀이 시간을 보고 지난 기록과 비교합니다.", spotlight: .contentTop),
        .init(id: "quick-controls", section: "40초 눈풀이", route: .quickPractice,
              title: "배점과 세트 크기를 고르고 시작합니다.",
              message: "문제가 열리면 40초 타이머가 흐릅니다. 답을 낸 뒤 풀이와 코치 피드백을 확인합니다.", spotlight: .contentMiddle),
        .init(id: "quick-note", section: "40초 눈풀이", route: .quickPractice,
              title: "문제와 풀이 메모를 함께 쓸 수 있습니다.",
              message: "지원되는 기기에서는 Apple Pencil로, iPhone에서는 손가락으로 메모를 남길 수 있습니다.", spotlight: .contentBottom),
        .init(id: "to-assessment", section: "평가센터", route: .quickPractice,
              title: "이제 평가 구조를 확인합니다.",
              message: "배운 범위안에서만 평가가 열리고, 통과 기준을 넘어야 완료됩니다.", spotlight: .tab(.assess)),
        .init(id: "assessment-overview", section: "평가센터", route: .assess,
              title: "평가는 배운 범위 안에서만 열립니다.",
              message: "아직 조건을 충족하지 못한 평가는 필요한 학습 조건과 함께 잠겨 있습니다.", spotlight: .contentTop),
        .init(id: "assessment-rules", section: "평가센터", route: .assess,
              title: "통과 기준을 충족해야 최종 완료됩니다.",
              message: "소단원·대단원·과목 평가가 순서대로 열리며, 미통과 평가는 새 회차로 다시 응시합니다.", spotlight: .contentMiddle),
        .init(id: "assessment-weekly", section: "평가센터", route: .assess,
              title: "주간 공식 모의고사도 여기서 입장합니다.",
              message: "운영 일정과 응시 가능 여부를 확인한 뒤 시험장으로 들어갑니다.", spotlight: .contentBottom),
        .init(id: "to-wrong", section: "오답 복습", route: .assess,
              title: "틀린 문제는 오답노트에서 다시 봅니다.",
              message: "학습과 평가에서 생긴 오답이 자동으로 모여 복습 순서를 만듭니다.", spotlight: .tab(.wrongNotes)),
        .init(id: "wrong-overview", section: "오답 복습", route: .wrongNotes,
              title: "오답과 오늘 복습량을 확인합니다.",
              message: "오늘 풀어야 할 문제, 대기 중인 문제와 완료한 문제가 나뉘어 표시됩니다.", spotlight: .contentTop),
        .init(id: "wrong-filter", section: "오답 복습", route: .wrongNotes,
              title: "과목·이유·검색어로 필요한 오답만 찾습니다.",
              message: "복습 상태와 틀린 이유를 바꿔 보면 지금 우선해야 할 문제가 남습니다.", spotlight: .contentMiddle),
        .init(id: "wrong-results", section: "오답 복습", route: .wrongNotes,
              title: "문제별 기록과 복습 버튼을 확인합니다.",
              message: "출처, 난이도, 이전 답안과 필기 기록을 보고 같은 문제를 다시 풀어 복습합니다.", spotlight: .contentBottom),
        .init(id: "to-community", section: "게시판", route: .wrongNotes,
              title: "질문과 학습 이야기는 게시판에서 나눕니다.",
              message: "다른 학생의 글을 읽거나 내 질문을 남길 수 있는 공간으로 이동합니다.", spotlight: .tab(.community)),
        .init(id: "community-read", section: "게시판", route: .community,
              title: "앱 안에서 글을 읽고 탐색합니다.",
              message: "게시판·정렬·검색을 바꾸고 아래로 당겨 새로고침합니다. 로그인 전에도 공개 글을 볼 수 있습니다.", spotlight: .contentTop),
        .init(id: "community-write", section: "게시판", route: .community,
              title: "로그인하면 바로 글을 작성합니다.",
              message: "상단의 글쓰기에서 질문이나 학습 경험과 첨부파일을 남기고, 알림에서 답글 소식을 확인합니다.", spotlight: .contentMiddle),
        .init(id: "to-arena", section: "GOAT Arena", route: .community,
              title: "다음은 GOAT Arena입니다.",
              message: "배치고사, 1대1 경기, 공식 모의고사와 랭킹을 서버 기준으로 확인합니다.", spotlight: .tab(.rank)),
        .init(id: "arena-status", section: "GOAT Arena", route: .rank,
              title: "내 현재 Arena 상태를 확인합니다.",
              message: "티어, 티어 안 순위, GP와 현재 활동 중인 전장이 표시됩니다.", spotlight: .contentTop),
        .init(id: "arena-actions", section: "GOAT Arena", route: .rank,
              title: "시작할 경기와 이어 할 경기를 고릅니다.",
              message: "역할·예치·마감을 확인한 뒤 배치고사나 1대1 경기로 들어갑니다.", spotlight: .contentMiddle),
        .init(id: "arena-record", section: "GOAT Arena", route: .rank,
              title: "정산이 끝난 경기는 기록으로 남습니다.",
              message: "승패와 자리·GP 변동은 서버가 확정한 결과만 표시합니다.", spotlight: .contentBottom),
        .init(id: "ai-tutor", section: "AI 튜터", route: .rank,
              title: "막힌 문제는 상단 AI 튜터에서 이어갑니다.",
              message: "별 모양 버튼을 누르면 풀이 맥락을 정리해 질문하고, 온디바이스 모델 상태도 확인할 수 있습니다.", spotlight: .topAction(.chat)),
        .init(id: "pro-entry", section: "시험지 채점 PRO", route: .assess,
              title: "종이 시험지는 평가센터에서 채점합니다.",
              message: "시험지 채점 PRO 진입 카드에서 촬영한 시험지를 불러와 문항별 결과를 만듭니다.", spotlight: .contentBottom),
        .init(id: "pro-report", section: "시험지 채점 PRO", route: .pro,
              title: "문항별 답과 교정 결과를 한곳에서 봅니다.",
              message: "페이지·문항별 정오답과 자기 교정 상태를 펼쳐 보고, 다시 공부할 항목을 찾습니다.", spotlight: .contentTop),
        .init(id: "profile", section: "프로필", route: .pro,
              title: "개인 설정과 튜토리얼은 프로필에서 관리합니다.",
              message: "프로필 사진, 닉네임, 코치 모드를 바꾸고 원하는 튜토리얼 편을 다시 시작할 수 있습니다.", spotlight: .profile),
    ]

    /// 최신 웹 `arena-tutorial.js`의 6개 편·23개 단계를 같은 순서와
    /// 문구로 유지한다. 웹 전용 작전 페이지는 앱의 Arena 화면 영역에
    /// 연결하고, Ranked 상점만 실제 네이티브 상점 route를 쓴다.
    private static let arenaSteps: [String: [NativeTutorialStep]] = [
        "common": [
            .init(id: "common-navigation", section: "기본 안내", route: .rank,
                  title: "현재 내 전장에서 플레이를 시작합니다.",
                  message: "Unranked와 Ranked는 서로 다른 전장입니다. 현재 전장에서 실제로 이용할 수 있는 경기 기능만 보입니다.", spotlight: .header),
            .init(id: "common-match", section: "기본 안내", route: .rank,
                  title: "공식 1대1은 같은 다섯 문제로 겨룹니다.",
                  message: "양쪽이 같은 문제를 풀고, 서버 정산 결과에 따라 공개 티어·티어 안 순위·GP가 움직입니다.", spotlight: .contentTop),
            .init(id: "common-status", section: "기본 안내", route: .rank,
                  title: "내 현재 Arena 상태를 확인합니다.",
                  message: "티어, 티어 안 순위, GP와 현재 전장을 보고 다음 행동을 고릅니다.", spotlight: .contentMiddle),
        ],
        "unranked": [
            .init(id: "unranked-hero", section: "UNRANKED 전장", route: .rank,
                  title: "Unranked는 자동 배정 방식입니다.",
                  message: "같은 티어의 내 위 순위를 먼저 찾고, 후보가 없을 때만 바로 위 티어까지 탐색합니다.", spotlight: .header),
            .init(id: "unranked-status", section: "UNRANKED 전장", route: .rank,
                  title: "신청 전에 내 이용 상태를 확인합니다.",
                  message: "현재 이용 가능 여부, 티어 안 순위와 남은 학습 가능 일수를 보고 잠긴 이유를 확인합니다.", spotlight: .contentTop),
            .init(id: "unranked-battle", section: "UNRANKED 전장", route: .rank,
                  title: "여기서 일반 쟁탈전을 시작합니다.",
                  message: "자동 매치를 신청하고, 이미 잡힌 공격·방어 경기는 진행 중 경기에서 이어 풉니다.", spotlight: .contentMiddle),
            .init(id: "unranked-record", section: "UNRANKED 전장", route: .rank,
                  title: "끝난 경기는 기록으로 남습니다.",
                  message: "상대와 승패, 경기 뒤 티어·순위·GP 변동은 정산이 확정된 기록만 보여줍니다.", spotlight: .contentBottom),
            .init(id: "unranked-progress", section: "UNRANKED 전장", route: .rank,
                  title: "페이백 점수와 공격 출석을 따로 확인합니다.",
                  message: "경기에서 움직이는 페이백 점수와 이용 주기의 공격 출석일은 서로 다른 조건입니다.", spotlight: .contentBottom),
        ],
        "unranked_match": [
            .init(id: "unranked-match-candidate", section: "UNRANKED 1대1", route: .rank,
                  title: "서버가 가장 가까운 상위 후보를 찾습니다.",
                  message: "같은 티어의 상위 순위를 우선하고, 없으면 바로 위 티어로 넓힌 뒤 최근 방어 부담도 함께 봅니다.", spotlight: .contentTop),
            .init(id: "unranked-match-stake", section: "UNRANKED 1대1", route: .rank,
                  title: "신청 전에 예치와 오늘의 참가 범위를 봅니다.",
                  message: "내 Arena 상태, 이번 경기의 페이백 점수와 탐색 가능 티어를 확인합니다.", spotlight: .contentMiddle),
            .init(id: "unranked-match-action", section: "UNRANKED 1대1", route: .rank,
                  title: "가능한 행동 하나만 선택하면 됩니다.",
                  message: "신청 가능할 때는 자동 매치를 시작하고, 진행 중 경기가 있으면 같은 자리에서 복귀합니다.", spotlight: .contentBottom),
        ],
        "ranked": [
            .init(id: "ranked-hero", section: "RANKED 전장", route: .rank,
                  title: "Ranked에서는 학습일수를 직접 운용합니다.",
                  message: "상향 쟁탈전과 하위 티어 초대전에서 목표 티어와 학습일수를 정합니다.", spotlight: .header),
            .init(id: "ranked-wallet", section: "RANKED 전장", route: .rank,
                  title: "사용 가능한 학습일수부터 확인합니다.",
                  message: "초대 예약이나 진행 중 경기에 예치된 일수는 새 경기와 상점에 쓸 수 없습니다.", spotlight: .contentTop),
            .init(id: "ranked-battle", section: "RANKED 전장", route: .rank,
                  title: "경기 지휘에서 플레이 방식을 고릅니다.",
                  message: "상향 쟁탈전·하위 티어 초대전·복수전·친선 경기 중 필요한 행동을 선택합니다.", spotlight: .contentMiddle),
            .init(id: "ranked-operations", section: "RANKED 전장", route: .rank,
                  title: "초대와 학습일수 이동을 관리합니다.",
                  message: "받은 초대와 보낸 예약, 사용 가능·예약·경기 예치 일수와 이동 기록을 따로 확인합니다.", spotlight: .contentBottom),
            .init(id: "ranked-shop", section: "RANKED 전장", route: .rank,
                  title: "확보한 학습일수는 상점에서도 사용합니다.",
                  message: "경기 분석, 일정 보호와 프로필 효과가 필요하면 Ranked 상점으로 들어갑니다.", spotlight: .contentBottom),
        ],
        "ranked_battle": [
            .init(id: "ranked-battle-status", section: "RANKED 경기", route: .rank,
                  title: "새 경기 전에 현재 이용 가능 상태를 봅니다.",
                  message: "진행 중 공식 경기, 부족한 학습일수나 이용 제한이 있으면 작전이 잠기고 이유가 표시됩니다.", spotlight: .contentTop),
            .init(id: "ranked-battle-upward", section: "RANKED 경기", route: .rank,
                  title: "상향 쟁탈전은 목표 티어를 정해 도전합니다.",
                  message: "최대 세 티어 위까지 목표와 예치량을 고르면 서버가 적격 상대를 무작위 배정합니다.", spotlight: .contentMiddle),
            .init(id: "ranked-battle-invite", section: "RANKED 경기", route: .rank,
                  title: "하위 티어 초대전은 먼저 예약을 만듭니다.",
                  message: "목표 하위 티어에 일괄 초대하고, 먼저 수락한 한 명과만 같은 학습일수를 예치합니다.", spotlight: .contentMiddle),
            .init(id: "ranked-battle-friendly", section: "RANKED 경기", route: .rank,
                  title: "친선전은 랭크 부담 없이 연습합니다.",
                  message: "Ranked 사용자를 닉네임으로 초대하지만 티어·GP·학습일수는 움직이지 않습니다.", spotlight: .contentBottom),
            .init(id: "ranked-battle-invitations", section: "RANKED 경기", route: .rank,
                  title: "받은 초대와 보낸 예약을 여기서 처리합니다.",
                  message: "받은 초대는 조건을 보고 수락·거절하며, 보낸 예약은 상태와 취소 가능 여부를 확인합니다.", spotlight: .contentBottom),
        ],
        "ranked_shop": [
            .init(id: "ranked-shop-wallet", section: "RANKED 상점", route: .arenaShop,
                  title: "상점은 사용 가능한 학습일수로 이용합니다.",
                  message: "초대 예약이나 경기 예치 중인 일수는 쓸 수 없으므로 먼저 현재 잔액을 확인합니다.", spotlight: .contentTop),
            .init(id: "ranked-shop-grid", section: "RANKED 상점", route: .arenaShop,
                  title: "필요한 효과의 카드를 선택합니다.",
                  message: "경기 분석·일정 보호·프로필 효과의 가격과 적용 범위를 확인한 뒤 사용합니다.", spotlight: .contentMiddle),
        ],
    ]

    var body: some View {
        Group {
            if run != nil, steps.indices.contains(stepIndex) {
                GeometryReader { proxy in
                    let target = spotlightRect(for: steps[stepIndex].spotlight, in: proxy)
                    ZStack {
                        if spotlightVisible {
                            TutorialDimShape(spotlight: target)
                                .fill(Color.black.opacity(0.72), style: FillStyle(eoFill: true))
                                .ignoresSafeArea()
                                .allowsHitTesting(false)
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Tokens.brandCyan, lineWidth: 3)
                                .frame(width: target.width, height: target.height)
                                .position(x: target.midX, y: target.midY)
                                .shadow(color: Tokens.brandCyan.opacity(0.45), radius: 10)
                                .allowsHitTesting(false)
                        } else {
                            Color.black.opacity(0.72).ignoresSafeArea()
                        }

                        tutorialCard(
                            step: steps[stepIndex],
                            proxy: proxy,
                            sitsAboveTarget: target.midY > proxy.size.height * 0.52)
                    }
                    .animation(reduceMotion || !store.motionOn ? nil : .easeOut(duration: 0.2),
                               value: spotlightVisible)
                }
                .transition(.opacity)
                .zIndex(20_000)
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)
            }
        }
        .task(id: triggerKey) { await startIfNeeded() }
        .task(id: runDescription) {
            coachFrame = 1
            guard run != nil, !reduceMotion, store.motionOn else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                coachFrame = coachFrame % 3 + 1
            }
        }
    }

    private var runDescription: String {
        switch run {
        case .dashboard: "dashboard"
        case .arena(let chapter): "arena-\(chapter)"
        case nil: "none"
        }
    }

    @ViewBuilder
    private func tutorialCard(
        step: NativeTutorialStep,
        proxy: GeometryProxy,
        sitsAboveTarget: Bool
    ) -> some View {
        let compact = proxy.size.width < 600
            || proxy.size.height < 500
            || dynamicTypeSize.isAccessibilitySize
        let maximumPanelHeight = max(
            220,
            proxy.size.height - max(48, proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom + 36)
        )
        VStack {
            if !sitsAboveTarget { Spacer(minLength: 0) }
            Group {
                if compact {
                    tutorialPanel(
                        step: step,
                        compact: true,
                        maximumHeight: maximumPanelHeight)
                        .frame(maxWidth: .infinity)
                } else {
                    HStack(alignment: .bottom, spacing: Tokens.Space.s3) {
                        coachImage.frame(width: 88, height: 100)
                        tutorialPanel(
                            step: step,
                            compact: false,
                            maximumHeight: maximumPanelHeight)
                            .frame(maxWidth: 620)
                    }
                }
            }
            .padding(.horizontal, max(18, proxy.safeAreaInsets.leading + 18))
            .padding(.vertical, max(24, proxy.safeAreaInsets.bottom + 24))
            if sitsAboveTarget { Spacer(minLength: 0) }
        }
    }

    private var coachImage: some View {
        AsyncImage(url: URL(
            string: "/images/coach-characters/mild-goat-\(coachFrame).webp",
            relativeTo: ServerAPI.baseURL)?.absoluteURL) { phase in
            if let image = phase.image { image.resizable().scaledToFit() }
            else { Color.clear }
        }
        .accessibilityHidden(true)
    }

    private func tutorialPanel(
        step: NativeTutorialStep,
        compact: Bool,
        maximumHeight: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            HStack(alignment: .top) {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        ScrollView(.vertical) {
                            tutorialCopy(step)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .scrollIndicators(.visible)
                        .frame(maxHeight: max(96, maximumHeight - 132))
                    } else {
                        tutorialCopy(step)
                    }
                }
                Spacer(minLength: Tokens.Space.s2)
                if compact {
                    coachImage.frame(width: 44, height: 50)
                }
                Button("건너뛰기", systemImage: "xmark") { finish(skipped: true) }
                    .labelStyle(.iconOnly)
                    .frame(width: 44, height: 44)
                    .disabled(mutationInFlight)
                    .accessibilityLabel("튜토리얼 건너뛰기")
            }
            ProgressView(
                value: Double(stepIndex + 1),
                total: Double(max(1, steps.count)))
                .tint(Tokens.primary)
            if let mutationError {
                Text(mutationError)
                    .font(.mCaption)
                    .foregroundStyle(Tokens.dangerInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Text("\(stepIndex + 1) / \(steps.count)")
                    .font(.mCaption).foregroundStyle(Tokens.text3)
                Spacer()
                Button(stepIndex + 1 == steps.count ? "완료" : "다음") {
                    advance()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(mutationInFlight)
            }
        }
        .padding(compact ? Tokens.Space.s4 : Tokens.Space.s5)
        // 일반 글자 크기에서는 카드가 본문 높이만 감싸야 한다. 이전에는 아래
        // maxHeight 프레임이 iPad의 큰 세로 제안을 그대로 받아 카드가 화면 대부분을
        // 차지했고, HStack의 bottom 정렬을 타는 코치가 본문에서 수백 pt 떨어졌다.
        // 접근성 글자 크기에서는 반대로 카드가 화면을 넘지 않아야 하므로 고정을
        // 풀고 위 copy ScrollView + maximumHeight 제한을 그대로 사용한다.
        .fixedSize(horizontal: false,
                   vertical: !dynamicTypeSize.isAccessibilitySize)
        .frame(maxHeight: dynamicTypeSize.isAccessibilitySize ? maximumHeight : nil)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private func tutorialCopy(_ step: NativeTutorialStep) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("MATTHS TOUR · \(step.section.uppercased())")
                .font(.mMicro)
                .tracking(1.4)
                .foregroundStyle(Tokens.primary)
            Text(step.title)
                .font(.mHeading)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(step.message)
                .font(.mBody)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// MainTabBar.items와 같은 순서다. 탭 개수나 순서가 바뀌어도 숫자 인덱스를
    /// 튜토리얼 문장에 박아 두지 않도록 route로 타겟을 찾는다.
    private static let tutorialTabRoutes: [AppStore.Route] = [
        .home, .curriculum, .assess, .wrongNotes, .community, .rank,
    ]

    private func spotlightRect(
        for spotlight: NativeTutorialStep.Spotlight,
        in proxy: GeometryProxy
    ) -> CGRect {
        let size = proxy.size
        let safeTop = proxy.safeAreaInsets.top
        let safeBottom = proxy.safeAreaInsets.bottom
        let contentTop = safeTop + 68
        let contentBottom = max(contentTop + 120, size.height - safeBottom - 94)
        let contentHeight = max(120, contentBottom - contentTop)
        switch spotlight {
        case .header:
            return CGRect(x: 16, y: safeTop + 4,
                          width: max(1, size.width - 32), height: 64)
        case .contentTop:
            return CGRect(x: 16, y: contentTop,
                          width: max(1, size.width - 32),
                          height: min(245, contentHeight * 0.34))
        case .contentMiddle:
            let height = min(260, contentHeight * 0.36)
            return CGRect(x: 16,
                          y: max(contentTop, (contentTop + contentBottom - height) / 2),
                          width: max(1, size.width - 32), height: height)
        case .contentBottom:
            let height = min(245, contentHeight * 0.34)
            return CGRect(x: 16, y: max(contentTop, contentBottom - height),
                          width: max(1, size.width - 32), height: height)
        case .tab(let route):
            guard let index = Self.tutorialTabRoutes.firstIndex(of: route) else {
                return CGRect(x: 16, y: contentTop,
                              width: max(1, size.width - 32), height: 120)
            }
            let barWidth = min(560, size.width)
            let originX = (size.width - barWidth) / 2
            let width = barWidth / CGFloat(Self.tutorialTabRoutes.count)
            return CGRect(x: originX + width * CGFloat(index),
                          y: size.height - safeBottom - 74,
                          width: width, height: 62).insetBy(dx: 4, dy: -3)
        case .topAction(let route):
            // 상단바 trailing 순서는 AI 튜터→알림→프로필이다. 오버레이의
            // GeometryReader는 가로 safe area 안쪽 폭을 받으므로 profile과 같은
            // 기준점에서 56pt(44pt 표적 + 12pt 간격)씩 왼쪽으로 이동한다.
            let slotsFromProfile: CGFloat
            switch route {
            case .chat: slotsFromProfile = 2
            case .notifications: slotsFromProfile = 1
            default: slotsFromProfile = 0
            }
            return CGRect(
                x: size.width - proxy.safeAreaInsets.trailing - 24 - slotsFromProfile * 56,
                y: safeTop + 4, width: 56, height: 62)
        case .profile:
            // 오버레이 GeometryReader의 폭은 가로 safe area 안쪽에서 제안된다.
            // 따라서 여기서 trailing inset을 다시 크게 빼면 한 칸 왼쪽의 알림 버튼을
            // 두른다. 우측으로 열어 둔 24pt가 safe area 밖 아바타 중심까지 포함한다.
            return CGRect(x: size.width - proxy.safeAreaInsets.trailing - 24,
                          y: safeTop + 4, width: 56, height: 62)
        }
    }

    @MainActor
    private func startIfNeeded() async {
        guard run == nil, !store.isSessionMode else { return }

        #if DEBUG
        if !consumedDebugFixture,
           let fixture = Self.argumentValue(after: "-tutorialFixture") {
            consumedDebugFixture = true
            let normalized = fixture.replacingOccurrences(of: "arena-", with: "")
            if fixture == "dashboard" {
                store.isTutorialPresentationActive = true
                run = .dashboard
                stepIndex = Self.fixtureStepIndex(count: Self.dashboardSteps.count)
                await settle(on: Self.dashboardSteps[stepIndex].route)
            } else if Self.arenaSteps[normalized] != nil {
                let fixtureSteps = Self.arenaSteps[normalized] ?? []
                store.isTutorialPresentationActive = true
                run = .arena(normalized)
                stepIndex = Self.fixtureStepIndex(count: fixtureSteps.count)
                await settle(on: fixtureSteps[stepIndex].route)
            }
            return
        }
        #endif

        guard store.authProvider == "server", let profile = store.serverProfile else { return }

        // 첫 로그인 PENDING 상태는 짧은 목표 선택 온보딩이 단독으로 소유한다.
        // Arena 자동 투어까지 같은 프레임에 겹치면 두 모달이 서로 포커스를 빼앗는다.
        if profile.dashboardTutorial?.shouldAutoStart == true,
           !store.requestedDashboardTutorial {
            return
        }

        // 프로필에서 사용자가 직접 고른 챕터는 서버의 autoChapter와 별개다.
        // 선택 자체가 명시적인 시작 의사이므로 그 요청을 가장 먼저 소비한다.
        if let requested = store.requestedArenaTutorialChapter,
           let arena = profile.arenaTutorial,
           !arena.suspended,
           arena.availableChapters.contains(requested),
           arena.chapters[requested]?.status == "PENDING" {
            let requiredRoute: AppStore.Route = requested == "ranked_shop" ? .arenaShop : .rank
            guard store.route == requiredRoute else { return }
            store.requestedArenaTutorialChapter = nil
            store.isTutorialPresentationActive = true
            run = .arena(requested)
            stepIndex = 0
            await settle(on: requiredRoute)
            return
        }

        if store.requestedDashboardTutorial,
           profile.dashboardTutorial?.shouldAutoStart == true {
            store.isTutorialPresentationActive = true
            run = .dashboard
            stepIndex = 0
            await settle(on: .home)
            return
        }

        // 최신 웹과 같은 판정: Arena 응답은 의도적으로 autoChapter=null,
        // shouldAutoStart=false를 준다. 현재 페이지와 division으로 해당 챕터를
        // 고른 뒤 PENDING인지 확인해야 실제로 열린다.
        guard let arena = profile.arenaTutorial, !arena.suspended else { return }
        let pageChapter: String?
        switch store.route {
        case .arenaShop:
            pageChapter = "ranked_shop"
        case .rank:
            switch arena.activeDivision?.uppercased() {
            case "SUB": pageChapter = "unranked"
            case "MAIN": pageChapter = "ranked"
            default: pageChapter = nil
            }
        default:
            pageChapter = nil
        }
        guard let chapter = pageChapter,
              arena.availableChapters.contains(chapter),
              arena.chapters[chapter]?.status == "PENDING" else { return }
        store.isTutorialPresentationActive = true
        run = .arena(chapter)
        stepIndex = 0
        await settle(on: store.route)
    }

    #if DEBUG
    private static func argumentValue(after flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else {
            return nil
        }
        return arguments[index + 1]
    }

    /// 사람에게 보이는 단계 번호(1부터)를 받아 유효 범위로 고정한다.
    /// `-tutorialFixture dashboard -tutorialStep 31`로 마지막 profile spotlight를
    /// 다른 화면을 30번 넘기지 않고 반복 검사할 수 있다.
    private static func fixtureStepIndex(count: Int) -> Int {
        guard count > 0,
              let raw = argumentValue(after: "-tutorialStep"),
              let oneBased = Int(raw) else { return 0 }
        return min(max(0, oneBased - 1), count - 1)
    }
    #endif

    @MainActor
    private func settle(on route: AppStore.Route) async {
        spotlightVisible = false
        store.route = route
        if !reduceMotion && store.motionOn {
            try? await Task.sleep(for: .milliseconds(380))
        }
        guard run != nil else { return }
        spotlightVisible = true
    }

    private func advance() {
        guard !mutationInFlight else { return }
        mutationError = nil
        if stepIndex + 1 >= steps.count {
            finish(skipped: false)
            return
        }
        stepIndex += 1
        let route = steps[stepIndex].route
        Task { await settle(on: route) }
    }

    private func finish(skipped: Bool) {
        guard let activeRun = run, !mutationInFlight else { return }
        #if DEBUG
        if consumedDebugFixture {
            store.isTutorialPresentationActive = false
            run = nil
            spotlightVisible = false
            mutationError = nil
            return
        }
        #endif
        mutationInFlight = true
        mutationError = nil
        Task {
            do {
                switch activeRun {
                case .dashboard:
                    _ = try await ServerAPI.updateDashboardTutorial(skipped ? "SKIP" : "COMPLETE")
                case .arena(let chapter):
                    _ = try await ServerAPI.updateArenaTutorial(
                        chapter: chapter, action: skipped ? "SKIP" : "COMPLETE")
                }
                await store.refreshServerProfile()
            } catch {
                // 완료 상태가 서버에 저장되지 않으면 닫지 않는다. 재시도 가능한 같은
                // 버튼을 남겨 기기만 완료된 거짓 상태를 만들지 않는다.
                mutationInFlight = false
                mutationError = (error as? ServerAPIError)?.errorDescription
                    ?? "튜토리얼 상태를 저장하지 못했습니다. 다시 시도해 주세요."
                return
            }
            store.requestedDashboardTutorial = false
            store.requestedArenaTutorialChapter = nil
            store.isTutorialPresentationActive = false
            run = nil
            spotlightVisible = false
            mutationInFlight = false
        }
    }
}

// MARK: - 하단 탭바

struct MainTabBar: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private struct Item {
        let route: AppStore.Route
        let title: String
        let icon: String
        var badge: Int? = nil
    }

    // 탭은 동급 목적지 3~5개 원칙(0752)에 맞춰 5개만 남긴다.
    // 채점 Pro(도구)는 평가센터의 진입 카드로, AI 튜터(도구)는 상단바 버튼으로 —
    // Route enum 과 두 화면은 그대로라 기존 라우팅(.pro/.chat)은 계속 동작한다.
    private var items: [Item] {
        [
            .init(route: .home,       title: "홈",       icon: "house.fill"),
            .init(route: .curriculum, title: "커리큘럼", icon: "square.grid.2x2.fill"),
            .init(route: .assess,     title: "평가센터", icon: "flag.fill"),
            .init(route: .wrongNotes, title: "오답노트", icon: "book.fill", badge: store.dueReviewCount),
            // 게시판은 여섯째다 — 5개 원칙(0752)을 하나 넘지만, 웹 IA 에 있는 동급 목적지를
            // 앱에서만 숨길 수는 없다. 제목은 lineLimit(1)+축소라 iPhone 세로에서도 들어간다.
            .init(route: .community,  title: "게시판",   icon: "text.bubble.fill"),
            .init(route: .rank,       title: arenaTabTitle, icon: "crown.fill"),
        ]
    }

    /// 아레나 탭의 표시 이름. **좁은 폭에서만** 줄인다.
    ///
    /// 여섯 칸이 되면서 iPhone 세로의 한 칸은 65.7pt 다(402pt − 좌우 4pt, ÷6).
    /// "GOAT Arena" 는 caption2 11pt 에서 약 80pt 라, 0.8 까지 줄여도 64pt —
    /// 칸을 꽉 채우고 선택 알약(좌우 3pt 안쪽)을 좌우로 뚫고 나간다.
    /// 실측에서 감독이 "탭 버튼이 삐져나온다" 고 짚은 지점이 정확히 이것이다.
    /// 더 줄이면(0.7 이하) 7pt 대 글자가 되어 읽을 수 없으니 글자 크기가 아니라
    /// **이름 길이**를 줄인다. 아이콘은 왕관 그대로고 눌러 들어가면 셸이 네이비로
    /// 바뀌므로 "Arena" 만으로도 목적지가 흔들리지 않는다.
    /// 폭이 regular 인 iPad(칸 93pt)는 전체 이름 그대로다.
    /// VoiceOver 라벨은 accessibilityLabel(for:) 이 항상 전체 이름을 읽는다.
    private var arenaTabTitle: String {
        horizontalSizeClass == .compact ? "Arena" : "GOAT Arena"
    }

    var body: some View {
        // 높이가 compact라는 이유만으로 iPhone 가로의 넓은 폭까지 아이콘 전용으로
        // 만들지 않는다. 왕관·깃발·책만 나열하면 처음 쓰는 학생은 목적지를 추측해야
        // 한다. 실제 가용 폭이 350pt 이상이면 44pt 바 안에서도 아이콘+짧은 이름이
        // 들어가므로 이름을 유지하고, 정말 좁은 Slide Over에서만 아이콘으로 줄인다.
        ViewThatFits(in: .horizontal) {
            tabRow(showTitles: true)
                // 여섯 칸 기준. 350pt 면 한 칸 58pt 라 네 글자 한글 이름(약 44pt)이
                // 좌우 여백과 0.8 축소를 포함해 들어간다. 320pt Slide Over(가용 312pt)는
                // 이 문턱을 못 넘어 아이콘 전용으로 떨어진다.
                .frame(minWidth: 350)
            tabRow(showTitles: false)
        }
        .adaptiveBarPadding()
        // 탭을 화면 끝까지 벌리지 않는다. 13인치 가로에서 5개가 1366pt 에 흩어지면
        // 엄지로 옮겨 다닐 수 없고, 눈으로도 한 덩어리로 안 읽힌다.
        // iPadOS 의 기본 탭바도 항목을 가운데 묶어서 보여준다.
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .padding(.top, verticalLayoutClass == .compact ? 2 : 6)
        .background(store.isArenaRoute ? Tokens.brandNavy : Color(uiColor: .systemBackground))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(store.isArenaRoute ? Tokens.brandCyan.opacity(0.52) : Tokens.line)
                .frame(height: store.isArenaRoute ? 1 : 0.5)
        }
        // 키보드가 올라와도 탭바가 따라 올라오지 않게 한다.
        // 답을 입력하는 중에 메뉴가 튀어 오르면 오탭이 난다.
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var verticalLayoutClass: MatthsLayoutClass {
        switch verticalSizeClass {
        case .compact: .compact
        case .regular: .regular
        default: .unspecified
        }
    }

    private func tabRow(showTitles: Bool) -> some View {
        HStack(spacing: 0) {
            // id 는 route 다. 제목으로 잡으면 회전으로 arenaTabTitle 이 바뀌는 순간
            // 그 항목이 다른 뷰가 되어 선택 바운스 상태(TabIcon.bounces)가 날아간다.
            ForEach(Array(items.enumerated()), id: \.element.route) { index, item in
                tab(item, showTitle: showTitles, ordinal: index + 1)
            }
        }
    }

    @ViewBuilder private func tab(_ item: Item, showTitle: Bool, ordinal: Int) -> some View {
        let selected = store.selectedTab == item.route
        let isArenaItem = item.route == .rank
        let arenaShell = store.isArenaRoute

        Button {
            store.route = item.route
        } label: {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    // 선택 표시는 색과 굵기로만 한다. 아이콘 뒤에 알약을 깔지 않는다.
                    // 선택 순간의 바운스가 유일한 추가 모션 (모션 설정 존중).
                    TabIcon(icon: item.icon,
                            selected: selected,
                            motion: store.motionOn && !reduceMotion,
                            width: showTitle ? 52 : 36,
                            arena: isArenaItem)

                    if let badge = item.badge, badge > 0 {
                        Text("\(badge)")
                            .font(Font.stat(11, .semibold))
                            .foregroundStyle(Tokens.onPrimary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Tokens.danger, in: Capsule())
                            .offset(x: 6, y: -4)
                    }
                }

                if showTitle {
                    Text(item.title)
                        // 고정 11pt 대신 caption2(기준 11pt) — 접근성 글자 크기를 따라간다
                        .font(.system(.caption2, weight: selected ? .bold : .medium))
                        // 다만 접근성 글씨를 끝까지 따라가면 여섯 칸에서는 방법이 없다:
                        // caption2 는 AX5 에서 32pt 라 "커리큘럼" 한 단어가 128pt,
                        // 한 칸(65.7pt)의 두 배다. 라벨을 통째로 없애 아이콘만 남기는
                        // 것보다(저시력 사용자에게 더 나쁘다) 여기서 성장만 멈춘다.
                        // 본문 글자 크기는 그대로고 탭 이름만 xxxLarge(15pt)에서 선다.
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        // 선택 알약이 좌우 3pt 안쪽에 그려지므로 글자는 그보다 먼저
                        // 끝나야 한다. 이 4pt 가 없으면 긴 이름이 알약 테두리를 뚫는다.
                        .padding(.horizontal, 4)
                }
            }
            .foregroundStyle(
                selected
                    ? (isArenaItem ? Tokens.brandCyan : Tokens.ink)
                    : (arenaShell ? Tokens.onNavy.opacity(0.56)
                                  : Tokens.text3))
            .frame(maxWidth: .infinity)
            // compact 높이에서는 50이 44로 내려가도 라벨을 유지한다. 아이콘 20pt,
            // 간격 3pt, 제한된 caption 라벨이 이 안에 들어간다. 여기서 40까지 더
            // 내리지는 않는다: 탭 여섯 개가 전부 이 높이 그대로
            // 히트 영역이라, 44 아래로 내리면 최소 터치 타깃이 그냥 깨진다.
            // 아이콘은 20pt 라 시각적으로는 이미 여유가 없다.
            .frame(minHeight: UniversalLayoutPolicy.tabMinimumHeight(
                vertical: verticalLayoutClass))
            .background {
                if isArenaItem && selected {
                    RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                        .fill(Tokens.navyElevated)
                        .overlay {
                            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                                .strokeBorder(
                                    Tokens.brandCyan.opacity(0.5),
                                    lineWidth: 1)
                        }
                        .padding(.horizontal, 3)
                        // 세로로도 안쪽으로 물린다. 이 알약은 탭 항목의 히트 영역
                        // (최소 44pt)과 높이가 같아서, 물리지 않으면 바 아래쪽 경계에
                        // 딱 붙어 홈 인디케이터 띠로 흘러내린 것처럼 보인다.
                        // 히트 영역은 바깥 frame 이 잡으므로 여기서 줄여도 터치는 그대로다.
                        .padding(.vertical, 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // 하드웨어 키보드 — ⌘1~⌘5 로 다섯 탭을 오간다. ⌘ 를 길게 누르면
        // 시스템 단축키 목록에 접근성 라벨과 함께 자동 노출된다 (1651·1652).
        .keyboardShortcut(KeyEquivalent(Character("\(ordinal)")), modifiers: .command)
        .accessibilityLabel(accessibilityLabel(for: item))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func accessibilityLabel(for item: Item) -> String {
        // 좁은 폭에서 화면에 적히는 이름은 줄어도(arenaTabTitle) 읽어 주는 이름은
        // 언제나 전체 이름이다 — 목적지의 정체성을 화면 폭이 깎으면 안 된다.
        let spoken = item.route == .rank ? "GOAT Arena" : item.title
        guard let badge = item.badge, badge > 0 else { return spoken }
        return "\(spoken), 처리할 항목 \(badge)개"
    }
}

/// 탭 아이콘 — 선택되는 순간에만 한 번 튄다.
///
/// `symbolEffect(.bounce, value:)` 는 값이 "바뀌면" 발동하지 방향을 보지 않는다.
/// 그래서 selected 를 그대로 넘기면 선택이 풀리는 탭(true→false)도 같이 튀어,
/// 탭을 옮길 때마다 두 아이콘이 동시에 튀었다. 발동 횟수를 직접 세서
/// "선택됨" 으로 바뀐 쪽만 올린다.
private struct TabIcon: View {
    let icon: String
    let selected: Bool
    /// 앱 모션 설정 + 동작 줄이기를 이미 반영한 값
    let motion: Bool
    let width: CGFloat
    let arena: Bool

    @State private var bounces = 0

    var body: some View {
        ZStack {
            // GOAT 전용 원형 장식은 선택됐을 때만 보인다. 선택 전에도 보라색
            // 원·테두리가 남으면 현재 탭처럼 읽혀 홈의 선택 상태와 충돌한다.
            if arena && selected {
                Circle()
                    .fill(Tokens.brandCyan.opacity(0.13))
                    .frame(width: 30, height: 30)
                Circle()
                    .strokeBorder(Tokens.brandCyan.opacity(0.7), lineWidth: 1)
                    .frame(width: 30, height: 30)
            }

            Image(systemName: icon)
                .font(.system(size: arena ? 17 : 20,
                              weight: selected ? .bold : .regular))
                .symbolEffect(.bounce, options: .speed(1.4), value: bounces)
        }
        .frame(width: width, height: 30)
        .onChange(of: selected) { _, isSelected in
            if isSelected && motion { bounces += 1 }
        }
    }
}

private struct AdaptiveBarPadding: ViewModifier {
    @Environment(\.horizontalSizeClass) private var hSize

    func body(content: Content) -> some View {
        // 320pt 에서 탭 5개가 각각 44pt+ 터치 폭을 확보하도록 좁을 때는 4pt 로 줄인다.
        // 텍스트는 MainTabBar가 숨기고 접근성 라벨은 그대로 남긴다.
        content.padding(.horizontal, hSize == .compact ? Tokens.Space.s1 : Tokens.Space.s5)
    }
}

private extension View {
    func adaptiveBarPadding() -> some View { modifier(AdaptiveBarPadding()) }
}

// MARK: - 홈
//
// 정보 대시보드가 아니라 "오늘의 미션" 화면이다 — 폴드 위에서 끝난다:
//  ① 머리: 작은 인사·날짜 한 줄 + 괘선. 여기서 끝난다 — 예전의 큰 상태 제목
//     ("○○을 이어서 학습하세요")은 바로 아래 히어로가 같은 개념명을 다시 말해서
//     같은 문장을 두 번 읽히게 했다. 큰 글자 자리는 히어로에게 넘긴다:
//     화면에서 제일 큰 글자가 미션 이름이고 그 바로 아래가 주 CTA 라,
//     왼쪽 위에서 시작한 시선이 곧장 주 행동에 닿는다.
//     스트릭 숫자는 상단바 칩이 이미 맡고 있다 — 본문에서 반복하지 않는다.
//  ② 미션 히어로: 오늘 할 다음 행동 하나 + 유일한 주 CTA. 밀린 복습이 있으면
//     카드가 복습 미션(건수 + 예상 시간 + 복습 시작)이 되고 새 개념은 보조 행으로
//     내려간다. 없으면 다음 개념 미션이다 — 판정은 HomeMission 하나.
//     첫 시각 위계는 언제나 이것이다 — 통계가 미션 위로 올라오지 않는다.
//  ②-b 바로 가기 한 줄: 퀵 연습 · 이용권과 상점. 주 CTA 바로 아래에 붙지만
//     카드도 색 면도 없는 평문 행이라 위계는 한 단계 아래다. 두 곳 다 지금까지
//     다른 화면 안쪽(평가센터 하단 · 프로필)에만 문이 있었다. 여기서 하는 일은
//     문을 하나 더 다는 것뿐이다: 상점의 가격·상품·조건은 상점 화면이 서버에서
//     받아 그대로 보여 준다. 홈은 계산하지도 요약하지도 않는다.
//  ②-c 알림 칸: 문제집·모의고사 팩 안내처럼 서버가 보낸 소식을 싣는 자리.
//     앱이 문구를 지어내지 않는다. 실을 소식이 없으면 칸 자체를 그리지 않는다 —
//     빈 상자는 "올 것이 안 왔다" 로 읽힌다.
//  ③ 받침: 이번 주 학습(괘선 섹션 + 3지표 + 차트, 카드 아님) ·
//     GOAT Arena 예고(화면 유일의 네이비 면). 홈의 흰 카드는 히어로 하나다.
//  실제 본문 폭이 700pt 이상이면 ① 아래를 두 칸으로 세운다:
//     첫 행 왼쪽이 "지금 할 일"(②·②-b·②-c), 오른쪽이 "쌓인 기록"(③-a)이고,
//     Arena 예고(③-b)는 두 칸 아래에서 전체 폭을 쓴다.
//     세로로만 흘리면 ②가 900pt 를 통째로 차지하는데 제목·본문·주 CTA(300pt)는
//     왼쪽 절반에서 끝나, 카드 오른쪽이 통째로 빈 면이 된다(실기 캡처에서
//     사용자가 직접 동그라미 친 지점). 그 자리에 이번 주 학습이 들어온다.
//     위계는 그대로다 — 화면에서 제일 큰 글자와 유일한 색 버튼은 여전히 왼쪽
//     히어로가 갖고, 오른쪽은 카드도 색 면도 없는 괘선 섹션이라 한 단계 아래다.
//     판정은 ViewThatFits가 받은 실제 폭이다(기기 이름이나 size class가 아니다) —
//     iPhone 가로의 800pt대 폭은 두 칸을 쓰고, 좁은 Split View·Stage Manager는
//     즉시 한 칸으로 접힌다.
//  시작 전(학습 기록이 아예 없는 계정)에는 ③을 통째로 걷어낸다 —
//  0분·0/7일은 빈 데이터가 아니라 죽은 숫자고, 랭킹 예고도 첫 문제를 풀기 전에는
//  남의 잔치다. 그 자리도 첫 미션 히어로가 선다. 오른쪽 칸에 실을 것이 없으니
//  두 칸도 만들지 않는다 — 대신 한 칸을 내용 폭에서 멈춰 세운다. 빈 칸을 세우는
//  것은 지금 고치려는 그 문제 그대로이고, 빈 면을 만드느니 카드를 줄인다.
//  로그인 만료는 화면 맨 위의 컴팩트 배너 한 장이 맡고, 아레나 예고는 접는다 —
//  만료 중 입장은 서버 랭킹 화면에서 곧장 실패한다. 대체 문구는 두지 않는다:
//  랭킹전 안내는 랭킹 탭이 담당하고, 홈의 만료 안내는 배너 하나로 끝낸다.
// 나머지(오늘 계획·취약 개념·과목 진도)는 각 목적지 화면이 맡는다.

private enum HomeArenaTierState: Equatable {
    case unknown
    case placementPending
    case tier(String)

    var tierCode: String? {
        guard case let .tier(code) = self else { return nil }
        return code
    }
}

struct HomeScreen: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize

    /// 첫 프레임의 통계. `.task` 는 첫 프레임이 화면에 올라간 **다음** 런루프에서 돌므로,
    /// 여기 초깃값이 곧 사용자가 처음 보는 숫자다. refreshDashboard 의 첫 동기 대입과
    /// 같은 값(firstPaintDashboard)으로 시작해야 두 번째 프레임이 첫 프레임과 다르지 않다.
    @State private var dashboard = HomeScreen.firstPaintDashboard()
    @State private var source: DashboardActivitySource = .local
    @State private var dashboardSlot = DataScope.slot
    @State private var loadID = UUID()
    /// GOAT Arena가 마지막으로 검증해 계정 슬롯에 저장한 서버 티어다.
    /// 홈은 새 요청도, MMR→티어 환산도 하지 않고 이 표시값만 읽는다.
    /// 초깃값도 같은 캐시에서 읽는다 — .unknown 으로 시작하면 첫 프레임은 82pt 물음표,
    /// 다음 프레임은 58pt 휘장이라 아레나 카드 오른쪽이 실행 직후 한 번 뛴다.
    @State private var cachedArenaTierState: HomeArenaTierState = HomeScreen.cachedArenaTier()
    /// "다시 시도" 가 미는 재조회 토큰 — 값이 바뀌면 .task(id:) 가 새로 돈다.
    /// 계정 전환과 같은 취소·재시작 경로를 그대로 타므로 늦은 응답 가드도 동일하다.
    @State private var retryToken = UUID()

    private var accountRole: String {
        #if DEBUG
        if DemoMode.isOn { return DemoMode.demoUser.role?.lowercased() ?? "student" }
        #endif
        return store.serverProfile?.role?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? "student"
    }

    private var isStaffHome: Bool {
        accountRole == "teacher" || accountRole == "admin"
    }

    /// 오늘 날짜 — "2026. 7. 30. 목" 형식 (기기 언어와 무관하게 웹과 같은 한국어).
    private static var todayLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy. M. d. E"
        return formatter.string(from: Date())
    }

    /// 게시된 계정 상태가 바뀌면 기존 task가 취소되고 새 슬롯의 로컬 스냅샷부터 그린다.
    /// 토큰은 401 처리 중 바뀔 수 있으므로 계정 식별자에 넣지 않는다. 넣으면 같은 요청의
    /// 401 응답까지 "다른 계정의 늦은 응답"으로 오인해 동기화 표시가 영원히 남는다.
    private var accountIdentity: String {
        [
            DataScope.slot,
            store.authProvider ?? "guest",
            store.userEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            accountRole,
        ].joined(separator: "|")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            if displayedSource == .expired {
                SyncPausedBanner()
                    .entrance(0)
            }

            greetingHeader
                .entrance(0)

            if usesTwoColumnBody {
                // 사이즈 클래스만으로는 "두 칸이 설 폭인지" 를 알 수 없다. 12.9인치의
                // 50:50 Split View 는 창이 507pt 인데도 regular 이고, 그 폭에서 두 칸을
                // 세우면 칸마다 210pt 라 히어로 제목이 세 줄로 접히고 바로 가기 이름이
                // 잘린다(하네스 507x1100-regular 실측). 그래서 후보 두 개를 세워 두고
                // 들어가는 쪽을 고른다 — 두 후보의 내용물은 완전히 같고 순서만 다르다.
                ViewThatFits(in: .horizontal) {
                    twoColumnBody
                        // 후보의 이상 폭을 고정해 "이 폭이면 두 칸" 을 명시한다.
                        // 안 그러면 ViewThatFits 가 본문 글줄의 한 줄 길이를 이상 폭으로
                        // 재서, 13인치에서도 두 칸이 안 들어간다고 판정한다.
                        .frame(minWidth: Self.twoColumnMinWidth,
                               idealWidth: Self.twoColumnMinWidth,
                               maxWidth: .infinity,
                               alignment: .leading)
                    singleColumnBody
                }
            } else {
                singleColumnBody
            }
        }
        .task(id: "\(accountIdentity)|\(retryToken.uuidString)") {
            await refreshDashboard()
        }
    }

    /// 한 칸 — 아이폰·좁은 Split View·접근성 글씨. 순서 그대로 위에서 아래로 흐른다.
    @ViewBuilder private var singleColumnBody: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            missionBlock
            noticeBoard
            if showsWeeklySection { weeklySection }
            if showsArenaTeaser { arenaTeaser }
        }
        // 넓은데 한 칸으로 흐르는 경우(=시작 전)에는 여기서 폭을 끊는다.
        .frame(maxWidth: soloColumnWidth, alignment: .leading)
    }

    /// 두 칸 — 첫 행은 왼쪽 "지금 할 일", 오른쪽 "쌓인 기록".
    /// Arena 예고는 둘 중 한 칸에 종속시키지 않고 그 아래 전체 폭을 쓴다.
    /// 그래서 카드의 오른쪽 티어 휘장까지 한 번에 읽히고, 왼쪽 열만 길어져
    /// 아래쪽에 불필요한 빈 면이 생기지 않는다.
    private var twoColumnBody: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            HStack(alignment: .top, spacing: Tokens.Space.s8) {
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    missionBlock
                    noticeBoard
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                weeklySection
                    // 안쪽 프레임이 칸을 채우고 바깥 프레임이 340pt 에서 멈춘다.
                    // 남는 폭은 전부 왼쪽 미션이 가져간다 — 3지표와 요일 차트는
                    // 340pt 면 다 읽히고, 히어로는 넓을수록 본문 줄이 산다.
                    // 창이 좁아 340 에 못 미치면 두 칸이 반씩 나눠 갖는다.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(maxWidth: Self.recordColumnWidth, alignment: .leading)
            }

            if showsArenaTeaser { arenaTeaser }
        }
    }

    /// ② 미션 + ②-b 바로 가기 — 한 덩어리다. 섹션 간격(28)이 아니라 카드 간격(16)으로
    /// 붙여야 "주 행동 하나 + 그 아래 가벼운 두 개" 로 읽힌다.
    private var missionBlock: some View {
        VStack(alignment: .leading,
               spacing: vSize == .compact ? Tokens.Space.s3 : Tokens.Space.s4) {
            MissionHeroCard(mission: mission)
                .entrance(1)

            HomeShortcutRow()
                .entrance(2)
        }
    }

    /// ②-c 알림 — 서버가 보낸 안내가 있을 때만 선다. 없으면 자리도 없다.
    @ViewBuilder private var noticeBoard: some View {
        if !notices.isEmpty {
            HomeNoticeBoard(notices: notices)
                .entrance(3)
        }
    }

    /// ③-a 이번 주 학습 — 넓은 폭에서는 오른쪽 칸이 통째로 이 섹션이다.
    private var weeklySection: some View {
        WeeklyStudySection(activity: displayedDashboard, source: displayedSource,
                           onRetry: { retryToken = UUID() })
            .entrance(4)
    }

    /// ③-b GOAT Arena 예고.
    private var arenaTeaser: some View {
        ArenaTeaserCard(tierState: cachedArenaTierState)
            .entrance(5)
    }

    /// 통계 받침을 세울 상태인지 — 시작 전에는 0분·0/7일뿐이라 걷어낸다.
    private var showsWeeklySection: Bool { !isStaffHome && !isPreStart }

    /// 만료 중에는 아레나 예고를 조용히 접는다 — 서버 랭킹 화면이 곧장 실패한다.
    /// 출구(다시 로그인)는 상단 배너 하나가 맡고, 랭킹전 안내는 랭킹 탭 몫이다 —
    /// 홈에 대체 문구를 남기면 상단 배너와 같은 말을 두 번 하는 고아 한 줄이 된다(RG-05).
    private var showsArenaTeaser: Bool {
        !isStaffHome && !isPreStart && displayedSource != .expired
    }

    /// 섹션 사이 간격. 세로가 짧으면(가로 iPhone) 28pt 가 세 번 들어가 84pt 를 먹는다.
    /// 순서도 구성도 그대로 두고 간격만 한 단계 좁힌다. 인사 다음이 미션 히어로이고
    /// 그 다음이 받침이라는 위계는 간격이 아니라 글자 크기가 세운다.
    ///
    /// 폭이 좁을 때(iPhone 세로)도 한 단계 내린다 — 28pt 는 "iPad 에서 따닥따닥" 이라는
    /// 피드백으로 올린 값이고(Tokens.Space.s7 주석), 그 근거가 iPhone 한 칸 흐름에는
    /// 없다. 여기서만 네 번의 간격 중 32pt 를 본문에 돌려준다.
    /// regular 폭·regular 높이(iPad)에서는 종전 s7 그대로다.
    private var sectionSpacing: CGFloat {
        if vSize == .compact { return Tokens.Space.s4 }
        return hSize == .compact ? Tokens.Space.s5 : Tokens.Space.s7
    }

    /// 두 칸 후보를 세울 수 있는 상태인지. 실제 폭 판정은 위 ViewThatFits의
    /// `twoColumnMinWidth`가 맡는다. iPhone 가로는 size class가 compact여도 본문 폭이
    /// 700pt를 넘으므로 두 칸을 써야 하고, iPhone 세로·좁은 Split View는 후보가
    /// 들어가지 않아 자동으로 한 칸으로 돌아온다.
    /// 접근성 글씨에서는 폭과 무관하게 언제나 한 칸이다: 반으로 쪼갠 칸에서는
    /// 3지표가 다시 세로로 풀려 두 칸이 오히려 더 길어진다.
    /// 오른쪽에 실을 기록이 없는 시작 전에도 두 칸을 만들지 않는다 — 빈 칸을
    /// 세우는 것은 지금 고치려는 그 문제(오른쪽이 통째로 빈 화면)와 같다.
    private var usesTwoColumnBody: Bool {
        !dynamicTypeSize.isAccessibilitySize && showsWeeklySection
    }

    /// 넓은 화면인데 한 칸으로 흐를 때(=시작 전) 본문이 멈추는 폭.
    /// 놔두면 히어로가 900pt 를 통째로 먹으면서 카드 오른쪽 절반이 다시 빈 면이 된다.
    /// 채울 것이 없으면 카드를 줄인다 — 접근성 글씨에서는 줄이 짧아지는 쪽이
    /// 손해라 제한하지 않고, 좁은 폭에서는 애초에 잘라낼 폭 자체가 없다.
    private var soloColumnWidth: CGFloat? {
        hSize == .regular && !dynamicTypeSize.isAccessibilitySize ? 620 : nil
    }

    /// 오른쪽 기록 칸의 최대 폭.
    private static let recordColumnWidth: CGFloat = 340

    /// 두 칸이 서려면 필요한 본문 폭(좌우 여백 뺀 값).
    /// 기록 칸 340 + 고랑 32 + 미션 칸 최소 328(카드 안여백 48 을 빼면 본문 280) 이다.
    /// 11인치 세로(본문 770)는 통과하고, 12.9인치 50:50 Split View(본문 443)는 걸러진다.
    private static let twoColumnMinWidth: CGFloat = 700

    /// 시작 전 상태 — 이 계정에 학습 기록이 아예 없다.
    /// "이번 주 0분"(복귀 사용자)과 다른 판정이다: 주간·누적·완료 개념·학습일이
    /// 전부 비어 있어야 한다. 출처가 복구 필요 상태(만료·실패·오프라인·미지원)면
    /// 서버에 기록이 있을 수 있으므로 시작 전으로 단정하지 않고 통계 섹션을 남긴다 —
    /// "다시 시도" 출구가 그 헤더에 있고, 만료의 "다시 로그인" 은 상단 배너에 있다.
    private var isPreStart: Bool {
        switch displayedSource {
        case .unsupported, .offline, .expired, .failed: return false
        case .local, .syncing, .server: break
        }
        let stats = displayedDashboard.stats
        return stats.weeklyStudyMinutes == 0
            && stats.weeklySolvedProblems == 0
            && store.solvedTotal == 0
            && store.progressV2.byConcept.isEmpty
            && store.activityDays.isEmpty
    }

    /// 계정 전환과 task 시작 사이의 한 프레임에도 앞 계정 통계를 보여 주지 않는다.
    /// 상태가 새 슬롯으로 재바인딩되기 전에는 새 슬롯의 로컬 파일을 직접 읽어 그린다.
    private var displayedDashboard: ServerAPI.DashboardActivity {
        dashboardSlot == DataScope.slot ? dashboard : LocalDashboardSnapshot.make()
    }

    private var displayedSource: DashboardActivitySource {
        dashboardSlot == DataScope.slot ? source : .local
    }

    /// 인사·날짜 한 줄 + 괘선. 큰 제목은 여기 없다 — 상태 문장("○○을 이어서
    /// 학습하세요")과 바로 아래 히어로의 개념명이 같은 말을 두 번 했고, 그 큰 글자가
    /// 주 CTA 보다 위에서 시선을 먼저 먹었다. 이제 화면의 제일 큰 글자는 히어로의
    /// 미션 이름이고, 그 바로 아래가 주 버튼이다 — 미션 상태(신규/복습/완료)는
    /// 히어로의 아이브로우가 말한다. 스트릭 칩은 상단바 것 하나로 충분하다.
    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                    greetingText
                        .fixedSize(horizontal: false, vertical: true)
                    dateText
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s4) {
                        greetingText
                            .lineLimit(1)
                        Spacer(minLength: Tokens.Space.s4)
                        dateText
                            .fixedSize(horizontal: true, vertical: false)
                    }

                    VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                        greetingText
                            .fixedSize(horizontal: false, vertical: true)
                        dateText
                    }
                }
            }

            ExamRule()
        }
    }

    /// 오늘의 미션 — 히어로 제목·본문·주 CTA 가 전부 이 판정 하나에서 나온다.
    private var mission: HomeMission {
        homeMission(in: store, preStart: isPreStart, accountRole: accountRole)
    }

    /// 알림 칸에 실을 소식 — **서버가 보낸 것만** 담긴다.
    ///
    /// 지금은 언제나 비어 있다. 앱이 쓰는 홈 기록 응답에는 소식 필드가 없고,
    /// 없는 소식을 앱이 지어내면 그건 안내가 아니라 광고 흉내다.
    /// 서버가 소식을 내려주기 시작하면 이 한 곳만 그 응답을 읽도록 바꾸면 되고,
    /// 화면(HomeNoticeBoard)과 접는 규칙은 그대로 쓴다.
    private var notices: [HomeNotice] {
        #if DEBUG
        if let layoutCheck = HomeNoticeFixture.current { return layoutCheck }
        #endif
        return []
    }

    private var greetingText: some View {
        Text("안녕하세요, \(store.userName)님")
            .font(.mCallout)
            .foregroundStyle(Tokens.text2)
    }

    private var dateText: some View {
        Text(Self.todayLabel)
            .font(.mCaption)
            .foregroundStyle(Tokens.text3)
    }

    /// 첫 프레임에 그릴 통계 — 현재 슬롯에 **서버가 마지막으로 내려준 집계**가 있으면 그것,
    /// 없으면 이 iPad 의 이벤트 집계다.
    ///
    /// 왜 서버 캐시가 먼저인가. 서버 계정의 홈은 로컬 집계를 먼저 그리고 응답이 오면
    /// 서버 집계로 바꿔 그렸다. 둘은 같은 학생의 기록이어도 다른 숫자다(로컬은 이 기기의
    /// 이벤트만, 서버는 전 기기 합산 + 서버 규칙) — 그래서 **매 실행마다** 첫 프레임과
    /// 1초 뒤 프레임의 숫자가 달랐고, 값 길이가 다르면 3지표의 배치까지 뒤집혔다.
    /// 마지막 서버 응답을 슬롯에 남겨 두고 그걸로 시작하면, 그 사이 기록이 안 바뀐 보통의
    /// 재실행에서는 첫 프레임이 곧 최종 프레임이고, 바뀐 경우에도 같은 자리에서 숫자만 바뀐다.
    /// 게스트 슬롯에는 서버 응답이 저장된 적이 없으므로 종전과 같이 로컬 집계다.
    private static func firstPaintDashboard() -> ServerAPI.DashboardActivity {
        DashboardActivityCache.load() ?? LocalDashboardSnapshot.make()
    }

    /// GOAT Arena 캐시의 서버 티어 표시값 — 초깃값과 refreshDashboard 가 같은 판정을 쓴다.
    private static func cachedArenaTier() -> HomeArenaTierState {
        guard let skill = ServerAPI.cachedGoatArenaSnapshot()?.snapshot.ranking.skill else {
            return .unknown
        }
        if let tier = skill.tier?.trimmingCharacters(in: .whitespacesAndNewlines),
           !tier.isEmpty {
            return .tier(tier)
        }
        return skill.status == "PLACEMENT_PENDING" ? .placementPending : .unknown
    }

    /// 서버 집계를 못 쓰는 상태(만료·실패·오프라인·미지원)로 갈 때 — 각주가
    /// "이 기기 기록을 표시합니다" 라고 말하므로 화면의 숫자도 실제 로컬 기록이어야 한다.
    /// 캐시로 시작했더라도 여기서 로컬 집계로 돌린다. 배치는 폭이 정하므로 자리가 흔들리지 않는다.
    private func showLocalRecord(as fallback: DashboardActivitySource) {
        dashboard = LocalDashboardSnapshot.make()
        source = fallback
    }

    @MainActor
    private func refreshDashboard() async {
        let requestID = UUID()
        let requestedAccount = accountIdentity
        let requestedSlot = DataScope.slot
        loadID = requestID

        // 네트워크를 기다리는 동안 빈 스켈레톤 대신 현재 계정 슬롯의 실제 기록을 즉시 표시.
        // 첫 프레임의 @State 초깃값과 **같은 계산**이다 — 계정 전환으로 task 가 다시 돌 때
        // 새 슬롯의 값으로 갈아끼우려고 한 번 더 부른다. 첫 실행에서는 값이 같아 화면이 안 바뀐다.
        dashboard = Self.firstPaintDashboard()
        dashboardSlot = requestedSlot
        source = .local
        cachedArenaTierState = Self.cachedArenaTier()

        // 교사·운영자 홈의 주 작업은 학원 작업대다. 보이지도 않는 학생 학습 통계를
        // 갱신하려고 동기화 큐와 dashboard API를 호출하면 첫 진입만 느려지고,
        // 역할에 따라 허용되지 않은 학생용 응답이 경고로 남을 수 있다.
        guard !isStaffHome else { return }

        #if DEBUG
        if let fixture = DashboardFixture.current {
            switch fixture {
            case "active":
                dashboard = DashboardFixture.active
                source = .server
            case "zero":
                dashboard = DashboardFixture.zero
                source = .server
            case "failure":
                dashboard = DashboardFixture.active
                source = .offline
            default:
                break
            }
            return
        }
        #endif

        // 인증 제공자가 서버일 때만 원격 계정이다. 구버전 전역 프로필의 이메일이
        // 게스트 슬롯에 남은 설치를 이메일 유무만으로 서버 계정 취급하면 안 된다.
        let isServerAccount = store.authProvider == "server"
        // 게스트·디버그 계정은 서버 집계가 없고, 서버 응답 캐시는 계정 슬롯에만 적히므로
        // 게스트 슬롯의 첫 프레임은 언제나 로컬 집계다 — 여기서 더 할 일이 없다.
        guard isServerAccount else { return }
        guard ServerAPI.hasToken else {
            showLocalRecord(as: .expired)
            return
        }

        source = .syncing

        // 서버 집계가 방금까지의 오프라인 이벤트도 포함하도록 큐를 먼저 올린다.
        await SyncEngine.shared.syncNow()
        guard !Task.isCancelled,
              requestID == loadID,
              requestedAccount == accountIdentity else { return }

        // 동기화 중 401이 났다면 SyncEngine이 오류를 보존하고 ServerAPI가 토큰을 지운다.
        guard ServerAPI.hasToken else {
            showLocalRecord(as: .expired)
            return
        }

        do {
            let remote = try await ServerAPI.getDashboardActivity()
            guard !Task.isCancelled,
                  requestID == loadID,
                  requestedAccount == accountIdentity else { return }
            dashboard = remote
            source = .server
            // 다음 실행의 첫 프레임이 이 응답으로 시작한다. 요청을 시작한 슬롯에 적는다 —
            // 응답을 기다리는 사이 계정이 바뀌었으면 위 가드가 이미 걸러냈지만,
            // 다른 학생 슬롯에 적힐 길 자체를 남기지 않는다.
            DashboardActivityCache.save(remote, slot: requestedSlot)
        } catch {
            guard !Task.isCancelled,
                  requestID == loadID,
                  requestedAccount == accountIdentity else { return }
            showLocalRecord(as: DashboardActivitySource(error: error))
        }
    }
}

/// 서버 대시보드 집계의 계정별 마지막 응답 — 다음 실행의 **첫 프레임**이 이걸로 그려진다.
///
/// GOAT Arena 캐시(ServerAPI.cachedGoatArenaSnapshot)와 같은 규칙이다: 슬롯 파일이라
/// 공용 iPad 에서 다른 학생의 숫자가 섞이지 않고, 7일이 지난 값은 이번 주 기록으로
/// 오해될 위험이 커 쓰지 않는다(그때는 종전대로 로컬 집계로 시작한다).
/// 서버가 정본이고 이 파일은 표시 전용 사본이다 — 여기서 집계하거나 병합하지 않는다.
private enum DashboardActivityCache {
    private struct Envelope: Codable {
        var savedAt: Date
        var dashboard: ServerAPI.DashboardActivity
    }

    private static let file = "dashboard-activity-cache.json"
    private static let maximumAge: TimeInterval = 7 * 24 * 60 * 60

    static func load(now: Date = Date()) -> ServerAPI.DashboardActivity? {
        // 게스트 슬롯은 서버 응답을 받은 적이 없다. 파일이 어떻게든 남아 있어도
        // 게스트의 첫 프레임은 이 iPad 기록이어야 한다(refreshDashboard 의 게스트 분기와 같은 축).
        guard DataScope.slot != "guest",
              let data = try? Data(contentsOf: DataScope.url(file)),
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else {
            return nil
        }
        let age = max(0, now.timeIntervalSince(envelope.savedAt))
        guard age <= maximumAge else { return nil }
        return envelope.dashboard
    }

    static func save(_ dashboard: ServerAPI.DashboardActivity, slot: String,
                     savedAt: Date = Date()) {
        let envelope = Envelope(savedAt: savedAt, dashboard: dashboard)
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        try? data.write(to: DataScope.url(file, for: slot), options: .atomic)
    }
}

/// 커리큘럼의 다음 미션 — 웹과 같은 v2 진도 정본의 진행 중 개념을 먼저 찾고,
/// 없으면 공통 과목의 첫 미완료, 그 다음 전체 과목의 첫 미완료를 찾는다.
/// 홈 제목(stateTitle)과 미션 히어로가 이 하나를 같이 쓴다.
@MainActor
private func nextMission(in store: AppStore) -> (course: CourseV2, concept: ConceptV2)? {
    guard let (course, _, concept) = store.progressV2.continueConcept() else { return nil }
    return (course, concept)
}

/// 홈의 오늘 미션 — 제목(stateTitle)·히어로 카드·주 CTA 가 나눠 쓰는 단일 상태.
/// 우선순위: 시작 전 → 밀린 복습 → 다음 개념 → 전 과목 완료.
/// 복습이 개념보다 먼저다 — "부터" 라는 제목 그대로, 밀린 복습을 정리해야
/// 새 학습이 쌓인다(오답노트 배지와 같은 축, store.dueReviewCount).
private enum HomeMission {
    case academy(role: String)
    case firstConcept(course: CourseV2, concept: ConceptV2)
    /// followUp = 다음에 배울 새 개념 — 히어로에서 "바로 가기" 보조 행으로만 보인다
    case review(count: Int, followUp: (course: CourseV2, concept: ConceptV2)?)
    case nextConcept(course: CourseV2, concept: ConceptV2)
    case allDone
}

@MainActor
private func homeMission(in store: AppStore, preStart: Bool,
                         accountRole: String = "student") -> HomeMission {
    if accountRole == "teacher" || accountRole == "admin" {
        return .academy(role: accountRole)
    }
    let next = nextMission(in: store)
    if preStart {
        // 시작 전에는 복습이 있을 수 없다(오답은 풀이 기록에서만 생긴다) — 첫 개념이 미션
        if let (course, concept) = next { return .firstConcept(course: course, concept: concept) }
        return .allDone   // 커리큘럼이 빈 방어 분기 — 현행 데이터에는 없다
    }
    if store.dueReviewCount > 0 {
        return .review(count: store.dueReviewCount, followUp: next)
    }
    if let (course, concept) = next {
        return .nextConcept(course: course, concept: concept)
    }
    return .allDone
}

// 개념명 뒤 목적격 조사(을/를)를 고르던 objectParticle 은 여기 있었다.
// 유일한 호출자가 홈의 큰 상태 제목("○○을 이어서 학습하세요")이었고,
// 그 제목이 히어로의 개념명과 중복이라 사라지면서 같이 지웠다.
// 개념명을 문장에 끼워 넣는 자리가 다시 생기면 그때 복원한다.

/// 로그인 만료 배너 — 통계 섹션에서 분리한 화면 상단의 컴팩트 한 장.
/// 통계 헤더에 섞여 있던 만료 안내는 "내 기록이 날아갔나" 로 읽혔다 —
/// 데이터가 안전하다는 말이 먼저고, 출구는 "다시 로그인" 하나다.
/// 트리거는 종전 통계 헤더의 것과 같다(store.signOut → 인증 화면 복귀).
///
/// 크기는 일부러 죽인다 — 시스템 상태가 제품 가치(미션)보다 크게 서면 안 된다.
/// 전폭 노란 바 대신 미션 콘텐츠와 같은 컬럼에서 760pt 에 멈추고,
/// 세로 패딩 한 단계 축소 + warningSoft 틴트를 낮춰 화면의 첫인상을
/// 미션 히어로에게 돌려준다.
private struct SyncPausedBanner: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Tokens.Space.s3) {
                message
                Spacer(minLength: Tokens.Space.s3)
                loginButton
            }
            VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                message
                loginButton
            }
        }
        .padding(.horizontal, Tokens.Space.s4)
        .padding(.vertical, Tokens.Space.s1)
        .background(Tokens.warningSoft.opacity(0.6),
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        .frame(maxWidth: 760, alignment: .leading)
    }

    private var message: some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s2) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.mCaption)
                .accessibilityHidden(true)
            Text("동기화가 잠시 멈췄어요. 이 기기의 기록은 안전합니다.")
                .font(.mCaption)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Tokens.warningInk)
    }

    private var loginButton: some View {
        Button {
            store.signOut()
        } label: {
            HStack(spacing: 2) {
                Text("다시 로그인").font(.mCaption).fontWeight(.bold)
                Image(systemName: "chevron.right").font(.mMicro)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Tokens.warningInk)
            .frame(minHeight: 44)              // 최소 터치 타겟
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("다시 로그인")
    }
}

private enum DashboardActivitySource: Equatable {
    case local
    case syncing
    case server
    case unsupported
    case offline
    case expired
    case failed

    init(error: Error) {
        if let apiError = error as? ServerAPIError {
            if apiError.statusCode == 404 {
                self = .unsupported
                return
            }
            if apiError.statusCode == 401 {
                self = .expired
                return
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut,
                 .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                self = .offline
            default:
                self = .failed
            }
            return
        }

        self = .failed
    }

    var message: String {
        switch self {
        case .local:
            return "이 기기 기록"
        case .syncing:
            return "서버 기록 확인 중"
        case .server:
            return "서버 기록"
        case .unsupported:
            return "온라인 기록을 사용할 수 없어 이 기기 기록을 표시합니다."
        case .offline:
            return "연결할 수 없어 이 기기 기록을 표시합니다."
        case .expired:
            return "로그인이 만료되어 이 기기 기록을 표시합니다."
        case .failed:
            return "서버 기록을 불러오지 못해 이 기기 기록을 표시합니다."
        }
    }

    // icon/tint 는 지웠다. 출처 상태는 이제 아이콘도 상태색도 없는 각주 한 줄이다
    // (WeeklyStudySection.sourceNote). 예전 규칙 — 만료는 복구 가능한 상태라
    // danger 가 아니라 warning(0373·0276) — 은 색을 안 쓰면서 무의미해졌고,
    // 그 warning 아이콘 + 주황 글자가 통계 위에서 이 섹션의 최고 위계를 먹었다.
    // 상태색을 다시 붙이려면 그게 왜 통계보다 중요한지부터 답해야 한다.
}

private enum LocalDashboardSnapshot {
    static func make(now: Date = Date()) -> ServerAPI.DashboardActivity {
        // JSONL을 한 번만 읽고 서버와 같은 KST 경계·반올림 규칙으로 집계한다.
        let local = EventLog.dashboardSnapshot(now: now)
        let days = local.days.map { day in
            ServerAPI.DashboardActivity.WeeklyActivity.Day(
                dateKey: day.dateKey,
                label: day.label,
                minutes: day.minutes,
                isToday: day.isToday)
        }

        return ServerAPI.DashboardActivity(
            generatedAt: ISO8601DateFormatter().string(from: local.generatedAt),
            stats: .init(
                weeklyStudyMinutes: local.weeklyStudyMinutes,
                weeklyStudyDetail: local.weeklyStudyDetail,
                todayStudyMinutes: local.todayStudyMinutes,
                activeStudyDays: local.activeStudyDays,
                averageStudyMinutes: local.averageStudyMinutes,
                weeklySolvedProblems: local.weeklySolvedProblems,
                weeklySolvedDetail: local.weeklySolvedDetail,
                correctRate: local.correctRate,
                correctRateDetail: local.correctRateDetail),
            weeklyActivity: .init(
                days: days,
                maxMinutes: local.maxMinutes))
    }
}

/// ② 미션 히어로 — 오늘 할 다음 행동 하나.
///
/// 판정은 홈이 내려주는 HomeMission 하나다.
/// 밀린 복습이 있으면 카드 자체가 복습 미션이 되고 새 개념은 보조 행으로 내려간다 —
/// 카드가 복습을 말하는데 주 CTA 가 새 개념을 미는 충돌 방지(회귀 R-02).
///
/// 카드의 미션 이름은 mHeading 이 아니라 mTitle 이다: 홈에서 사라진 큰 상태 제목의
/// 자리를 이 카드가 받았다. 화면에서 제일 큰 글자 바로 아래에 주 버튼이 붙어
/// "무엇을 · 지금 누르면 됨" 이 한 덩어리로 읽힌다.
private struct MissionHeroCard: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var vSize

    /// 홈이 판정해서 내려주는 오늘의 미션 — stateTitle 과 같은 값이다.
    let mission: HomeMission

    /// 과목 진도 — 완료 개념 수 / 전체. 히어로 진행바는 이 실데이터만 쓴다.
    private func progress(in course: CourseV2) -> Double {
        Double(store.progressV2.coursePercent(course)) / 100
    }

    /// 과목에 남은 미완료 개념 수 — "남은 양" 표기의 근거
    private func remaining(in course: CourseV2) -> Int {
        course.allConcepts.filter { store.progressV2.percent(for: $0) < 100 }.count
    }

    /// 다음 개념의 예상 소요 시간(분) — 미션과 같은 v2 강의 메타만 사용한다.
    private func estimatedMinutes(for concept: ConceptV2) -> Int? {
        concept.lesson?.estimatedMinutes ?? 15
    }

    /// 세로가 짧을 때(가로 iPhone) 카드 안쪽을 한 단계 좁힌다. 이 카드가 홈에서
    /// 제일 큰 덩어리라 24pt 안여백이 위아래로 48pt 를 쓴다. 글자 크기와 위계,
    /// 주 버튼 폭은 그대로다. regular 높이에서는 종전 값(안여백 24, 간격 16)이다.
    private var short: Bool { vSize == .compact }

    var body: some View {
        VStack(alignment: .leading, spacing: short ? Tokens.Space.s3 : Tokens.Space.s4) {
            switch mission {
            case let .academy(role):
                academyMission(role: role)
            case let .review(count, followUp):
                reviewMission(count: count, followUp: followUp)
            case let .firstConcept(course, concept):
                conceptMission(course: course, concept: concept, preStart: true)
            case let .nextConcept(course, concept):
                conceptMission(course: course, concept: concept, preStart: false)
            case .allDone:
                allDone
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: short ? Tokens.Space.s4 : Tokens.Space.s6)
    }

    /// 교사·운영자에게 학생 진도나 오답을 첫 행동으로 제시하지 않는다. 역할별 정본
    /// 작업대 하나만 크게 열고, 학습 기능은 기존 하단 탭에서 그대로 사용할 수 있다.
    private func academyMission(role: String) -> some View {
        let admin = role == "admin"
        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                academyMissionStack(admin: admin)
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: Tokens.Space.s8) {
                        academyMissionCopy(admin: admin)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        academyMissionButton(admin: admin)
                            .frame(width: 300)
                    }
                    .frame(minWidth: 652, idealWidth: 652, maxWidth: .infinity)

                    academyMissionStack(admin: admin)
                }
            }
        }
    }

    private func academyMissionStack(admin: Bool) -> some View {
        VStack(alignment: .leading, spacing: short ? Tokens.Space.s3 : Tokens.Space.s4) {
            academyMissionCopy(admin: admin)
            academyMissionButton(admin: admin)
                .frame(maxWidth: 300, alignment: .leading)
        }
    }

    private func academyMissionCopy(admin: Bool) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text(admin ? "오늘의 운영" : "오늘의 수업")
                .font(.mMicro).foregroundStyle(Tokens.text3)
            Text(admin ? "학원 운영 현황 확인" : "담당 반 수업 확인")
                .font(.mTitle).foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(admin
                 ? "승인 대기 학원, 계약 상태와 운영 이상 항목을 확인하고 바로 처리하세요."
                 : "출결을 열고 학생과 수업 자료를 확인한 뒤 오늘 수업을 시작하세요.")
                .font(.mCallout).foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func academyMissionButton(admin: Bool) -> some View {
        Button(admin ? "운영 작업대 열기" : "수업 작업대 열기") {
            store.route = .academy
        }
        .buttonStyle(PrimaryButtonStyle())
        .accessibilityHint(admin
                           ? "학원 승인과 전체 운영 관리 화면으로 이동합니다"
                           : "담당 반 출결과 수업 관리 화면으로 이동합니다")
    }

    /// 복습 미션 — 건수·예상 시간·시작 경로 전부 오답노트와 같은 근거를 쓴다:
    /// 문항당 4분은 복습 문항 복원(WrongNoteEntry.asProblem)의 minutes 와 같은 값,
    /// 시작 세트는 due 전체(WrongNotesScreen 히어로의 startReview 호출과 동일)다.
    @ViewBuilder private func reviewMission(
        count: Int, followUp: (course: CourseV2, concept: ConceptV2)?
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text("오늘의 미션, 오답 복습")
                .font(.mMicro).foregroundStyle(Tokens.text3)
            Text("오늘 복습 \(count)개")
                .font(.mTitle).foregroundStyle(Tokens.ink)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("틀렸던 바로 그 문제를 그대로 다시 풉니다.")
                .font(.mCallout).foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
            Text("예상 약 \(count * 4)분")
                .font(.mCaption).foregroundStyle(Tokens.text2)
                .monospacedDigit()
        }

        // 이 화면의 유일한 주 버튼 — 제목("복습부터 정리해요")과 같은 곳을 가리킨다
        Button("복습 시작") {
            store.startReview(ids: store.wrongNotes.filter(\.isDue).map(\.id))
        }
        .buttonStyle(PrimaryButtonStyle())
        .frame(maxWidth: 300, alignment: .leading)
        .accessibilityLabel("복습 시작, 오늘 복습 \(count)개")

        // 새 개념은 보조 행으로 강등 — 주 CTA 와 경쟁하지 않는 평문 링크 문법.
        // 문구는 동작 그대로 말한다: 누르면 복습을 건너뛰고 즉시 개념으로 간다.
        // "복습 후 이어갈" 은 순서를 약속하는 거짓말이었다(RG-03 — 동작 변경 없음).
        if let (_, concept) = followUp {
            Button {
                store.openConceptV2(concept.id)
            } label: {
                HStack(spacing: Tokens.Space.s2) {
                    Text("새 개념으로 바로 가기: \(concept.title)")
                        .font(.mCaption).foregroundStyle(Tokens.text2)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                        .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.8)
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "chevron.right")
                        .font(.mMicro).foregroundStyle(Tokens.text4)
                }
                .frame(minHeight: 44)          // 평문이어도 터치 타겟은 지킨다
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("새 개념으로 바로 가기, \(concept.title)")
        }
    }

    /// 개념 미션 — preStart 는 개념 판정 축과 목적지를 그대로 두고,
    /// "이어서" 를 "오늘 시작할 첫 미션" 으로 프레이밍만 바꾼다.
    @ViewBuilder private func conceptMission(
        course: CourseV2, concept: ConceptV2, preStart: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text((preStart ? "오늘의 첫 미션" : "오늘의 미션") + ", \(course.title)")
                .font(.mMicro).foregroundStyle(Tokens.text3)
            Text(concept.title)
                .font(.mTitle).foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            // 커리큘럼 원문은 LaTeX 를 담고 있다. 이 자리는 WebView 를 띄울 수 없으므로
                // 인라인 수식만 유니코드로 옮겨 그린다 — 안 그러면 $-1$ 이 달러째로 나온다.
                Text(InlineMath.plain(concept.lesson?.summary ?? concept.achievementStandard ?? "개념 학습을 시작합니다."))
                .font(.mCallout).foregroundStyle(Tokens.text2)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
            missionMeta(course: course, concept: concept, preStart: preStart)
        }

        // 시작 전에는 0% 진행바를 걸지 않는다 — 빈 막대는 "지금 시작" 을
        // "아직 없음" 으로 되돌려 읽게 만든다
        if !preStart {
            ProgressBar(value: progress(in: course))
                .frame(maxWidth: 340)
        }

        // 이 화면의 유일한 주 버튼 — 솔리드 바이올렛 + 하드 엣지 (PrimaryButtonStyle).
        // 카드 전폭이 아니라 300pt 에서 멈춘다: iPad 폭에서 전폭 CTA 는
        // 버튼이 아니라 구획 배경처럼 읽힌다. 본문과 같은 leading 정렬.
        Button(preStart ? "지금 시작하기" : "이어서 풀기") { store.openConceptV2(concept.id) }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: 300, alignment: .leading)
            .accessibilityLabel("\(preStart ? "지금 시작하기" : "이어서 풀기"), \(concept.title)")
    }

    /// 전 과목 완료 — 죽은 문장 대신 다음 행동을 준다
    @ViewBuilder private var allDone: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text("이어서 학습")
                .font(.mMicro).foregroundStyle(Tokens.text3)
            Text("모든 개념을 완료했습니다")
                .font(.mTitle).foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("커리큘럼에서 복습할 개념을 고르거나 평가로 실력을 확인해 보세요.")
                .font(.mCallout).foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
        }

        Button("커리큘럼 보기") { store.route = .curriculum }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: 300, alignment: .leading)   // 주 CTA 와 같은 폭 규칙
    }

    /// 미션의 크기 한 줄 — 예상 시간과 남은 양. 크기를 먼저 보여야 시작 부담이 준다.
    private func missionMeta(course: CourseV2, concept: ConceptV2, preStart: Bool) -> some View {
        let minutes = estimatedMinutes(for: concept)
        let text: String
        if preStart {
            text = minutes.map { "예상 약 \($0)분" } ?? "오늘 첫 개념부터 시작합니다"
        } else {
            let left = "남은 개념 \(remaining(in: course))개"
            text = minutes.map { "예상 약 \($0)분, \(left)" } ?? left
        }
        return Text(text)
            .font(.mCaption).foregroundStyle(Tokens.text2)
            .monospacedDigit()
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// ②-b 바로 가기 — 퀵 연습과 학원·서비스.
///
/// 주 CTA 바로 다음 자리이되 위계는 한 단계 아래다. 카드도 색 면도 쓰지 않는다:
/// 홈의 흰 카드는 여전히 미션 히어로 하나이고, 이 줄은 히어로 아래에 붙은
/// 평문 링크 두 개다(복습 미션의 "새 개념으로 바로 가기" 와 같은 문법).
///
/// 퀵 연습이 먼저다. 쉬는 시간처럼 짧게 비는 때에 한 문항을 푸는 길이라
/// 홈의 두 번째 행동이 된다. 종전에는 평가센터 맨 아래 "빠른 연습과 도구" 에만
/// 문이 있어서, 홈에서 두 번을 더 눌러야 닿았다. 그 문은 그대로 둔다.
///
/// 관리·자료·지원·이용권을 홈에 각각 늘어놓지 않고 `학원·서비스` 한 문으로 모은다.
/// 역할에 맞지 않는 관리자 버튼이 학생 홈에 섞이지 않도록 허브가 계정 역할을 보고
/// 첫 행동을 고른다.
private struct HomeShortcutRow: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var hSize

    /// 부제까지 넣을 폭인지. 기기 이름이 아니라 사이즈 클래스로 가른다 —
    /// Split View 로 좁아지면 이름만 남고, 넓어지면 부제가 돌아온다.
    private var showsDetail: Bool {
        hSize == .regular && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        Group {
            // 접근성 글자 크기에서는 두 칸을 세로로 푼다. 한 줄에 두 개를 유지하면
            // 이름이 두 글자마다 잘리거나 축소되어 결국 못 읽는다.
            if dynamicTypeSize.isAccessibilitySize {
                stacked
            } else {
                // 같은 이유로 폭이 모자랄 때도 세로로 푼다. 판정을 사이즈 클래스에
                // 맡길 수 없다 — 이 줄은 홈이 두 칸일 때 왼쪽 칸 안에 들어가서,
                // 화면은 regular 인데 이 줄이 받는 폭은 그 절반 이하일 수 있다.
                // 실제로 320pt Slide Over 와 좁은 칸에서 이름이 "이…" 로 잘렸다.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: Tokens.Space.s3) {
                        quickPractice
                        verticalHairline
                        services
                    }
                    stacked
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 세로로 푼 모양 — 이름이 잘리느니 두 줄을 쓴다.
    private var stacked: some View {
        VStack(alignment: .leading, spacing: 0) {
            quickPractice
            horizontalHairline
            services
        }
    }

    private var quickPractice: some View {
        // 급식 줄에서 쓰라고 만든 자리다. 화면을 열고 다시 "문제 뽑기" 를 누르면
        // 두 번이 되어 그 시간이 안 나온다. 여기서는 곧바로 문항까지 간다.
        // 그래서 이름도 "퀵 연습" 이 아니라 무슨 일이 일어나는지 그대로 적는다.
        entry(title: "바로 한 문항",
              detail: "짬 나는 시간에 40초",
              icon: "bolt.fill") {
            store.quickPracticeAutoStart = true
            store.route = .quickPractice
        }
    }

    private var services: some View {
        entry(title: "학원·서비스",
              detail: "학원, 자료실, 이용권과 지원",
              icon: "square.grid.2x2.fill") {
            store.route = .services
        }
    }

    private func entry(title: String, detail: String, icon: String,
                       action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.s2) {
                Image(systemName: icon)
                    // 이름이 본문 크기로 올라간 만큼 글리프도 한 단계 올린다 —
                    // 13pt 글리프는 17pt 이름 옆에서 먼지처럼 보인다.
                    .font(.mCallout)
                    .foregroundStyle(Tokens.text2)
                    // 아이콘 칸을 20pt 로 묶는 것은 두 줄의 글자 시작점을 맞추기
                    // 위해서다. 접근성 글씨에서는 그 20pt 안에 글리프가 안 들어가
                    // 이름 첫 글자를 파고들었다(실측). 그 크기에서는 칸을 풀고
                    // 간격(8pt)에 맡긴다 — 어차피 두 항목이 세로로 풀려 있어서
                    // 시작점을 맞출 이유도 없다.
                    .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 20)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    // 13pt 캡션으로 두었더니 히어로 카드 밑의 잔글씨로 읽혀서,
                    // "상점이 구석에 있다 · 퀵 연습도 홈에서 닿게" 라는 말을 계속
                    // 들었다(실기 피드백). 본문 크기로 올린다 — 위계는 그대로다:
                    // 큰 글자(28)와 유일한 색 버튼은 여전히 히어로 몫이고,
                    // 여기는 카드도 색 면도 없는 평문 행이다.
                    Text(title)
                        .font(.mBodyB)
                        .foregroundStyle(Tokens.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if showsDetail {
                        Text(detail)
                            .font(.mMicro)
                            .foregroundStyle(Tokens.text3)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                Spacer(minLength: Tokens.Space.s2)
                Image(systemName: "chevron.right")
                    .font(.mMicro)
                    .foregroundStyle(Tokens.text3)
                    .accessibilityHidden(true)
            }
            // 평문이어도 터치 타겟은 지킨다
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        // 화면에서 부제를 접어도 음성 안내는 무엇인지 끝까지 말한다.
        .accessibilityLabel("\(title), \(detail)")
    }

    private var verticalHairline: some View {
        Rectangle().fill(Tokens.line)
            .frame(width: 1, height: 24)
            .accessibilityHidden(true)
    }

    private var horizontalHairline: some View {
        Rectangle().fill(Tokens.line)
            .frame(height: 0.5)
            .accessibilityHidden(true)
    }
}

/// 홈 알림 칸에 실리는 소식 한 건. 서버가 보낸 제목과 본문을 그대로 담는다.
private struct HomeNotice: Identifiable {
    let id: String
    let title: String
    let message: String
}

/// ②-c 알림 칸 — 문제집·모의고사 팩 안내를 거는 자리.
///
/// **앱은 문구를 만들지 않는다.** 서버가 보낸 제목과 본문을 그대로 싣기만 한다.
/// 실을 소식이 없으면 홈이 이 뷰를 아예 부르지 않는다(빈 상자 금지).
/// 개수 제한도 두지 않는다 — 몇 건을 걸지는 보내는 쪽이 정한다.
///
/// 여는 문(자세히 보기)과 닫는 문(그만 보기)은 아직 없다. 소식이 어디로 가야 하는지,
/// 한 번 닫으면 언제까지 안 보여야 하는지는 서버가 알려 줘야 하는 값이고,
/// 앱이 임의로 목적지를 정하면 안내가 아니라 유도가 된다.
/// 표시 문법은 카드가 아니라 괘선 섹션이다 — 홈의 흰 카드는 미션 히어로 하나다.
private struct HomeNoticeBoard: View {
    let notices: [HomeNotice]

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            SectionRule(title: "알림")

            ForEach(notices) { notice in
                VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                    Text(notice.title)
                        .font(.mBodyB)
                        .foregroundStyle(Tokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(notice.message)
                        .font(.mCallout)
                        .foregroundStyle(Tokens.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// ③-a 이번 주 학습 — 괘선 섹션 + 핵심 3지표 + 주간 차트.
///
/// 예전 6칸 동일 그리드는 지표끼리 서열이 없어 아무것도 안 읽혔다.
/// 학습시간·학습한 날·정답률 셋만 남기고 나머지는 각 목적지 화면이 맡는다.
/// 카드 chrome 은 벗겼다 — 통계는 행동 위계가 필요 없는 받침 정보라
/// 시험지 괘선 문법(섹션 제목 + 선)의 평면 섹션으로 내려가고,
/// 홈의 흰 카드는 미션 히어로 하나만 남는다.
/// 로그인 만료 안내는 여기 없다 — 화면 상단의 SyncPausedBanner 가 맡는다.
///
/// 데이터 출처 상태는 헤더 오른쪽 끝에 있었다. 거기서 주황색 아이콘 + 두 줄짜리
/// 문구가 정답률 칸 바로 위에 얹혀, 이 섹션에서 제일 눈에 띄는 요소가 실패 안내가
/// 됐다(실기 캡처에서 사용자가 직접 표시한 지점). 이제 sourceNote 로 통계 **아래**
/// 조용한 한 줄이고, 잘 돌아가는 상태는 아예 그리지 않는다.
private struct WeeklyStudySection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var vSize

    let activity: ServerAPI.DashboardActivity
    let source: DashboardActivitySource
    /// .failed/.offline 의 "다시 시도" — 홈 화면의 기존 재조회를 그대로 트리거한다
    let onRetry: () -> Void

    /// 요일별 학습 시간이 하나도 없으면 0 높이 막대 일곱 개를 그리지 않는다.
    /// 문제 풀이 건수와 시간 집계는 서로 다른 신호이므로, 풀이가 있어도 모든
    /// minute 값이 0이면 시간 차트 대신 상태 문장을 보여 준다.
    private var hasChartData: Bool {
        activity.weeklyActivity.days.contains { $0.minutes > 0 }
    }

    /// 이번 주에 기록이 하나라도 있는지 — 학습시간·풀이·학습일 중 아무거나.
    /// 셋 다 0이면 3지표는 "0분 / 0/7일 / —" 세 칸에 예고 문장까지 붙여
    /// 화면의 3분의 1을 쓰면서 정보량은 0이다. 정보가 없으면 자리도 주지 않는다:
    /// 그럴 때는 한 줄 안내로 접고, 기록이 생기는 순간 원래 3지표로 돌아온다.
    private var hasWeeklyRecord: Bool {
        let stats = activity.stats
        return stats.weeklyStudyMinutes > 0
            || stats.weeklySolvedProblems > 0
            || stats.activeStudyDays > 0
    }

    var body: some View {
        // 세로가 짧으면(가로 iPhone) 제목·지표·차트·각주 사이 20pt 가 최대 세 번 들어가
        // 60pt 를 먹는다. 막대 트랙을 낮추는 것(WeeklyActivityChart.trackHeight)과 같은 축이다.
        VStack(alignment: .leading, spacing: vSize == .compact ? Tokens.Space.s3 : Tokens.Space.s5) {
            header
            if hasWeeklyRecord {
                statRow
                if hasChartData {
                    WeeklyActivityChart(activity: activity.weeklyActivity)
                } else {
                    chartForecast
                }
            } else {
                emptyWeekLine
            }
            sourceNote
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 제목 + 괘선. 오른쪽 끝은 비워 둔다 — 여기 얹혀 있던 출처 상태가
    /// 정답률 칸 위에서 주황색으로 충돌해 읽혔다. 출처는 sourceNote 로 내려갔다.
    private var header: some View {
        SectionRule(title: "이번 주 학습")
    }

    /// 이번 주 기록 0건 — 0분/0-7일/— 세 칸 대신 한 줄. 시작 CTA 는 위 히어로 몫이라
    /// 여기서는 앞으로 무엇이 이 자리에 쌓이는지만 말한다.
    private var emptyWeekLine: some View {
        Text("이번 주 기록은 아직 없어요. 학습을 시작하면 학습시간, 학습한 날, 정답률이 여기에 쌓입니다.")
            .font(.mCallout)
            .foregroundStyle(Tokens.text3)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// 출처 각주 — 통계 **아래** 조용한 한 줄이다.
    ///
    /// 정상(.server)·동기화 중(.syncing)·로컬 기본값(.local)은 아무것도 그리지 않는다:
    /// 잘 돌아간다고 알리는 배지는 정보가 아니고, 그 자리는 통계가 쓴다.
    /// 만료(.expired)도 여기서는 침묵한다 — 안내와 출구("다시 로그인")를
    /// 화면 상단 SyncPausedBanner 가 이미 갖고 있어 같은 말 두 번이 된다.
    ///
    /// 저하 상태만 남기되 경고색(warning/danger)은 쓰지 않는다 — 실패 안내가
    /// 내용보다 눈에 띄면 안 된다. 위계는 stat detail 과 같은 mMicro·text3 이고,
    /// 색으로 세우지 않는 대신 자리(맨 아래)와 순서로만 말한다.
    /// 다만 .failed/.offline 의 "다시 시도" 는 그대로 남긴다 —
    /// 문제만 말하고 출구를 안 주면 안 된다(1116·0373).
    /// .unsupported(404)는 재시도해도 같은 404라 행동을 붙이지 않는다.
    @ViewBuilder private var sourceNote: some View {
        switch source {
        case .local, .syncing, .server, .expired:
            EmptyView()
        case .unsupported:
            noteText(source.message)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .failed, .offline:
            noteAction(source.message, actionTitle: "다시 시도", action: onRetry)
        }
    }

    private func noteText(_ message: String) -> some View {
        Text(message)
            .font(.mMicro)
            .foregroundStyle(Tokens.text3)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// 각주 + 출구 한 줄 — 넓으면 한 줄, 좁거나 접근성 글씨면 두 줄로 푼다.
    private func noteAction(_ message: String, actionTitle: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                        noteText(message)
                        noteActionLabel(actionTitle)
                    }
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s2) {
                            noteText(message)
                            noteActionLabel(actionTitle)
                        }
                        VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                            noteText(message)
                            noteActionLabel(actionTitle)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 44)              // 최소 터치 타겟 (1261)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message) \(actionTitle)")
    }

    /// 출구 레이블 — 각주 본문(text3)보다 한 단계만 진하게(text2). 여기까지가
    /// 이 줄에 허용된 강조 전부다: 색 강조는 주 CTA 하나가 독점한다.
    private func noteActionLabel(_ title: String) -> some View {
        HStack(spacing: 2) {
            Text(title)
                .font(.mMicro)
                .foregroundStyle(Tokens.text2)
            Image(systemName: "chevron.right")
                .font(.mMicro)
                .foregroundStyle(Tokens.text3)
                .accessibilityHidden(true)
        }
    }

    /// 3지표 한 줄이 서는 최소 폭. 이 값 **이상이면 언제나** 한 줄 세 칸이고, 미만이면 세로다.
    ///
    /// 왜 고정 폭인가. ViewThatFits 는 후보의 **이상 폭**(글줄을 안 접었을 때 폭)으로
    /// 들어가는지 재는데, 이 줄의 이상 폭은 값 문자열이 정한다 — "6분" 은 짧고
    /// "5시간 22분" 은 길다. 그래서 같은 340pt 칸에서 로컬 집계(긴 문자열)는 세로로,
    /// 서버 집계(짧은 문자열)는 가로로 판정돼, 실행 직후 로컬 → 서버로 값이 바뀌는
    /// 순간 세로 스택이 가로 세 칸으로 통째로 다시 배치됐다(실기 iPad Pro 11" 보고).
    /// 판정 축을 문자열에서 **칸의 폭**으로 옮긴다: 폭이 있으면 값이 길어도 세 칸이고,
    /// 긴 값은 칸 안에서 축소한다(stat 참조). 두 칸 홈의 기록 칸(340)과 아이폰 세로는
    /// 통과하고, 320pt Slide Over(본문 288)는 세로로 남는다 — 종전 의도 그대로다.
    /// 큰 글씨에서는 같은 폭에 세 칸이 안 서므로 캡션 배율을 따라 커진다.
    @ScaledMetric(relativeTo: .caption2) private var statRowMinWidth: CGFloat = 320

    /// 3지표 — 넓으면 한 줄 세 칸, 좁으면(320pt·접근성 글씨) 세로로 푼다.
    private var statRow: some View {
        let stats = activity.stats
        // 이번 주 풀이가 0건이면 정답률은 "0%(전부 틀림)" 가 아니라 측정값 없음이다 (1380).
        let noSolves = stats.weeklySolvedProblems == 0
        let rateValue = noSolves ? "—" : "\(stats.correctRate)%"
        let rateDetail = noSolves ? "이번 주 풀이 기록 없음" : stats.correctRateDetail
        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    stat("이번 주 학습시간", Self.formatStudyTime(stats.weeklyStudyMinutes),
                         detail: stats.weeklyStudyDetail)
                    stat("학습한 날", "\(stats.activeStudyDays)/7일", detail: "최근 7일 중")
                    stat("정답률", rateValue, detail: rateDetail)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: Tokens.Space.s4) {
                        stat("이번 주 학습시간", Self.formatStudyTime(stats.weeklyStudyMinutes),
                             detail: stats.weeklyStudyDetail)
                        statDivider
                        stat("학습한 날", "\(stats.activeStudyDays)/7일", detail: "최근 7일 중")
                        statDivider
                        stat("정답률", rateValue, detail: rateDetail)
                    }
                    // 후보의 이상 폭을 statRowMinWidth 로 못박는다 — 홈의 두 칸 판정
                    // (twoColumnMinWidth)과 같은 수법이다. 이게 없으면 ViewThatFits 가
                    // 값 문자열의 길이로 재서 데이터가 바뀔 때마다 세로↔가로가 뒤집힌다.
                    .frame(minWidth: statRowMinWidth, idealWidth: statRowMinWidth,
                           maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                        stat("이번 주 학습시간", Self.formatStudyTime(stats.weeklyStudyMinutes),
                             detail: stats.weeklyStudyDetail)
                        stat("학습한 날", "\(stats.activeStudyDays)/7일", detail: "최근 7일 중")
                        stat("정답률", rateValue, detail: rateDetail)
                    }
                }
            }
        }
    }

    private func stat(_ title: String, _ value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            // 제목과 값은 한 줄을 지킨다. 세 칸 판정이 폭으로 고정된 뒤로는 긴 값
            // ("5시간 22분")이 칸을 넘칠 수 있는데, 접혀서 두 줄이 되면 값에 따라
            // 줄 높이가 달라져 아래 차트가 오르내린다. 접는 대신 축소해 기하를 지킨다 —
            // 값 22pt 의 0.6 배(13pt)까지면 "12시간 45분" 도 85pt 칸에 들어간다.
            Text(title).font(.mMicro).foregroundStyle(Tokens.text3)
                .lineLimit(1).minimumScaleFactor(0.8)
            Text(value).font(.mStat).foregroundStyle(Tokens.ink).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
            // detail 은 장식이 아니라 데이터(증감 추이)다 — text4 는 대비 미달 (0409·0410)
            // 빈 문구는 줄 자체를 접는다 — 이번 주 0 인 지표에 감소 강조를
            // 붙이지 않는 EventLog 의 판정(RG-04)과 같은 축이다.
            if !detail.isEmpty {
                Text(detail).font(.mMicro).foregroundStyle(Tokens.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(statAccessibilityLabel(title: title, value: value, detail: detail))
    }

    /// "—" 는 음성으로 읽히지 않는다 — 측정 없음은 말로 풀어 주고,
    /// 접힌 delta 줄(빈 문구)은 음성에서도 읽지 않는다.
    private func statAccessibilityLabel(title: String, value: String, detail: String) -> String {
        let base = value == "—" ? title : "\(title) \(value)"
        return detail.isEmpty ? base : "\(base), \(detail)"
    }

    private var statDivider: some View {
        Rectangle().fill(Tokens.line)
            .frame(width: 1, height: 44)
            .accessibilityHidden(true)
    }

    /// 빈 상태 — 골격 막대를 그리지 않는다: 희미한 가짜 막대는 잠깐이라도 기록처럼
    /// 읽힌다. 무엇이 올지 한 줄로 예고만 한다. 시작 CTA 는 바로 위 히어로 몫이다.
    private var chartForecast: some View {
        Text(activity.stats.weeklySolvedProblems > 0
             ? "이번 주 \(activity.stats.weeklySolvedProblems)문제를 풀었어요. 학습 시간이 기록되면 요일별 패턴을 보여드려요."
             : "3일 학습하면 주간 패턴을 분석해 드려요")
            .font(.mCallout)
            .foregroundStyle(Tokens.text3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private static func formatStudyTime(_ minutes: Int) -> String {
        let safeMinutes = max(0, minutes)
        let hours = safeMinutes / 60
        let remaining = safeMinutes % 60
        if hours == 0 { return "\(remaining)분" }
        if remaining == 0 { return "\(hours)시간" }
        return "\(hours)시간 \(remaining)분"
    }
}

/// ③-b GOAT Arena 예고 — 이 화면의 유일한 네이비 면.
///
/// 네이비 위 강조색은 시안 하나만 쓴다(네이비 위 마젠타·바이올렛 금지).
/// 다크 모드에서는 페이지 바탕(paper)이 네이비와 같은 색이라 카드 경계는
/// 테두리 선이 세운다.
///
/// "입장" 알약은 걷어냈다. 이 카드는 같은 말을 세 번 했다 — 머리글 "GOAT Arena
/// 입장", 큰 글자 "GOAT ARENA", 그리고 알약 "입장". 홈에 바로 가기 줄이 새로
/// 들어오는 만큼 여기서 한 덩어리를 덜어낸다: 알약이 차지하던 44pt 는 좁은 폭에서
/// 그대로 세로 길이였다. 누를 수 있다는 신호는 머리글 옆 화살표와 누를 때
/// 눌리는 동작(PressScaleStyle)이 이어받고, 음성 안내 문구는 그대로다.
private struct ArenaTeaserCard: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.verticalSizeClass) private var vSize

    let tierState: HomeArenaTierState

    private var onNavy: Color { Tokens.onNavy }
    private var tierName: String {
        switch tierState {
        case .unknown:
            return "티어 확인 전"
        case .placementPending:
            return "배치 전"
        case let .tier(tierCode):
            return RankTier(serverCode: tierCode)?.label ?? "티어 확인 중"
        }
    }

    var body: some View {
        Button {
            store.route = .rank
        } label: {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: Tokens.Space.s6) {
                    titleBlock
                    Spacer(minLength: Tokens.Space.s4)
                    tierBlock
                        .fixedSize(horizontal: true, vertical: false)
                }

                VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                    titleBlock
                    tierBlock
                }
            }
            // 세로가 짧으면 안여백을 한 단계 줄인다 — 미션 히어로(MissionHeroCard.short)와
            // 같은 규칙이다. 홈에서 제일 큰 두 덩어리만 이 규칙을 갖는다.
            .padding(vSize == .compact ? Tokens.Space.s4 : Tokens.Space.s6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ArenaArtworkBackground(
                    imageName: "ArenaHeroBackdrop",
                    focalAlignment: .trailing,
                    darkening: 0.18)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.xl))
            }
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.xl)
                    .strokeBorder(Tokens.brandCyan.opacity(0.28), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.xl))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(
            "GOAT Arena. 현재 티어 \(tierName). 매일 출석으로 내 자리를 지키는 30일 서바이벌. GOAT Arena 열기")
    }

    /// 맵 화면과 같은 라운디드 헤비 — 큰 제목의 장난기는 서체로만 낸다
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            HStack(spacing: Tokens.Space.s2) {
                Label("GOAT Arena 입장", systemImage: "crown.fill")
                Image(systemName: "chevron.right")
            }
            .font(.mMicro)
            .foregroundStyle(Tokens.brandCyan)
            Text("GOAT ARENA")
                .font(.mTitle)
                .fontDesign(.rounded)
                .foregroundStyle(onNavy)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("매일 출석으로 내 자리를 지키는 30일 서바이벌")
                .font(.mCallout)
                .foregroundStyle(onNavy.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 계정별 Arena 캐시에 들어 있는 서버 tier/status만 보여 준다.
    /// 캐시가 없거나 만료된 것과 서버가 명시한 배치 대기를 구분한다.
    /// MMR이나 자리 번호로 티어를 추정하지 않는다.
    private var tierBlock: some View {
        HStack(spacing: Tokens.Space.s2) {
            switch tierState {
            case .unknown:
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(onNavy.opacity(0.72))
                    // 휘장(RankBadgeView)과 **같은 58pt** 다. 82 였을 때는 티어를 모르는
                    // 상태의 카드만 24pt 더 높았고, 캐시가 빈 계정에서 서버 응답이 오는
                    // 순간 82→58 로 카드가 한 번 뛰었다(홈 cachedArenaTierState 주석의
                    // 그 튐이 남아 있던 자리). 세로 공간도 24pt 돌려받는다.
                    .frame(width: 58, height: 58)
            case .placementPending:
                RankBadgeView(tierCode: nil, size: 58, animated: true)
            case let .tier(tierCode):
                RankBadgeView(tierCode: tierCode, size: 58, animated: true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("현재 티어")
                    .font(.mMicro)
                    .foregroundStyle(onNavy.opacity(0.65))
                Text(tierName)
                    .font(.mBodyB)
                    .foregroundStyle(onNavy)
                    .lineLimit(1)
            }
        }
        .accessibilityHidden(true) // 카드 전체 라벨에서 한 번만 읽는다
    }
}

private struct WeeklyActivityChart: View {
    let activity: ServerAPI.DashboardActivity.WeeklyActivity

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var vSize

    private var days: [ServerAPI.DashboardActivity.WeeklyActivity.Day] {
        var result = Array(activity.days.prefix(7))
        let fallbackLabels = EventLog.recentDayLabels()
        while result.count < 7 {
            let index = result.count
            result.append(.init(
                dateKey: "missing-\(index)",
                label: fallbackLabels.indices.contains(index) ? fallbackLabels[index] : "—",
                minutes: 0,
                isToday: index == 6))
        }
        return result
    }

    private var maximum: Int {
        max(1, activity.maxMinutes, days.map(\.minutes).max() ?? 0)
    }

    /// 받침 카드로 내려오면서 더 촘촘하게 — 116→88 (접근성 글씨는 150→128)
    ///
    /// 접근성 글씨는 폭도 높이도 보지 않고 128 을 지킨다. 큰 글씨를 쓰는 이유가
    /// 화면이 넓어서가 아니기 때문이다.
    /// 그 밖에 세로가 짧으면(가로 iPhone) 막대 트랙만 낮춘다. 요일 7칸과 분 라벨은
    /// 그대로 남고 비율도 maximum 기준 그대로라, 읽는 방법이 달라지지 않는다.
    private var trackHeight: CGFloat {
        if dynamicTypeSize.isAccessibilitySize { return 128 }
        return vSize == .compact ? 64 : 88
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            HStack(spacing: Tokens.Space.s2) {
                Circle()
                    .fill(Tokens.primary)
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)
                Text("학습 시간")
                    .font(.mMicro)
                    .foregroundStyle(Tokens.text3)
            }

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    chartDay(day, index: index)
                }
            }
            // 7개 축을 한 줄로 유지하는 시각화라 접근성 배율을 그대로 적용하면
            // 서로 겹친다. 각 막대의 전체 값은 아래 accessibilityLabel로 제공한다.
            .dynamicTypeSize(.large)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("요일별 학습 시간")
    }

    private func chartDay(
        _ day: ServerAPI.DashboardActivity.WeeklyActivity.Day,
        index: Int
    ) -> some View {
        let minutes = max(0, day.minutes)
        let ratio = minutes == 0
            ? 0
            : max(0.07, min(1, Double(minutes) / Double(maximum)))

        return VStack(spacing: Tokens.Space.s2) {
            // 접근성 글씨 크기에서도 7열을 유지하려면 단위는 범례·VoiceOver에 맡기고
            // 숫자만 표시한다. 일반 크기에서는 웹과 같은 "42분" 표기다.
            Text(dynamicTypeSize.isAccessibilitySize ? "\(minutes)" : "\(minutes)분")
                .font(.mMicro)
                .foregroundStyle(Tokens.text3)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            ZStack(alignment: .bottom) {
                chartGrid

                if ratio > 0 {
                    // 단일 시리즈(학습 시간)는 단색이다 — 요일별 브랜드 색 로테이션은
                    // 카테고리 차이처럼 오독되고 범례 점(primary)과도 어긋난다 (0401·0415).
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Tokens.primary)
                        .frame(maxWidth: 28)
                        .frame(height: trackHeight * ratio)
                }
            }
            .frame(height: trackHeight)

            Text(day.label)
                .font(.mCaption)
                .foregroundStyle(day.isToday ? Tokens.ink : Tokens.text3)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(day.label), \(minutes)분\(day.isToday ? ", 오늘" : "")")
    }

    private var chartGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { index in
                Rectangle()
                    .fill(index == 3 ? Tokens.lineStrong : Tokens.line)
                    .frame(height: index == 3 ? 1 : 0.5)
                if index < 3 { Spacer(minLength: 0) }
            }
        }
        .accessibilityHidden(true)
    }

}

#if DEBUG
/// 알림 칸 레이아웃 검수용. 실행 인자 `-homeNoticeFixture` 를 줄 때만 나타나고
/// Release 빌드에는 아예 컴파일되지 않는다.
///
/// 문구는 일부러 상품 홍보가 아니다. 여기 들어갈 진짜 문구는 서버가 보내는 것이고,
/// 그 전에 그럴듯한 홍보 문안을 심어 두면 스크린샷에서 "이미 되는 기능" 으로 읽힌다.
/// 이 픽스처가 확인해 주는 것은 문구가 아니라 자리다(줄바꿈·간격·좁은 폭).
private enum HomeNoticeFixture {
    static var current: [HomeNotice]? {
        guard ProcessInfo.processInfo.arguments.contains("-homeNoticeFixture") else { return nil }
        return [
            HomeNotice(
                id: "layout-check",
                title: "안내가 실리는 자리",
                message: "서버가 보낸 안내가 있을 때만 이 칸이 나타납니다. 보낼 안내가 없으면 칸 자체를 그리지 않습니다."),
        ]
    }
}

private enum DashboardFixture {
    static var current: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-dashboardFixture"),
              arguments.indices.contains(index + 1) else { return nil }
        let value = arguments[index + 1].lowercased()
        return ["active", "zero", "failure"].contains(value) ? value : nil
    }

    static let active = ServerAPI.DashboardActivity(
        generatedAt: "2026-07-30T09:30:00.000Z",
        stats: .init(
            weeklyStudyMinutes: 315,
            weeklyStudyDetail: "지난주보다 85분 늘었어요",
            todayStudyMinutes: 42,
            activeStudyDays: 5,
            averageStudyMinutes: 63,
            weeklySolvedProblems: 128,
            weeklySolvedDetail: "개념과 복습 문제",
            correctRate: 84,
            correctRateDetail: "지난주보다 6% 늘었어요"),
        weeklyActivity: .init(
            days: zip(
                ["금", "토", "일", "월", "화", "수", "오늘"],
                [24, 0, 58, 75, 46, 70, 42]
            ).enumerated().map { index, value in
                .init(
                    dateKey: "fixture-\(index)",
                    label: value.0,
                    minutes: value.1,
                    isToday: index == 6)
            },
            maxMinutes: 75))

    static let zero = ServerAPI.DashboardActivity(
        generatedAt: "2026-07-30T09:30:00.000Z",
        stats: .init(
            weeklyStudyMinutes: 0,
            weeklyStudyDetail: "지난주와 같아요",
            todayStudyMinutes: 0,
            activeStudyDays: 0,
            averageStudyMinutes: 0,
            weeklySolvedProblems: 0,
            weeklySolvedDetail: "개념과 복습 문제",
            correctRate: 0,
            correctRateDetail: "지난주와 같아요"),
        weeklyActivity: .init(
            days: ["금", "토", "일", "월", "화", "수", "오늘"].enumerated().map {
                .init(
                    dateKey: "fixture-\($0.offset)",
                    label: $0.element,
                    minutes: 0,
                    isToday: $0.offset == 6)
            },
            maxMinutes: 10))
}
#endif
