//  AuthScreen.swift
//  Matths
//
//  로그인 — Sign in with Apple / 서버 Google OAuth / 이메일 / 게스트 모드.
//
//  브랜드 버튼 규정을 지킨다:
//   카카오 = #FEE500 바탕 + 검정 텍스트,  Google = 흰 바탕 + 테두리 + G 마크,
//   Apple = 검정 바탕 + 흰 로고(다크에서는 반대). 애플 HIG 는 이 버튼을 다른
//   소셜 버튼보다 **위 또는 동등한** 자리에 두라고 요구해서 Google 위에 있다.

import AuthenticationServices
import SwiftUI

struct AuthScreen: View {
    @EnvironmentObject private var store: AppStore
    @State private var showEmailAuth = false
    @StateObject private var googleSignIn = GoogleSignInCoordinator()
    @State private var googleBusy = false
    @State private var googleError: String?
    @State private var googleAttemptID: UUID?
    /// 코디네이터의 브라우저/시스템 시트뿐 아니라 그 전에 도는 provider 조회까지
    /// 취소해야 한다. Task를 소유하지 않으면 이메일 폼으로 넘어간 뒤 늦은 조회가
    /// 끝나면서 예전 소셜 인증창이 새 화면 위에 다시 뜰 수 있다.
    @State private var googleTask: Task<Void, Never>?
    // 애플 경로는 Google 과 **같은 파이프**를 탄다. 상태 변수도 1:1로 둔다 —
    // 두 로그인이 하나의 busy/attempt 를 공유하면 늦게 온 응답이 다른 쪽 로그인을
    // 덮는다(ServerAPI.beginAuthenticationAttempt 가 막으려는 바로 그 사고).
    @StateObject private var appleSignIn = AppleSignInCoordinator()
    @State private var appleBusy = false
    @State private var appleError: String?
    @State private var appleAttemptID: UUID?
    @State private var appleTask: Task<Void, Never>?
    /// 서버가 애플 교환 경로를 켰는가. **기본값 false** — 조회 전과 조회 실패는
    /// 모두 "모른다"이고, 모를 때는 그리지 않는다(refreshAppleAvailability 주석).
    @State private var appleAvailable = false
    // 카카오는 공식 SDK 인증 후 서버의 일회용 grant와 PKCE 교환을 거친다.
    // 가입 정보가 필요한 계정은 같은 인증 시도를 유지한 네이티브 폼으로 이어진다.
    @StateObject private var kakaoSignIn = KakaoSignInCoordinator()
    @State private var kakaoBusy = false
    @State private var kakaoError: String?
    @State private var kakaoAttemptID: UUID?
    @State private var kakaoTask: Task<Void, Never>?
    /// 서버가 카카오를 켰는가. 애플과 같은 이유로 **기본값 false** 다 —
    /// 눌러도 안 되는 버튼을 먼저 보여주면 학생은 자기 계정 문제로 읽는다.
    @State private var kakaoAvailable = false
    private struct NativeRegistrationPresentation: Identifiable {
        let context: NativeSocialRegistrationContext
        let attemptID: UUID
        let provider: String
        var id: UUID { context.id }
    }
    @State private var nativeRegistration: NativeRegistrationPresentation?
    #if DEBUG
    @State private var didPresentNativeRegistrationCapture = false
    #endif
    /// 애플 버튼 색은 라이트/다크가 반전된다(HIG). 토큰이 아니라 순수 흑백이라
    /// 색 결정을 위해 외관을 직접 읽는다.
    @Environment(\.colorScheme) private var colorScheme
    /// 기기 이름이 아니라 사이즈 클래스로 판정한다. iPhone 가로뿐 아니라
    /// Split View, Stage Manager 로 좁아진 iPad 창도 여기에 들어온다.
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// 세로가 짧은 창 — iPhone 가로는 가용 높이가 약 390pt 밖에 없다.
    /// 락업과 여백을 줄여 로그인 수단이 접히지 않게 한다.
    private var compactHeight: Bool { verticalSizeClass == .compact }

    /// 인증창은 한 번에 하나만 존재해야 한다. 각 수단이 자기 busy만 보면 provider
    /// 사전 조회가 느린 순간 다른 버튼을 연타해 시스템 시트 두 개가 순서대로 뜬다.
    private var socialAuthenticationBusy: Bool {
        googleBusy || appleBusy || kakaoBusy
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                AuthLandingLayout(viewportHeight: geo.size.height, compact: compactHeight) {
                    brandLockup
                    signInActions
                }
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.paper)
        // iPhone 가로에서 page sheet의 드래그 제스처가 가입 폼 ScrollView를
        // 가로채면 학교·약관·가입 버튼에 도달할 수 없다. 인증은 독립 전체 화면이다.
        .fullScreenCover(isPresented: $showEmailAuth) { EmailAuthSheet() }
        .fullScreenCover(item: $nativeRegistration) { presentation in
            NativeSocialRegistrationScreen(context: presentation.context) { auth in
                completeNativeRegistration(auth, presentation: presentation)
            } onCancel: {
                guard nativeRegistration?.id == presentation.id else { return }
                if presentation.provider == "apple" { cancelAppleSignIn() }
                else { cancelKakaoSignIn() }
            }
        }
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-authSheetCapture") {
                showEmailAuth = true
            }
            if ProcessInfo.processInfo.arguments.contains("-nativeRegistrationCapture"), !didPresentNativeRegistrationCapture {
                didPresentNativeRegistrationCapture = true
                let attemptID = ServerAPI.beginAuthenticationAttempt()
                let provider = ProcessInfo.processInfo.arguments.contains("-nativeRegistrationKakao") ? "kakao" : "apple"
                let info = ServerAPI.NativeSocialRegistrationInfo(
                    token: "capture-only-not-a-server-ticket", provider: provider,
                    expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(
                        ProcessInfo.processInfo.arguments.contains("-nativeRegistrationExpired") ? -60 : 1800)),
                    email: "sample@example.invalid", suggestedRealName: nil,
                    termsVersion: "2026-08-13", privacyVersion: "2026-08-13")
                if provider == "apple" { appleAttemptID = attemptID; appleBusy = true }
                else { kakaoAttemptID = attemptID; kakaoBusy = true }
                nativeRegistration = .init(context: .init(registration: info, codeVerifier: "capture-only"),
                                           attemptID: attemptID, provider: provider)
            }
            #endif
        }
        .onDisappear { cancelGoogleSignIn() }
        // 기존 Google 웹 인증의 종료 처리는 유지한다. Apple·카카오의
        // 네이티브 인증 화면 전환은 아래 정책으로 별도 처리한다.
        // Apple 시스템 시트와 카카오톡 앱 전환은 AuthScreen을
        // 잠시 disappear 상태로 만들 수 있다. busy 중에 여기서
        // 취소하면 정상 자격 증명 콜백을 스스로 폐기하고,
        // 취소 오류를 무문구 처리하므로 로그인 화면에 그대로 남는다.
        // 이메일 폼·다른 provider 선택은 이미 버튼 시점에 명시적으로
        // cancel하므로, 여기서는 idle 상태의 진짜 teardown만 정리한다.
        .onDisappear {
            if NativeAuthenticationPresentationPolicy.shouldCancelOnAuthScreenDisappear(
                isBusy: appleBusy,
                sessionPublished: store.authProvider != nil
            ) {
                cancelAppleSignIn()
            }
        }
        .onDisappear {
            if NativeAuthenticationPresentationPolicy.shouldCancelOnAuthScreenDisappear(
                isBusy: kakaoBusy,
                sessionPublished: store.authProvider != nil
            ) {
                cancelKakaoSignIn()
            }
        }
        // 버튼을 그릴지 말지는 서버가 정한다. .task 는 진입에서 한 번 돌고
        // 화면을 벗어나면 스스로 취소된다.
        .task { await refreshSocialAvailability() }
    }

    // 인증 면은 CI Primary Identity 전체 락업을 원본 그대로 쓴다.
    // 좁은 세로에서는 같은 원본을 비율 그대로 줄여 쓴다(재조합 금지).
    // 다크에서 워드마크가 배경과 같은 검정이라 사라지던 문제는 에셋 카탈로그의
    // 다크 외관 변형으로 고쳤다 — 여기서 색을 덧칠하지 않는다(BrandMark.swift 주석).
    private var brandLockup: some View {
        VStack(spacing: compactHeight ? Tokens.Space.s1 : Tokens.Space.s5) {
            PrimaryBrandIdentity()
                .frame(width: compactHeight ? 116 : 180,
                       height: compactHeight ? 36 : 56)
                .accessibilityIdentifier("auth.brand.identity")
            Text("풀이 과정까지 채점하는 수학").font(.mCallout)
                .foregroundStyle(Tokens.text3)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Tokens.Space.s6)
    }

    private var signInActions: some View {
        VStack(spacing: compactHeight ? Tokens.Space.s1 : Tokens.Space.s3) {
            // 운영 서버의 provider 설정을 확인한 뒤 Apple 버튼을 표시한다.
            // 네이티브 자격 증명은 /api/v1/auth/apple/exchange에서 검증한다.
            // configured는 실제 계정 인증의 성공까지 보장하는 값은 아니다.
            if appleAvailable {
                Button { startAppleSignIn() } label: {
                    HStack(spacing: Tokens.Space.s2) {
                        // 애플 로고는 규정 심볼이다. 직접 그린 도형이나 텍스트 대체는
                        // HIG 위반이라 SF Symbol 을 쓴다.
                        Image(systemName: "apple.logo")
                            .font(.system(size: 17, weight: .medium))
                            .accessibilityHidden(true)
                        Text(appleBusy ? "Apple 확인 중…" : "Apple로 계속하기")
                            .font(.mBodyB)
                    }
                    // 크기·모서리는 Google 버튼과 같다. 두 버튼의 높이가 다르면
                    // 어느 쪽이 "진짜 로그인" 인지로 읽혀서 선택이 편향된다.
                    .foregroundStyle(appleForeground)
                    .frame(maxWidth: .infinity, minHeight: signInButtonHeight)
                    .background(appleBackground,
                                in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                }
                .disabled(socialAuthenticationBusy)
                .accessibilityLabel(appleBusy ? "Apple 로그인 확인 중" : "Apple로 계속하기")
            }

            // 카카오. 브랜드 규정상 #FEE500 바탕 + 검정 글자가 고정이라 토큰을
            // 쓰지 않는다(다크 모드에서도 같다). 애플 버튼 아래, 구글 위 —
            // 국내 사용자가 가장 먼저 찾는 수단이라 소셜 중에서는 앞에 둔다.
            if kakaoAvailable {
                Button { startKakaoSignIn() } label: {
                    HStack(spacing: Tokens.Space.s2) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 15, weight: .bold))
                            .accessibilityHidden(true)
                        Text(kakaoBusy ? "카카오 확인 중…" : "카카오로 계속하기")
                            .font(.mBodyB)
                    }
                    .foregroundStyle(Color(hex: 0x191600))
                    .frame(maxWidth: .infinity, minHeight: signInButtonHeight)
                    .background(Color(hex: 0xFEE500),
                                in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                }
                .disabled(socialAuthenticationBusy)
                .accessibilityLabel(kakaoBusy ? "카카오 로그인 확인 중" : "카카오로 계속하기")
            }

            Button { startGoogleSignIn() } label: {
                HStack(spacing: Tokens.Space.s2) {
                    Image("GoogleGMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .accessibilityHidden(true)
                    Text(googleBusy ? "Google 확인 중…" : "Google로 계속하기")
                        .font(.mBodyB).foregroundStyle(Tokens.text1)
                }
                .frame(maxWidth: .infinity, minHeight: signInButtonHeight)
                .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.md)
                    .strokeBorder(Tokens.lineStrong, lineWidth: 1.2))
            }
            .disabled(socialAuthenticationBusy)
            .accessibilityLabel(googleBusy ? "Google 로그인 확인 중" : "Google로 계속하기")

            // 오류 슬롯은 하나다. 로그인 수단마다 줄을 따로 두면 화면이 길어지고,
            // 어차피 한 번에 한 수단만 진행한다.
            if let authenticationMessage = googleError ?? appleError ?? kakaoError ?? store.authenticationNotice {
                Text(authenticationMessage).font(.mCaption).foregroundStyle(Tokens.dangerInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 이메일 계정 — 서버(MongoDB) 실가입. 진도가 계정에 동기화된다
            Button {
                cancelGoogleSignIn()
                cancelAppleSignIn()
                cancelKakaoSignIn()
                store.clearAuthenticationNotice()
                showEmailAuth = true
            } label: {
                HStack(spacing: Tokens.Space.s2) {
                    Image(systemName: "envelope.fill").font(.system(size: 15))
                    Text("이메일로 가입 또는 로그인").font(.mBodyB)
                }
                .foregroundStyle(Tokens.onBrand)
                .frame(maxWidth: .infinity, minHeight: signInButtonHeight)
                .background(Tokens.actionPrimary, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
            }

            // 로그인할 수 없는 사용자와 App Review도 계정을 만들기 전에 정책·지원
            // 문서를 확인할 수 있어야 한다. 프로필 안에만 두면 인증 장애가 난 순간
            // 개인정보 처리방침과 문의 경로까지 함께 잠긴다. 한 줄 링크로 유지해
            // iPhone 가로의 짧은 높이에서도 버튼 묶음 아래에 바로 보이게 한다.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Tokens.Space.s3) {
                    termsLink
                    legalLinkDivider
                    privacyLink
                    legalLinkDivider
                    supportLink
                }

                VStack(spacing: 0) {
                    termsLink
                    privacyLink
                    supportLink
                }
            }
            .font(.mCaption)
            .foregroundStyle(Tokens.text3)
            .accessibilityElement(children: .contain)

            // 게스트 진입은 뺐다(감독 지시).
            //
            // "guest" 라는 이름 자체는 지우지 않는다 — DataScope 의 **기본 데이터
            // 슬롯 이름**이 "guest" 이고, 로그인 전 로컬 기록·로그아웃 후 슬롯이
            // 전부 그 이름 위에 서 있다. 여기서 없앤 것은 **가입 없이 들어가는 문**
            // 하나뿐이다. signInServer 의 게스트 기록 승계 경로도 그대로 둔다 —
            // 예전 버전에서 게스트로 쓰던 학생이 업데이트 후 로그인하면 그 기록이
            // 계정으로 넘어와야 한다.

            // ▼▼▼ 디버그 패스 — 이 묶음 하나만 주석 처리하면 사라진다 ▼▼▼
            #if DEBUG
            if !RuntimeMode.isReviewCapture {
                Button("DEBUG 로그인 건너뛰기") {
                    cancelGoogleSignIn()
                    cancelAppleSignIn()
                    store.signIn(provider: "debug")
                }
                    .font(.mCaption).foregroundStyle(Tokens.text4)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .padding(.top, compactHeight ? 0 : Tokens.Space.s2)
            }
            #endif
            // ▲▲▲ 디버그 패스 끝 ▲▲▲
        }
        .frame(maxWidth: 420)
        .padding(.horizontal, Tokens.Space.s6)
        .padding(.bottom, compactHeight ? Tokens.Space.s1 : Tokens.Space.s10)
    }

    /// iPhone SE 계열의 375pt 가로 높이에서는 52pt 버튼 네 개와 정책 링크가
    /// 동시에 들어가지 않았다. 조작 최소치인 44pt까지만 줄여 링크를 첫 화면에
    /// 남기고, 세로·큰 글자에서는 기존 52pt를 보존한다.
    private var signInButtonHeight: CGFloat { compactHeight ? 44 : 52 }

    /// HStack 자체에만 44pt를 주면 실제 Link의 표적은 글자 높이에 머문다.
    /// 링크마다 조작 영역을 갖게 하고, 큰 글자에서 한 줄이 안 되면 부모
    /// ViewThatFits가 세로로 내려 ScrollView 안에서 모두 읽히게 한다.
    private var termsLink: some View {
        Link("이용약관",
             destination: ServerAPI.baseURL.appendingPathComponent("terms"))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }

    private var privacyLink: some View {
        Link("개인정보처리방침",
             destination: ServerAPI.baseURL.appendingPathComponent("privacy"))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }

    private var supportLink: some View {
        Link("고객지원",
             destination: ServerAPI.baseURL.appendingPathComponent("faq"))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }

    private var legalLinkDivider: some View {
        Text("·")
            .foregroundStyle(Tokens.text4)
            .accessibilityHidden(true)
    }

    // 애플 버튼 색. HIG 는 밝은 배경엔 검정 버튼, 어두운 배경엔 흰 버튼을 요구한다.
    // 여기서만 디자인 토큰을 쓰지 않는다 — Tokens.text1/surface 는 남색이 섞인
    // 근사 흑백이고, 애플 로고는 순수 흑백으로만 그릴 수 있는 규정 자산이다.
    private var appleBackground: Color { colorScheme == .dark ? .white : .black }
    private var appleForeground: Color { colorScheme == .dark ? .black : .white }

    /// 어떤 소셜 버튼을 그릴지 서버에 묻는다. **한 번만 묻는다** — 애플과 카카오가
    /// 각각 조회하면 화면 진입마다 같은 요청이 두 번 나가고, 둘의 응답 시점이
    /// 어긋나 버튼이 따로따로 튀어나온다.
    ///
    /// 실패하면 둘 다 false 로 둔다. 조회 전과 조회 실패는 모두 "모른다" 이고,
    /// 모를 때 그리지 않는 쪽이 안전하다 — 눌러도 안 되는 버튼을 본 학생은
    /// 서버 설정이 아니라 자기 계정에 문제가 있다고 읽는다.
    private func refreshSocialAvailability() async {
        let providers = try? await ServerAPI.socialAuthProviders()
        appleAvailable = providers?.contains { $0.key == "apple" && $0.configured } ?? false
        kakaoAvailable = providers?.contains { $0.key == "kakao" && $0.configured } ?? false
    }

    /// Google 과 **같은 5단 규약**이다: 앞 시도 폐기 → beginAuthenticationAttempt →
    /// 왕복 → signInServer가 슬롯 장벽 안에서 acceptAuthentication. 새 경로를 만들지 않는다.
    private func startAppleSignIn() {
        cancelGoogleSignIn()
        cancelKakaoSignIn()
        cancelAppleSignIn()
        let attemptID = ServerAPI.beginAuthenticationAttempt()
        AuthFlowDiagnostics.begin(provider: "apple", attemptID: attemptID)
        appleAttemptID = attemptID
        appleBusy = true
        appleError = nil
        // 오류 슬롯을 셋이 공유하므로 앞 수단의 문구도 같이 지운다.
        // 아니면 Google 에서 난 빨간 줄이 애플 진행 중에 그대로 남는다.
        googleError = nil
        kakaoError = nil
        store.clearAuthenticationNotice()
        appleTask = Task {
            do {
                let result = try await appleSignIn.signIn()
                guard appleAttemptID == attemptID else { return }
                if case .registration(let context) = result {
                    nativeRegistration = .init(context: context, attemptID: attemptID, provider: "apple")
                    appleTask = nil
                    return // Keep this attempt busy until native registration completes/cancels.
                }
                guard case .authenticated(let auth) = result else { return }
                let entered = try await store.signInServer(auth, attemptID: attemptID)
                guard appleAttemptID == attemptID else { return }
                appleAttemptID = nil
                if !entered {
                    ServerAPI.cancelAuthenticationAttempt(attemptID)
                    appleError = "기존 학습 기록을 안전하게 저장하지 못해 계정을 전환하지 않았습니다. 저장 공간을 확인한 뒤 다시 시도해주세요."
                }
                appleBusy = false
                appleTask = nil
            } catch let error as ASAuthorizationError where error.code == .canceled {
                // 시트를 닫은 것은 실패가 아니다. Google 의 .canceledLogin 과 같게
                // 문구 없이 조용히 끝낸다 — 스스로 취소한 사람에게 빨간 줄을 띄우면
                // 뭔가 잘못한 것처럼 읽힌다.
                ServerAPI.cancelAuthenticationAttempt(attemptID)
                guard appleAttemptID == attemptID else { return }
                appleAttemptID = nil
                appleBusy = false
                appleTask = nil
            } catch {
                AuthFlowDiagnostics.fail(error, attemptID: attemptID)
                ServerAPI.cancelAuthenticationAttempt(attemptID)
                guard appleAttemptID == attemptID else { return }
                appleAttemptID = nil
                appleError = (error as? ServerAPIError)?.errorDescription
                    ?? "Apple 로그인을 완료하지 못했습니다."
                appleBusy = false
                appleTask = nil
            }
        }
    }

    private func cancelAppleSignIn() {
        if nativeRegistration?.provider == "apple" { nativeRegistration = nil }
        AuthFlowDiagnostics.record("cancel_requested", attemptID: appleAttemptID)
        appleTask?.cancel()
        appleTask = nil
        ServerAPI.cancelAuthenticationAttempt(appleAttemptID)
        appleSignIn.cancel()
        appleAttemptID = nil
        appleBusy = false
    }

    /// Google·Apple 과 **같은 5단 규약**. 새 경로를 만들지 않는다.
    private func startKakaoSignIn() {
        cancelGoogleSignIn()
        cancelAppleSignIn()
        cancelKakaoSignIn()
        let attemptID = ServerAPI.beginAuthenticationAttempt()
        AuthFlowDiagnostics.begin(provider: "kakao", attemptID: attemptID)
        kakaoAttemptID = attemptID
        kakaoBusy = true
        kakaoError = nil
        // 오류 슬롯을 셋이 공유하므로 앞 수단의 문구도 같이 지운다.
        googleError = nil
        appleError = nil
        store.clearAuthenticationNotice()
        kakaoTask = Task {
            do {
                let result = try await kakaoSignIn.signIn()
                guard kakaoAttemptID == attemptID else { return }
                if case .registration(let context) = result {
                    nativeRegistration = .init(context: context, attemptID: attemptID, provider: "kakao")
                    kakaoTask = nil
                    return
                }
                guard case .authenticated(let auth) = result else { return }
                let entered = try await store.signInServer(auth, attemptID: attemptID)
                guard kakaoAttemptID == attemptID else { return }
                kakaoAttemptID = nil
                if !entered {
                    ServerAPI.cancelAuthenticationAttempt(attemptID)
                    kakaoError = "기존 학습 기록을 안전하게 저장하지 못해 계정을 전환하지 않았습니다. 저장 공간을 확인한 뒤 다시 시도해주세요."
                }
                kakaoBusy = false
                kakaoTask = nil
            } catch let error as ASWebAuthenticationSessionError
                        where error.code == .canceledLogin {
                // 창을 닫은 것은 실패가 아니다. 스스로 취소한 사람에게 빨간 줄을
                // 띄우면 뭔가 잘못한 것처럼 읽힌다 — Google 과 같은 처리다.
                ServerAPI.cancelAuthenticationAttempt(attemptID)
                guard kakaoAttemptID == attemptID else { return }
                kakaoAttemptID = nil
                kakaoBusy = false
                kakaoTask = nil
            } catch {
                AuthFlowDiagnostics.fail(error, attemptID: attemptID)
                ServerAPI.cancelAuthenticationAttempt(attemptID)
                guard kakaoAttemptID == attemptID else { return }
                kakaoAttemptID = nil
                kakaoError = (error as? ServerAPIError)?.errorDescription
                    ?? "카카오 로그인을 완료하지 못했습니다."
                kakaoBusy = false
                kakaoTask = nil
            }
        }
    }

    private func cancelKakaoSignIn() {
        if nativeRegistration?.provider == "kakao" { nativeRegistration = nil }
        AuthFlowDiagnostics.record("cancel_requested", attemptID: kakaoAttemptID)
        kakaoTask?.cancel()
        kakaoTask = nil
        ServerAPI.cancelAuthenticationAttempt(kakaoAttemptID)
        kakaoSignIn.cancel()
        kakaoAttemptID = nil
        kakaoBusy = false
    }

    /// The native form never owns Keychain promotion. It returns an AuthResponse
    /// to the same latest-attempt + account-slot boundary as ordinary login.
    private func completeNativeRegistration(_ auth: AuthResponse,
                                            presentation: NativeRegistrationPresentation) {
        let attemptID = presentation.attemptID
        let isApple = presentation.provider == "apple"
        guard nativeRegistration?.id == presentation.id,
              (isApple ? appleAttemptID : kakaoAttemptID) == attemptID else { return }
        nativeRegistration = nil
        let task = Task { @MainActor in
            do {
                try Task.checkCancellation()
                guard (isApple ? appleAttemptID : kakaoAttemptID) == attemptID else { return }
                let entered = try await store.signInServer(auth, attemptID: attemptID)
                guard (isApple ? appleAttemptID : kakaoAttemptID) == attemptID else { return }
                if !entered {
                    ServerAPI.cancelAuthenticationAttempt(attemptID)
                    let message = "기존 학습 기록을 저장하지 못했습니다. 저장 공간을 확인한 뒤 다시 로그인해 주세요."
                    if isApple { appleError = message } else { kakaoError = message }
                }
            } catch {
                AuthFlowDiagnostics.fail(error, attemptID: attemptID)
                ServerAPI.cancelAuthenticationAttempt(attemptID)
                guard (isApple ? appleAttemptID : kakaoAttemptID) == attemptID else { return }
                if !(error is CancellationError) {
                    let message = (error as? ServerAPIError)?.errorDescription ?? "로그인을 완료하지 못했습니다. 다시 시도해 주세요."
                    if isApple { appleError = message } else { kakaoError = message }
                }
            }
            guard (isApple ? appleAttemptID : kakaoAttemptID) == attemptID else { return }
            if isApple { appleAttemptID = nil; appleBusy = false; appleTask = nil }
            else { kakaoAttemptID = nil; kakaoBusy = false; kakaoTask = nil }
        }
        if isApple { appleTask = task } else { kakaoTask = task }
    }

    private func startGoogleSignIn() {
        cancelAppleSignIn()
        cancelKakaoSignIn()
        cancelGoogleSignIn()
        let attemptID = ServerAPI.beginAuthenticationAttempt()
        AuthFlowDiagnostics.begin(provider: "google", attemptID: attemptID)
        googleAttemptID = attemptID
        googleBusy = true
        googleError = nil
        // 위와 같은 이유 — 공유 슬롯이라 다른 수단의 문구도 여기서 지운다.
        appleError = nil
        kakaoError = nil
        store.clearAuthenticationNotice()
        googleTask = Task {
            do {
                let auth = try await googleSignIn.signIn()
                guard googleAttemptID == attemptID else { return }
                let entered = try await store.signInServer(auth, attemptID: attemptID)
                guard googleAttemptID == attemptID else { return }
                googleAttemptID = nil
                if !entered {
                    ServerAPI.cancelAuthenticationAttempt(attemptID)
                    googleError = "기존 학습 기록을 안전하게 저장하지 못해 계정을 전환하지 않았습니다. 저장 공간을 확인한 뒤 다시 시도해주세요."
                }
                googleBusy = false
                googleTask = nil
            } catch let error as ASWebAuthenticationSessionError
                where error.code == .canceledLogin {
                ServerAPI.cancelAuthenticationAttempt(attemptID)
                guard googleAttemptID == attemptID else { return }
                googleAttemptID = nil
                googleBusy = false
                googleTask = nil
            } catch {
                AuthFlowDiagnostics.fail(error, attemptID: attemptID)
                ServerAPI.cancelAuthenticationAttempt(attemptID)
                guard googleAttemptID == attemptID else { return }
                googleAttemptID = nil
                googleError = (error as? ServerAPIError)?.errorDescription
                    ?? "Google 로그인을 완료하지 못했습니다."
                googleBusy = false
                googleTask = nil
            }
        }
    }

    private func cancelGoogleSignIn() {
        AuthFlowDiagnostics.record("cancel_requested", attemptID: googleAttemptID)
        googleTask?.cancel()
        googleTask = nil
        ServerAPI.cancelAuthenticationAttempt(googleAttemptID)
        googleSignIn.cancel()
        googleAttemptID = nil
        googleBusy = false
    }
}

private struct AuthLandingLayout: Layout {
    let viewportHeight: CGFloat
    let compact: Bool

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let width = max(0, proposal.width ?? 420)
        let measurement = ProposedViewSize(width: width, height: nil)
        let placement = AuthLandingGeometry.resolve(viewportHeight: viewportHeight,
            brandHeight: subviews[0].sizeThatFits(measurement).height,
            actionsHeight: subviews[1].sizeThatFits(measurement).height, compact: compact)
        return CGSize(width: width, height: placement.contentHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let measurement = ProposedViewSize(width: bounds.width, height: nil)
        let placement = AuthLandingGeometry.resolve(viewportHeight: viewportHeight,
            brandHeight: subviews[0].sizeThatFits(measurement).height,
            actionsHeight: subviews[1].sizeThatFits(measurement).height, compact: compact)
        subviews[0].place(at: CGPoint(x: bounds.midX, y: bounds.minY + placement.brandCenterY),
                          anchor: .center, proposal: measurement)
        subviews[1].place(at: CGPoint(x: bounds.midX, y: bounds.minY + placement.actionsTop),
                          anchor: .top, proposal: measurement)
    }
}

// MARK: - 이메일 가입/로그인 (서버 /api/v1/auth — Bearer 토큰 트랙)

struct EmailAuthSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    enum Mode: String, CaseIterable { case login = "로그인", register = "회원가입" }
    @State private var mode: Mode = .register

    @State private var realName = ""
    @State private var nickname = ""
    @State private var email = ""
    @State private var password = ""
    @State private var birthDate = Calendar.current.date(
        from: DateComponents(year: 2010, month: 1, day: 1)) ?? Date()
    @State private var grade = 10
    // 필수 동의는 문서 단위로 따로 받는다. 예전엔 토글 하나가 두 문서를 한꺼번에
    // 묶었고 본문으로 가는 길도 링크 두 개가 토글과 떨어져 있었다 — 미성년자 대상
    // 서비스라 "무엇에 동의했는지" 가 문서별로 남아야 하고, 심사도 여기를 본다.
    @State private var termsOfServiceOK = false
    @State private var privacyPolicyOK = false
    @State private var showSchoolPicker = false
    // 가입 폼의 학교는 **폼 로컬 상태**다. 예전엔 피커가 곧장 store.setSchool 을
    // 불러서 가입을 취소해도 게스트 프로필에 학교가 남았다 — 폼의 다른 필드는
    // 전부 @State 인데 학교만 전역이라 진실원이 갈렸다. store 반영은 가입 성공 후
    // signInServer 가 서버 응답(user.school)으로 수행한다.
    @State private var schoolRegion: String?
    @State private var schoolCode: String?
    @State private var schoolName: String?

    @State private var busy = false
    @State private var errorText: String?
    @State private var showReset = false
    @State private var authAttemptID: UUID?
    private enum FocusedField { case realName, nickname, email, password }
    @FocusState private var focusedField: FocusedField?
    /// 시트 안에서도 세로가 짧은 창(iPhone 가로)을 따로 본다.
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var compactHeight: Bool { verticalSizeClass == .compact }
    /// 큰 글씨에서는 바깥 CompactHeightColumns뿐 아니라 입력 필드의 내부 HStack도
    /// 반드시 한 열로 돌아가야 한다. 그렇지 않으면 생년월일·이메일·비밀번호가
    /// 반쪽 열 안에서 몇 글자씩 찢어지고 하단 액션 바 뒤에 겹쳐 보인다.
    private var usesCompactFieldRows: Bool {
        compactHeight && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                    modePicker

                    if compactHeight {
                        CompactHeightColumns(
                            spacing: Tokens.Space.s5,
                            stackedSpacing: Tokens.Space.s4
                        ) {
                            identityAndCredentialFields
                        } trailing: {
                            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                                if mode == .register { registrationRequirements }
                                formErrorAndRecovery
                            }
                        }
                    } else {
                        identityAndCredentialFields
                        if mode == .register { registrationRequirements }
                        formErrorAndRecovery
                        submitButton
                        unmetHint
                    }
                }
                .padding(.horizontal, Tokens.Space.s6)
                // 세로가 짧으면 위아래 24pt 두 겹이 폼 한 줄만큼을 먹는다.
                .padding(.vertical, compactHeight ? Tokens.Space.s2 : Tokens.Space.s6)
            }
            // iPhone 가로는 키보드가 시트의 절반을 덮는다. 스크롤로 내릴 수 있게 한다.
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.visible)
            .onChange(of: mode) { _, _ in focusedField = nil }
            .navigationTitle(mode == .register ? "회원가입" : "로그인")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        cancelAuthentication()
                        dismiss()
                    }
                }
            }
            // IPAD_API.md 규약: 가입 폼의 학교 목록은 서버(GET /api/v1/schools)가 우선.
            // 콜백으로 받아 폼 로컬 상태에만 둔다 — 전역 store 를 오염시키지 않고,
            // 서버 목록에만 있는 학교(내장 목록 검증에 걸리던)도 그대로 받는다.
            .fullScreenCover(isPresented: $showSchoolPicker) {
                APISchoolPickerSheet { region, code, name in
                    schoolRegion = region
                    schoolCode = code
                    schoolName = name
                }
            }
            .fullScreenCover(isPresented: $showReset) { PasswordResetSheet(prefillEmail: email) }
            .onAppear {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-authKeyboard") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        focusedField = .email
                    }
                }
                #endif
            }
            .onDisappear { cancelAuthentication() }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // 포커스된 필드는 같은 뷰 트리에 남겨 둔다. 키보드가 올라온 동안에는
            // 액션 바만 걷어 입력 공간을 돌려주고, Done으로 포커스가 풀리면 복원한다.
            if compactHeight && focusedField == nil {
                HStack(spacing: Tokens.Space.s4) {
                    unmetHint
                    Spacer(minLength: Tokens.Space.s2)
                    submitButton.frame(maxWidth: 320)
                }
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .safeAreaPadding(.horizontal, Tokens.Space.s5)
                .padding(.vertical, Tokens.Space.s2)
                .background(Tokens.surface)
                .overlay(alignment: .top) { Divider().overlay(Tokens.line) }
                // safeAreaInset 은 본문 NavigationStack 뒤에 별도 형제로 붙는다.
                // 우선순위를 지정하지 않으면 VoiceOver가 이 바의 오류/버튼부터 읽어
                // 제목과 입력 폼을 건너뛴 것처럼 들린다. 바 내부 순서는 유지하되,
                // 화면의 마지막 행동으로 읽히게 하나의 저우선순위 그룹으로 둔다.
                .accessibilityElement(children: .contain)
                .accessibilitySortPriority(-10)
            }
        }
    }

    private var modePicker: some View {
        Picker("", selection: $mode) {
            ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("로그인 또는 회원가입")
        .disabled(busy)
    }

    @ViewBuilder
    private var identityAndCredentialFields: some View {
        if usesCompactFieldRows {
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                if mode == .register {
                    HStack(alignment: .bottom, spacing: Tokens.Space.s2) {
                        field("실명", text: $realName, placeholder: "홍길동",
                              contentType: .name)
                            .focused($focusedField, equals: .realName)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .nickname }
                        field("닉네임 (Arena 표시)", text: $nickname,
                              placeholder: "맵쓰수학왕", contentType: .nickname)
                            .focused($focusedField, equals: .nickname)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .email }
                    }
                    HStack(alignment: .bottom, spacing: Tokens.Space.s2) {
                        birthDateField.frame(maxWidth: 112)
                        emailField
                        passwordField
                    }
                } else {
                    HStack(alignment: .bottom, spacing: Tokens.Space.s2) {
                        emailField
                        passwordField
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                if mode == .register {
                    field("실명", text: $realName, placeholder: "홍길동", contentType: .name)
                        .focused($focusedField, equals: .realName)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .nickname }
                    field("닉네임 (GOAT Arena 표시 이름)", text: $nickname,
                          placeholder: "맵쓰수학왕", contentType: .nickname)
                        .focused($focusedField, equals: .nickname)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .email }
                    birthDateField
                }
                emailField
                passwordField
            }
        }
    }

    private var birthDateField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("생년월일").font(.mCaption).foregroundStyle(Tokens.text3)
            DatePicker("생년월일", selection: $birthDate, in: ...Date(),
                       displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .environment(\.locale, Locale(identifier: "ko_KR"))
                .frame(minHeight: 44)
        }
    }

    private var emailField: some View {
        // 로그인은 .username 이다. 키체인이 아이디+비밀번호 쌍을 제안하려면
        // 이 값이어야 한다. 가입은 .emailAddress 자동완성을 받는다.
        field("이메일", text: $email, placeholder: "you@example.com",
              keyboard: .emailAddress,
              contentType: mode == .login ? .username : .emailAddress)
            .focused($focusedField, equals: .email)
            .submitLabel(.next)
            .onSubmit { focusedField = .password }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("비밀번호").font(.mCaption).foregroundStyle(Tokens.text3)
            SecureField("8자 이상", text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(minHeight: 44)
                .textContentType(mode == .register ? .newPassword : .password)
                .focused($focusedField, equals: .password)
                .submitLabel(.done)
                .onSubmit {
                    if formValid { submit() }
                    else { focusedField = nil }
                }
        }
    }

    @ViewBuilder
    private var registrationRequirements: some View {
        VStack(alignment: .leading, spacing: compactHeight ? Tokens.Space.s2 : Tokens.Space.s4) {
            // 320pt Slide Over에서는 학교를 다음 줄로 보내고, iPhone 가로의 오른쪽
            // 열에서는 학년과 학교가 가용 폭 안에서 맞으면 같은 행을 쓴다.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: Tokens.Space.s4) {
                    gradeField.frame(maxWidth: 280)
                    schoolField.fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    gradeField
                    schoolField
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                if !compactHeight {
                    Text("필수 동의").font(.mCaption).foregroundStyle(Tokens.text3)
                }
                consentRow("이용약관에 동의합니다", document: "이용약관",
                           isOn: $termsOfServiceOK,
                           destination: ServerAPI.baseURL.appendingPathComponent("terms"))
                consentRow("개인정보 처리방침에 동의합니다", document: "개인정보 처리방침",
                           isOn: $privacyPolicyOK,
                           destination: ServerAPI.baseURL.appendingPathComponent("privacy"))
            }
            .tint(Tokens.primary)
        }
    }

    @ViewBuilder
    private var formErrorAndRecovery: some View {
        if let e = errorText {
            Text(e).font(.mCaption).foregroundStyle(Tokens.dangerInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        if mode == .login {
            Button("비밀번호를 잊었나요?") { showReset = true }
                .font(.mCaption).foregroundStyle(Tokens.text3)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
    }

    private var submitButton: some View {
        Button { submit() } label: {
            if busy { ProgressView().frame(maxWidth: .infinity, minHeight: 52) }
            else {
                Text(mode == .register ? "가입하고 시작하기" : "로그인")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(busy || !formValid)
    }

    @ViewBuilder
    private var unmetHint: some View {
        if let hint = firstUnmetHint, !busy {
            Text(hint).font(.mMicro).foregroundStyle(Tokens.text4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var formValid: Bool { firstUnmetHint == nil }

    /// 버튼이 왜 잠겼는지 — 첫 번째 미충족 조건을 사람 말로. 회색 버튼만 남기면
    /// 사용자는 원인을 추측해야 하고, 오류는 서버 왕복 후에야 나타났다.
    /// 조건과 문구를 한 곳에 모아 formValid 와 안내가 어긋날 수 없게 한다.
    /// (최신 서버 계약: 생년월일은 전 학년 필수, 학교는 N수생을 제외하고 필수.)
    private var firstUnmetHint: String? {
        if mode == .register {
            if realName.isEmpty { return "실명을 입력해 주세요" }
            if nickname.isEmpty { return "닉네임을 입력해 주세요" }
        }
        if !(email.contains("@") && email.contains(".")) { return "이메일 주소를 입력해 주세요" }
        if password.count < 8 { return "비밀번호는 8자 이상이어야 합니다" }
        if mode == .login { return nil }
        if grade != 13, schoolRegion == nil || schoolCode == nil { return "학교를 선택해 주세요" }
        if !termsOfServiceOK { return "이용약관 동의가 필요합니다" }
        if !privacyPolicyOK { return "개인정보 처리방침 동의가 필요합니다" }
        return nil
    }

    /// 문서 하나 = 동의 토글 하나 + 그 문서로 가는 길 하나.
    /// 폭이 좁으면 "전문 보기" 를 다음 줄로 내린다. 두 배치 모두 44pt 를 지킨다 —
    /// 좁다고 링크를 글자 크기만 한 표적으로 만들면 손가락으로 못 누른다.
    private func consentRow(_ title: String,
                            document: String,
                            isOn: Binding<Bool>,
                            destination: URL) -> some View {
        let toggle = Toggle("", isOn: isOn)
            .labelsHidden()
            .accessibilityLabel(title)
        let caption = Text(title)
            .font(.mCallout)
            .foregroundStyle(Tokens.text2)
            .fixedSize(horizontal: false, vertical: true)
        let documentLink = Link(destination: destination) {
            HStack(spacing: 4) {
                Text("전문 보기").font(.mCaption)
                Image(systemName: "arrow.up.right.square").font(.mMicro)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .foregroundStyle(Tokens.primary)
        .accessibilityLabel("\(document) 전문 보기")
        .accessibilityHint("브라우저에서 문서를 엽니다")

        return ViewThatFits(in: .horizontal) {
            HStack(spacing: Tokens.Space.s3) {
                toggle
                caption
                Spacer(minLength: Tokens.Space.s2)
                documentLink
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Tokens.Space.s3) {
                    toggle
                    caption
                    Spacer(minLength: 0)
                }
                HStack(spacing: Tokens.Space.s3) {
                    // 자리맞춤용 — 스위치 폭만 차지하고 그리지도, 읽히지도 않는다.
                    // 이게 없으면 "전문 보기"가 스위치 아래로 붙어 어느 약관의
                    // 본문인지 눈으로 이어지지 않는다.
                    toggle.hidden()
                    documentLink
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(minHeight: 44)
    }

    private func submit() {
        cancelAuthentication()
        let attemptID = ServerAPI.beginAuthenticationAttempt()
        authAttemptID = attemptID
        busy = true
        errorText = nil
        Task {
            do {
                let auth: AuthResponse
                if mode == .register {
                    auth = try await ServerAPI.register(
                        realName: realName, name: nickname, email: email, password: password,
                        birthDate: birthDateString,
                        schoolGrade: grade,
                        schoolRegion: schoolRegion, schoolCode: schoolCode)
                } else {
                    auth = try await ServerAPI.login(email: email, password: password)
                }
                let current = await MainActor.run { authAttemptID == attemptID }
                guard current else { return }
                let entered = try await store.signInServer(auth, attemptID: attemptID)
                await MainActor.run {
                    guard authAttemptID == attemptID else { return }
                    authAttemptID = nil
                    if entered {
                        dismiss()
                    } else {
                        ServerAPI.cancelAuthenticationAttempt(attemptID)
                        errorText = "기존 학습 기록을 안전하게 저장하지 못해 계정을 전환하지 않았습니다. 저장 공간을 확인한 뒤 다시 시도해주세요."
                        busy = false
                    }
                }
            } catch {
                await MainActor.run {
                    ServerAPI.cancelAuthenticationAttempt(attemptID)
                    guard authAttemptID == attemptID else { return }
                    authAttemptID = nil
                    errorText = (error as? ServerAPIError)?.errorDescription
                        ?? "서비스에 연결하지 못했어요. 잠시 후 다시 시도해 주세요."
                    busy = false
                }
            }
        }
    }

    private func cancelAuthentication() {
        ServerAPI.cancelAuthenticationAttempt(authAttemptID)
        authAttemptID = nil
        busy = false
    }

    /// 서버 `normalizeBirthDate`가 받는 달력 날짜. ISO8601 시각으로 보내면
    /// 자정의 시간대 변환 때문에 날짜가 하루 밀릴 수 있어 날짜 구성요소만 직렬화한다.
    private var birthDateString: String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: birthDate)
        return String(format: "%04d-%02d-%02d", c.year ?? 2010, c.month ?? 1, c.day ?? 1)
    }

    private var gradeField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("학년").font(.mCaption).foregroundStyle(Tokens.text3)
            Picker("학년", selection: $grade) {
                Text("고1").tag(10); Text("고2").tag(11); Text("고3").tag(12)
                Text("N수").tag(13)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)
            .frame(minHeight: 44)
        }
    }

    @ViewBuilder private var schoolField: some View {
        if grade != 13 {
            VStack(alignment: .leading, spacing: 4) {
                Text("학교 (필수)").font(.mCaption).foregroundStyle(Tokens.text3)
                Button {
                    showSchoolPicker = true
                } label: {
                    Text(schoolName ?? "학교 선택")
                        .font(.mCallout)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(schoolName == nil ? Tokens.text3 : Tokens.ink)
                        // 글자 크기는 그대로 두고 히트 영역만 44pt 로 넓힌다.
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder private func field(_ label: String, text: Binding<String>,
                                    placeholder: String,
                                    keyboard: UIKeyboardType = .default,
                                    contentType: UITextContentType? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.mCaption).foregroundStyle(Tokens.text3)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .frame(minHeight: 44)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .autocapitalization(.none)
                .autocorrectionDisabled()
        }
    }
}

// MARK: - 서버 학교 목록 피커 (IPAD_API.md — GET /api/v1/schools)
//
// 서버 목록이 진실원. 서버에 못 닿으면 기기 내장 목록(schools.json — 같은
// NEIS 데이터라 코드 호환)으로 폴백하고 그 사실을 표시한다.

struct APISchoolPickerSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    /// 선택 결과의 수신처. 가입 폼처럼 전역 store 를 오염시키면 안 되는 호출부는
    /// 콜백으로 받는다. nil 이면 종전대로 store.setSchool — 단, setSchool 은 내장
    /// 목록으로 재검증하므로 서버에만 있는 학교는 조용히 거부된다는 한계가 있다.
    var onPick: ((_ region: String, _ code: String, _ name: String) -> Void)? = nil

    @State private var regions: [String: [ServerAPI.APISchool]] = [:]
    @State private var regionName = ""
    @State private var query = ""
    @State private var loading = true
    @State private var offline = false

    private var regionNames: [String] { regions.keys.sorted() }
    private var schools: [ServerAPI.APISchool] {
        let list = regions[regionName] ?? []
        return query.isEmpty ? list
            : list.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Tokens.Space.s3) {
                if loading {
                    ProgressView("서버에서 학교 목록을 받는 중…").padding(.top, Tokens.Space.s8)
                    Spacer()
                } else {
                    // 좌우 여백을 검색 필드에만 걸어 두어서 iPhone 폭에서는 지역
                    // 피커와 안내문만 화면 끝에 붙어 있었다. 헤더 묶음이 같은
                    // 여백을 쓰게 하고, 메뉴 피커도 44pt 표적을 갖게 한다.
                    VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                        if offline {
                            Text("서버에 연결하지 못해 기기 내장 목록을 표시합니다.")
                                .font(.mMicro).foregroundStyle(Tokens.warningInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Picker("지역", selection: $regionName) {
                            ForEach(regionNames, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(minHeight: 44)

                        TextField("학교 이름 검색", text: $query)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Tokens.Space.s4)

                    List(schools) { school in
                        Button {
                            if let onPick {
                                onPick(regionName, school.code, school.name)
                            } else {
                                store.setSchool(region: regionName, code: school.code)
                            }
                            dismiss()
                        } label: {
                            HStack {
                                Text(school.name).foregroundStyle(Tokens.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: Tokens.Space.s3)
                                Text(school.highSchoolType ?? "")
                                    .font(.mCaption).foregroundStyle(Tokens.text3)
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                    }
                    .listStyle(.plain)
                    // iPhone 에서는 검색 키보드가 목록의 절반을 덮는다.
                    .scrollDismissesKeyboard(.immediately)
                }
            }
            .navigationTitle("학교 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            }
            .task { await load() }
        }
    }

    private func load() async {
        do {
            let fetched = try await ServerAPI.schools()
            await MainActor.run {
                regions = fetched
                regionName = regionNames.first ?? ""
                loading = false
            }
        } catch {
            // 폴백 — 내장 목록을 같은 모양으로 변환
            let bundled = Dictionary(uniqueKeysWithValues: Schools.regions.map { r in
                (r.name, r.schools.map {
                    ServerAPI.APISchool(code: $0.code, name: $0.name, highSchoolType: $0.type)
                })
            })
            await MainActor.run {
                regions = bundled
                regionName = regionNames.first ?? ""
                offline = true
                loading = false
            }
        }
    }
}

// MARK: - 비밀번호 재설정 3단계 (IPAD_API.md)
//
// request(이메일) → verify(6자리 코드) → complete(새 비밀번호).
// 메일 키 없는 개발 서버는 previewCode 를 응답에 실어준다 — **DEBUG 빌드에서만**
// 보여준다. 출시 바이너리에 이 표시가 남으면, 운영 서버가 메일 키 설정을 잃는
// 순간 아무나 남의 이메일을 넣고 재설정 코드를 화면에서 읽는 계정 탈취 통로가
// 된다. 서버 잘못이 전제라도 클라이언트가 "비밀이 오면 보여준다"는 기본값을
// 갖지 않는 것이 다층 방어다.

struct PasswordResetSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    let prefillEmail: String
    var isPasswordChange = false

    enum Step { case email, code, newPassword, done }
    @State private var step: Step = .email
    @State private var email = ""
    @State private var code = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var requestTask: Task<Void, Never>?
    @State private var previewCode: String?
    @State private var authz: ServerAPI.ResetAuthorization?
    @State private var busy = false
    @State private var errorText: String?
    @State private var keyboardVisible = false
    private enum FocusedField { case email, code, newPassword, confirmPassword }
    @FocusState private var focusedField: FocusedField?
    private var compactHeight: Bool { verticalSizeClass == .compact }

    var body: some View {
        NavigationStack {
            // 고정 VStack 이었다. 세로가 짧은 창(iPhone 가로, 가용 높이 약 390pt)에서
            // 키보드가 올라오거나 Dynamic Type 을 키우면 "다음" 버튼이 화면 밖으로
            // 밀려 재설정을 끝낼 방법이 없었다. 남으면 그대로, 모자라면 스크롤한다.
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                    switch step {
                    case .email:
                        Text("이메일 인증으로 비밀번호를 변경합니다. 가입한 이메일로 인증코드를 보냅니다.")
                            .font(.mCallout).foregroundStyle(Tokens.text2)
                            .fixedSize(horizontal: false, vertical: true)
                        TextField("이메일", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .submitLabel(.done)
                            .onSubmit { focusedField = nil }
                    case .code:
                        Text("이메일로 받은 6자리 코드를 입력하세요.")
                            .font(.mCallout).foregroundStyle(Tokens.text2)
                            .fixedSize(horizontal: false, vertical: true)
                        // 개발 편의 표시 — Release 에는 컴파일 자체를 남기지 않는다
                        // (파일 머리주석의 계정 탈취 시나리오 참조).
                        #if DEBUG
                        if !RuntimeMode.isReviewCapture, let p = previewCode {
                            Text("개발 서버 미리보기 코드: \(p)")
                                .font(.mCaption).foregroundStyle(Tokens.warningInk)
                        }
                        #endif
                        TextField("123456", text: $code)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .focused($focusedField, equals: .code)
                    case .newPassword:
                        Text("새 비밀번호는 영문과 숫자를 포함해 8자 이상, 72바이트 이하로 입력해 주세요.")
                            .font(.mCallout).foregroundStyle(Tokens.text2)
                            .fixedSize(horizontal: false, vertical: true)
                        SecureField("새 비밀번호", text: $newPassword)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .newPassword)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .confirmPassword }
                        SecureField("새 비밀번호 확인", text: $confirmPassword)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .confirmPassword)
                            .submitLabel(.done)
                            .onSubmit { focusedField = nil }
                        if !confirmPassword.isEmpty && !confirmPassword.utf8.elementsEqual(newPassword.utf8) {
                            Text("새 비밀번호와 확인 입력이 일치하지 않습니다.")
                                .font(.mCaption).foregroundStyle(Tokens.dangerInk)
                        }
                        if newPassword.utf8.count > 72 {
                            Text("비밀번호가 너무 깁니다. 한글이나 이모지가 포함됐다면 글자 수를 줄여 주세요.")
                                .font(.mCaption).foregroundStyle(Tokens.dangerInk)
                        }
                    case .done:
                        Label("비밀번호가 변경되었습니다. 새 비밀번호로 로그인하세요.",
                              systemImage: "checkmark.circle.fill")
                            .font(.mBodyB).foregroundStyle(Tokens.successInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let e = errorText {
                        Text(e).font(.mCaption).foregroundStyle(Tokens.dangerInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !compactHeight { advanceButton }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Tokens.Space.s6)
            }
            .scrollBounceBehavior(.basedOnSize)
            // 좁은 화면에서는 키보드가 폼의 절반을 덮는다. 스크롤로 걷어낼 수 있게 한다.
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isPasswordChange ? "비밀번호 변경" : "비밀번호 재설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    if focusedField != nil {
                        Button("완료") { focusedField = nil }
                    }
                }
            }
            .onAppear { if email.isEmpty { email = prefillEmail } }
            .onReceive(NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillShowNotification)) { _ in
                    keyboardVisible = true
                }
            .onReceive(NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillHideNotification)) { _ in
                    keyboardVisible = false
                }
            .onDisappear {
                keyboardVisible = false
                requestTask?.cancel()
                code = ""; newPassword = ""; confirmPassword = ""; authz = nil; previewCode = nil
            }
            .onChange(of: step) { _, newStep in
                // 다음 단계가 열린 사실을 키보드까지 이어 준다. 코드 입력은 숫자
                // 키보드라 Return이 없으므로 위의 "완료"도 항상 함께 제공한다.
                DispatchQueue.main.async {
                    switch newStep {
                    case .code: focusedField = .code
                    case .newPassword: focusedField = .newPassword
                    case .email, .done: focusedField = nil
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // iPhone 가로에서 키보드와 버튼을 같은 390pt 높이에 억지로 넣으면
            // 버튼이 키보드 뒤에 걸린다. 입력 중에는 키보드 툴바의 완료로 포커스를
            // 끝내고, 즉시 복원되는 고정 액션으로 다음 단계에 간다.
            if compactHeight && !keyboardVisible {
                advanceButton
                    .frame(maxWidth: 420)
                    .safeAreaPadding(.horizontal, Tokens.Space.s5)
                    .padding(.vertical, Tokens.Space.s2)
                    .frame(maxWidth: .infinity)
                    .background(Tokens.surface)
                    .overlay(alignment: .top) { Divider().overlay(Tokens.line) }
            }
        }
    }

    private var advanceButton: some View {
        Button { advance() } label: {
            if busy { ProgressView().frame(maxWidth: .infinity, minHeight: 48) }
            else {
                Text(step == .done ? "로그인하러 가기" : "다음")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(busy || !stepValid)
    }

    private var stepValid: Bool {
        switch step {
        case .email: return email.contains("@")
        case .code: return code.count == 6 && code.allSatisfy { $0.isASCII && $0.isNumber }
        case .newPassword: return PasswordChangeValidation.isValid(newPassword, confirmation: confirmPassword)
        case .done: return true
        }
    }

    private func advance() {
        if step == .done { dismiss(); return }
        busy = true
        errorText = nil
        let account = store.captureAccountSessionBoundary()
        requestTask = Task { @MainActor in
            do {
                switch step {
                case .email:
                    let res = try await ServerAPI.passwordResetRequest(email: email)
                    try Task.checkCancellation()
                    await MainActor.run {
                        #if DEBUG
                        // 서버가 실어 준 미리보기 코드는 DEBUG 에서만 받는다 —
                        // Release 는 값 자체를 버려 표시 경로를 원천 차단한다.
                        previewCode = res.previewCode
                        #else
                        _ = res
                        #endif
                        step = .code
                    }
                case .code:
                    let a = try await ServerAPI.passwordResetVerify(email: email, code: code)
                    try Task.checkCancellation()
                    await MainActor.run { authz = a; step = .newPassword }
                case .newPassword:
                    guard let a = authz else { throw ServerAPIError(message: "인증이 만료됐습니다. 처음부터 다시 진행해 주세요.", code: nil) }
                    try await ServerAPI.passwordResetComplete(auth: a, newPassword: newPassword)
                    // The password is already changed on the server. Never retain reset secrets.
                    code = ""; newPassword = ""; confirmPassword = ""; authz = nil; previewCode = nil
                    if isPasswordChange, store.ownsCurrentAccountSession(account) {
                        await store.finishPasswordChange(for: account)
                    }
                    try Task.checkCancellation()
                    await MainActor.run { step = .done }
                case .done: break
                }
                await MainActor.run { busy = false }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    errorText = (error as? ServerAPIError)?.errorDescription ?? "요청 실패"
                    busy = false
                }
            }
        }
    }
}
