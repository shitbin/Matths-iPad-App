//  DesignTokens.swift
//  Matths
//
//  웹 토큰(tokens.css)을 Swift 로 옮긴 것.
//  웹과 앱이 같은 값을 쓰지 않으면 두 화면이 서서히 갈라진다.
//  값을 바꿀 때는 반드시 양쪽을 함께 고친다.
//
//  "양쪽" 이 어디인지 — 한때 여기가 어긋나 두 파일 전 항목이 갈라져 있었다.
//   · 앱(이 파일) = 팔레트 v4
//   · 웹 = design-system/tokens.css (v4 정본). apply_tokens.sh 가 이것을
//     public/css/tokens.css 로 복사한다.
//  2026-07-29 이전에는 design-system/tokens.css 가 v3(#1f1b16 · #fffefb · #d9402a)여서
//  그 스크립트를 돌릴 때마다 웹이 v3 로 되돌아갔다. 지금은 v4 로 통일했다.

import SwiftUI

/// 서버 계약의 SUB/MAIN 키를 화면 언어와 분리한다.
/// 네트워크·저장 키는 바꾸지 않고 모든 사용자 표시는 이 매퍼를 거친다.
enum ArenaDisplayTerms {
    private static let replacements: [(String, String)] = [
        (#"서브\s*디비전"#, "Unranked"),
        (#"메인\s*디비전"#, "Ranked"),
        // \b는 영문과 한글 사이를 단어 경계로 보지 않아 "Division별"을
        // 놓친다. 영문자만 내부 키의 경계로 취급해 한글 조사·접미사도 치환한다.
        (#"(?<![A-Za-z])Sub Division(?![A-Za-z])"#, "Unranked"),
        (#"(?<![A-Za-z])Main Division(?![A-Za-z])"#, "Ranked"),
        (#"(?<![A-Za-z])Sub Ranking(?![A-Za-z])"#, "Unranked"),
        (#"(?<![A-Za-z])Main Ranking(?![A-Za-z])"#, "Ranked"),
        (#"(?<![A-Za-z])Sub(?![A-Za-z])"#, "Unranked"),
        (#"(?<![A-Za-z])Main(?![A-Za-z])"#, "Ranked"),
        (#"(?<![A-Za-z])Division(?![A-Za-z])"#, "경쟁 구분"),
        (#"판돈"#, "경기 예치"),
    ]

    /// 서버에서 내려오는 과거 운영 용어를 사용자 화면에 그리기 직전 치환한다.
    /// 저장 키·API enum·랭킹 계산 규칙에는 적용하지 않는다.
    static func apply(_ text: String) -> String {
        replacements.reduce(text) { result, replacement in
            result.replacingOccurrences(
                of: replacement.0,
                with: replacement.1,
                options: [.regularExpression, .caseInsensitive]
            )
        }
    }

    static func mode(_ rawValue: String?) -> String {
        switch rawValue?.uppercased() {
        case "SUB": return "Unranked"
        case "MAIN": return "Ranked"
        default: return "미지정"
        }
    }

    static func ranking(_ rawValue: String?) -> String {
        let value = mode(rawValue)
        return value == "미지정" ? value : "\(value) 랭킹"
    }

    /// API와 저장소에는 안정적인 영문 티어 코드를 두되 화면에는 학생이 읽는 이름만
    /// 보인다. 서버가 이미 한국어 표시명을 내려준 경우에는 그대로 살린다.
    static func tier(_ rawValue: String?) -> String {
        let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        switch value.uppercased() {
        case "BRONZE": return "브론즈"
        case "SILVER": return "실버"
        case "GOLD": return "골드"
        case "PLATINUM": return "플래티넘"
        case "EMERALD": return "에메랄드"
        case "DIAMOND": return "다이아몬드"
        case "MASTER": return "마스터"
        case "GRANDMASTER": return "그랜드마스터"
        case "CHALLENGER": return "챌린저"
        default:
            if value.range(of: "[가-힣]", options: .regularExpression) != nil { return value }
            return value.isEmpty ? "티어 미발급" : "티어 확인 중"
        }
    }

    static func purchaseStatus(_ rawValue: String) -> String {
        switch rawValue.uppercased() {
        case "COMPLETED", "SUCCEEDED", "SUCCESS", "PAID", "PURCHASED", "APPLIED", "ACTIVE":
            return "완료"
        case "PENDING", "PROCESSING", "REQUESTED":
            return "처리 중"
        case "CANCELLED", "CANCELED":
            return "취소"
        case "FAILED", "REJECTED", "EXPIRED":
            return "처리 실패"
        default:
            return "확인 중"
        }
    }
}

// MARK: - 색

extension Color {
    /// #RRGGBB 리터럴로 색을 만든다. tokens.css 값을 그대로 옮기기 위한 것.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >>  8) & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// 라이트/다크 값을 함께 갖는 토큰.
/// SwiftUI 의 `Color(uiColor:)` + `UITraitCollection` 으로 시스템 외관을 따라간다.
private func adaptive(light: UInt32, dark: UInt32) -> Color {
    Color(uiColor: UIColor { traits in
        UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
    })
}

enum Tokens {

    // MARK: 팔레트 v4 — 공식 브랜드 (보라 → 파랑)
    //
    // 4차 개정. 사용자가 공식 로고를 확정했다: 보라→파랑 그라데이션 M + 스파클,
    // 근검정 바탕. 팔레트는 로고에서 그대로 뽑는다.
    //
    // 이력 메모: 2차 리디자인에서 "인디고·보라는 AI 기본값" 이라며 금지했던 계열이다.
    // 브랜드 확정은 사용자 결정이므로 그 금지는 브랜드 토큰에 한해 해제한다
    // (docs/디자인_차별화_조사.md 참조 — 토큰을 거치지 않은 생 보라는 여전히 금지).
    //   구조 = 학습 표면의 중립 유지 (쿨그레이로 전환)
    //   포인트 = 브랜드 바이올렛 (CTA), 로고 그라데이션은 브랜드 요소에만
    //   다크 모드 = 로고 원판의 근검정 #0A0A0E 바탕

    // MARK: 브랜드 원색 — **CI 가이드북이 진실원이다** (2026-08-06 격상)
    //
    // 값의 출처는 `MATTHS_CI_가이드북_스무딩_최종본`(2026.08, Master Logo Edition)
    // p.11 Color System — "제공 SVG 컬러 스와치에 실제 적용된 값" 이다.
    // 종전 진실원이던 웹 `matths-theme.css`(#d842ee·#7654f7·#3157f6·#19c7e9)는
    // 가이드북 확정 이전 값이라 이제 웹 쪽을 이 값으로 맞춰야 한다
    // (웹 동기화는 남은작업.md 참조 — 한쪽만 고치면 또 갈라진다).
    //   MAGENTA #CA44E3   VIOLET #7B4EFC
    //   BLUE    #327FFA   CYAN   #0CDCF1
    // 편집 요소 주조색은 마젠타·바이올렛, 블루·시안은 로고 그라데이션과
    // 기능성 포인트에 제한 사용한다(p.11 각주).
    static let brandMagenta = Color(hex: 0xCA44E3)
    static let brandViolet  = Color(hex: 0x7B4EFC)
    static let brandBlue    = Color(hex: 0x327FFA)
    static let brandCyan    = Color(hex: 0x0CDCF1)
    /// 공식 원색을 밝은 카드 위 작은 글자·아이콘에 그대로 쓰면 AA 대비가 부족하다.
    /// 색상 정체성은 유지하되 명도를 낮춘 on-surface 전용 잉크다.
    static let brandMagentaInk = adaptive(light: 0xA41BB5, dark: 0xF09AFA)
    static let brandCyanInk    = adaptive(light: 0x007D96, dark: 0x63E5FF)
    /// 웹 `--matths-navy`. GOAT Arena처럼 브랜드 대비가 필요한 한 개의 핵심 면에 쓴다.
    /// `paper`는 외관에 따라 바뀌지만 이 색은 로고 원판과 같은 고정 브랜드색이다.
    static let brandNavy    = Color(hex: 0x090C1B)
    // 예전 이름 — 호출부를 한 번에 못 고치므로 별칭으로 남긴다
    static let brandPurpleA = brandMagenta
    static let brandPurpleB = brandViolet
    static let brandBlueA   = brandCyan
    static let brandBlueB   = brandBlue
    /// 주 버튼·브랜드 면에 쓰는 로고 그라데이션.
    /// CI 가이드북 p.12 Gradient System — Magenta 0% → Violet 35% → Blue 70%
    /// → Cyan 100%. 임의 색상 추가·역방향 적용·불연속 밴딩 금지, 스톱 4개 고정.
    static var brandGradient: LinearGradient {
        LinearGradient(stops: [.init(color: brandMagenta, location: 0.00),
                               .init(color: brandViolet,  location: 0.35),
                               .init(color: brandBlue,    location: 0.70),
                               .init(color: brandCyan,    location: 1.00)],
                       startPoint: .leading, endPoint: .trailing)
    }
    /// 같은 4-스톱을 135° 대각으로 쓴 변형 (p.12 "M stroke: 135° diagonal").
    /// 3차 리디자인 전에는 주 버튼 밑판이 썼지만 버튼이 단색으로 바뀌며 손을 뗐다 —
    /// 이제 브랜드 모먼트의 대각 면(티어 배지 등) 전용이다. 뷰포트당 1회 규칙은 동일.
    static var brandGradientDeep: LinearGradient {
        LinearGradient(stops: [.init(color: brandMagenta, location: 0.00),
                               .init(color: brandViolet,  location: 0.35),
                               .init(color: brandBlue,    location: 0.70),
                               .init(color: brandCyan,    location: 1.00)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: 잉크 (텍스트) — 쿨그레이
    static let ink    = adaptive(light: 0x111426, dark: 0xEEF1FA)   // --matths-ink
    static let text1  = adaptive(light: 0x252B41, dark: 0xD7DCEA)
    static let text2  = adaptive(light: 0x4A5268, dark: 0xA6AEC2)
    /// --matths-muted. 2026-08-06 대비 보정(감사 고발 #1259·#0410):
    /// 종전 라이트 0x747D93 은 surface(0xFCFDFF) 위 4.05:1 로 AA(4.5:1) 미달이었다.
    /// 현행 실측 — 라이트 0x5C6478: surface 5.81:1 · paper 5.48:1 · paper2 5.10:1,
    ///            다크 0x8A94AB: surface(0x141A2E) 5.67:1 · navy(0x090C1B) 6.39:1.
    /// 세 면 전부 AA 통과. ⚠️ 웹 tokens.css 의 --matths-muted 도 같이 바꿔야 한다
    /// (파일 서두 규칙 — 웹 동기화는 이 웨이브 범위 밖, 감독 확인 요망).
    static let text3  = adaptive(light: 0x5C6478, dark: 0x8A94AB)   // --matths-muted
    /// ⚠️ 용도 못박기(감사 #0409·#0410): text4 는 placeholder·비활성 전용이다.
    /// 실측 라이트 2.54:1 — AA 미달이 허용되는 건 "읽지 않아도 되는" 텍스트뿐.
    /// 증감 추이·진도 수처럼 실제 데이터인 메타 텍스트는 text3 이상을 쓴다.
    static let text4  = adaptive(light: 0x99A1B4, dark: 0x5F687C)

    // MARK: 면 — 라이트는 흰 카드, 다크는 로고 원판의 근검정
    // 순수 #FFF 는 쓰지 않는다. 카드가 화면의 60%를 덮는데 그 면이 최대 휘도면
    // 오래 보는 눈이 먼저 지치고, 심사 리뷰로도 잡히는 항목이다(전체구조.md 함정 6).
    // 한 끗 낮춘 쿨 화이트 — paper(#F6F6FA)와 같은 계열이라 카드 경계는 그대로 산다.
    static let surface = adaptive(light: 0xFCFDFF, dark: 0x141A2E)   // --matths-surface
    static let paper   = adaptive(light: 0xF3F6FF, dark: 0x090C1B)   // --matths-canvas / --matths-navy
    static let paper2  = adaptive(light: 0xE9EEFC, dark: 0x12162B)   // --matths-navy-soft

    // MARK: 선
    static let line       = adaptive(light: 0xE3E8F4, dark: 0x232A44)   // --matths-line
    static let lineStrong = adaptive(light: 0xC9D2E6, dark: 0x333D5E)

    // MARK: 역할별 인터랙션 색
    // 다크 모드에서는 근검정 바탕 위 대비를 위해 밝은 톤으로 올린다.
    // ⚠️ 이 값은 `Assets.xcassets/AccentColor.colorset` 과 **반드시 같아야 한다.**
    // MatthsApp 의 `.tint(Tokens.primary)` 가 닿지 않는 곳 — 스크린샷 가드 오버레이,
    // UIImagePicker/PHPicker, WKWebView 의 텍스트 선택 핸들 — 은 에셋 accent 로 그려진다.
    // 한쪽만 고치면 그 화면들만 다른 색이 된다(실제로 그랬다, 2026-07-30).
    /// 화면의 주 행동. 버튼·확정 CTA 이외의 진행 표시에 쓰지 않는다.
    static let actionPrimary = adaptive(light: 0x7B4EFC, dark: 0x9A7BFF)
    static let actionPrimaryPressed = brandVioletDeep
    /// 학습 진도·선택·기능 상태. 주 CTA 색과 분리한다.
    static let progressBlue = adaptive(light: 0x327FFA, dark: 0x7E9BFF)
    /// GOAT Arena 네이비 면의 유일한 구조 액센트.
    static let arenaAccent = brandCyan
    /// 기존 호출부 호환 별칭. 새 코드는 역할 이름을 직접 사용한다.
    static let primary     = progressBlue
    static let onPrimary   = adaptive(light: 0xFBFCFF, dark: 0x081231)
    /// 눌린 버튼 · 두툼한 버튼의 아랫단
    static let primaryDark = adaptive(light: 0x2563D6, dark: 0x5A7CEE)
    static let primarySoft = adaptive(light: 0xE8EDFF, dark: 0x14203F)   // 웹 --blue-soft 계열

    // MARK: 상태
    // 오답의 기본색은 앰버. 빨강은 "오늘 반드시 처리할 것" 전용으로 복귀
    // (v3 에서 브랜드가 빨강이라 겸용했던 것을 분리).
    static let success     = adaptive(light: 0x1E9E5A, dark: 0x3FBE7D)
    static let successSoft = adaptive(light: 0xE3F4EB, dark: 0x12241B)
    static let warning     = adaptive(light: 0xD98A0F, dark: 0xE8A63C)
    static let warningSoft = adaptive(light: 0xFCF2DD, dark: 0x2A2112)
    static let danger      = adaptive(light: 0xE0344A, dark: 0xF26D7E)
    static let dangerSoft  = adaptive(light: 0xFDE8EB, dark: 0x331318)
    /// 상태 원색은 면 채움용, 아래 두 색은 작은 상태 문구와 아이콘용이다.
    /// 라이트·다크 양쪽에서 일반 텍스트 4.5:1 이상을 확보한다.
    static let successInk  = adaptive(light: 0x117744, dark: 0x74D9A1)
    static let warningInk  = adaptive(light: 0x8A5800, dark: 0xFFD27A)
    static let dangerInk   = adaptive(light: 0xB3202F, dark: 0xFF9AA7)

    // MARK: 채점·보상 시맨틱
    //
    // 위의 success/warning/danger 는 일반 UI 상태(복습 배지·마감 경고)용이고,
    // 아래 셋은 "문제를 풀었다" 순간 전용이다. 채점 결과는 학생이 하루에 수백 번
    // 보는 색이라 일반 상태색과 분리해 더 또렷한 값으로 잡는다.
    // ⚠️ 색만으로 정오답을 전하지 않는다 — 색+아이콘+문구 삼중이 규칙이다(색약 학생).
    static let correctGreen = adaptive(light: 0x16A34A, dark: 0x30D158)
    static let incorrectRed = adaptive(light: 0xDC2626, dark: 0xFF453A)
    /// 보상 골드 — 외관 불변 고정색. 스트릭·티어·완료 축하 같은 보상 모먼트 전용.
    /// 경고(warning)와 색이 비슷하니 상태 표시로 오용하지 않는다.
    static let rewardGold   = Color(hex: 0xF59E0B)
    /// brandNavy 히어로 면 위의 승격 레이어 — 한 단계 밝은 네이비 고정색.
    /// 네이비 안에서는 그림자 대신 이 층으로 깊이를 만들고, 포인트는 brandCyan 만 쓴다
    /// (네이비 위 마젠타·바이올렛 금지).
    static let navyElevated = Color(hex: 0x131730)

    // MARK: 브랜드 면 위 글자·압출
    /// 브랜드 면(바이올렛 버튼·네이비 히어로) 위 글자 — 크림 화이트, 외관 불변.
    /// 뷰에서 생 hex 를 못 쓰므로 버튼 글자색이던 #FDFCFF 를 토큰으로 승격했다.
    static let onBrand = Color(hex: 0xFDFCFF)
    /// 네이비 히어로 면 위 잉크 — 외관 불변 고정색(네이비 자체가 고정색이라서).
    /// 3개 파일(RankArena·GoatArena·GoatArenaRulebook)에 생 hex 로 복붙되어 있던
    /// 0xF4F6FF 를 정식 승격했다(감사 #1803 — v3/v4 분열 사고의 재현 조건 차단).
    /// 실측: brandNavy(0x090C1B) 위 18.0:1 · navyElevated(0x131730) 위 16.3:1.
    static let onNavy = Color(hex: 0xF4F6FF)
    /// 네이비 면 위 경고 잉크 — GoatArenaScreen 이 6곳에서 생 hex 로 쓰던 앰버의 승격.
    /// 네이비 면 색 규칙 명문화(감사 #1801): **강조(액센트)는 brandCyan 하나뿐이다.**
    /// warnOnNavy 는 액센트가 아니라 경고 시맨틱 전용 — 마감·주의 "문구와 아이콘"에만
    /// 쓰고, 테두리·아이브로우 같은 구조 강조에 쓰지 않는다(그건 시안의 자리).
    /// 네이비 위 마젠타·바이올렛 금지는 종전대로다(navyElevated 주석 참조).
    /// 실측: brandNavy 위 13.97:1 · navyElevated 위 12.6:1 — AA 여유 통과.
    static let warnOnNavy = Color(hex: 0xFFD66B)
    /// brandViolet 압출(밑판) 색 — 같은 색상에서 명도만 약 20% 낮춘 값.
    /// 그라데이션+검정 셰이드로 밑판을 만들던 방식을 버리고 단색 두 장으로 간다.
    static let brandVioletDeep = Color(hex: 0x6340CA)

    // MARK: 스페이싱 — 4pt 그리드
    enum Space {
        static let s1: CGFloat = 4,  s2: CGFloat = 8,  s3: CGFloat = 12
        static let s4: CGFloat = 16, s5: CGFloat = 20, s6: CGFloat = 24
        /// 화면 섹션 사이 전용 — 20pt 는 iPad 에서 "따닥따닥" 하다는 실사용 피드백으로 승격
        static let s7: CGFloat = 28
        static let s8: CGFloat = 32, s10: CGFloat = 40, s14: CGFloat = 56
    }

    // MARK: 반경
    enum Radius {
        // 웹 --matths-radius 18px · --matths-radius-lg 24px 에 맞춘다.
        static let sm: CGFloat = 8,  md: CGFloat = 12, lg: CGFloat = 18
        static let xl: CGFloat = 24, pill: CGFloat = 999
    }

    // MARK: 레이아웃
    //
    // 사이드바 폭 토큰은 없다. 셸이 하단 탭바로 바뀌면서 사이드바를 버렸다.
    // (이유는 RootView.swift 맨 위에 적어 두었다.)
    // 남겨 두면 누군가 다시 사이드바를 만들 근거로 쓰게 된다.

    /// 본문 최대 폭. 13인치 가로(1366pt)에서 한 줄이 너무 길어지는 것을 막는다.
    static let readableWidth: CGFloat = 900
}

// MARK: - 타이포
//
// pt 를 박지 않고 텍스트 스타일을 기준으로 잡는다.
// 그래야 Dynamic Type(설정 > 손쉬운 사용 > 글자 크기)을 따라간다 —
// 앱스토어 심사에서 접근성으로 보는 항목이고, 무엇보다 눈이 나쁜 학생이 쓴다.

extension Font {
    /// 텍스트 스타일 기준 시스템 폰트.
    ///
    /// 예전 구현은 `relativeTo` 를 인자로만 받고 본문에서 `.system(size:)` 를 돌려줬다.
    /// 그 표현식은 글자 크기를 xSmall→accessibility5 로 끝까지 올려도 렌더 크기가
    /// 1pt 도 변하지 않는다(시뮬 실측). 즉 이 파일 전체가 Dynamic Type 밖에 있었다.
    ///
    /// 스케일은 스타일에 맡긴다. SwiftUI 에는 "절대 pt + 스케일" 을 함께 주는
    /// 시스템 폰트 API 가 없고, `.custom(_:size:relativeTo:)` 는 이름을 못 찾으면
    /// 시스템 서체가 아닌 대체 서체로 떨어져 앱 전체 서체가 바뀐다.
    /// 대신 기준 크기가 기존 pt 와 같은 스타일만 골라 써서 기본 화면은 그대로 둔다.
    static func matths(_ style: Font.TextStyle, _ weight: Font.Weight) -> Font {
        .system(style, design: .default, weight: weight).leading(.standard)
    }

    // 주석의 pt 는 글자 크기 기본값(Large)에서의 크기 — 종전 고정값과 같다.
    static let mDisplay = matths(.largeTitle,  .heavy)     // 34
    static let mTitle   = matths(.title,       .heavy)     // 28
    static let mHeading = matths(.title2,      .bold)      // 22
    static let mBody    = matths(.body,        .regular)   // 17
    static let mBodyB   = matths(.body,        .semibold)  // 17
    // 15·13 을 지키려고 .callout(16)·.caption(12) 이 아니라
    // 기준 크기가 똑같은 .subheadline·.footnote 를 쓴다.
    static let mCallout = matths(.subheadline, .regular)   // 15
    static let mCaption = matths(.footnote,    .semibold)  // 13
    static let mMicro   = matths(.caption2,    .heavy)     // 11

    /// 점수·타이머·진도율 — 자리가 흔들리면 안 되는 숫자
    static let mNumeric = Font.system(.body, design: .rounded).monospacedDigit()

    /// 강조 숫자 — 점수·순위·문항수.
    /// 세리프(2차)는 문서처럼 읽혀서 뺐다. 라운디드 굵은 숫자로
    /// 점수·순위·문항 수를 빠르게 구분한다.
    ///
    /// ⚠️ 이 함수는 Dynamic Type 밖이다(고정 pt). 감사 #1253 —
    /// "캡션은 커지는데 주 정보 숫자는 얼어 있어 위계가 역전된다."
    /// 새 코드는 아래 mStat/mStatLarge(스타일 기반, 스케일됨)를 쓰고,
    /// 이 함수는 좌표계가 깨지는 곳(맵 노드·차트처럼 .dynamicTypeSize 캡을
    /// 이미 건 컨테이너)과 스플래시 전용으로 남긴다.
    static func stat(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    // 고정 pt(stat)에서 텍스트 스타일 기반으로 교체 — 기본(Large)에서는 종전과
    // 같은 22·34pt 로 렌더되고, 접근성 글자 크기에서 캡션과 함께 스케일된다.
    // (매핑 근거: .title2 기본 22pt, .largeTitle 기본 34pt — 감사 #1253 처방.)
    static let mStat      = Font.system(.title2,     design: .rounded, weight: .heavy)   // 22
    static let mStatLarge = Font.system(.largeTitle, design: .rounded, weight: .heavy)   // 34
}

// MARK: - 구획선

/// 화면 제목 아래의 단일 구획선. 이중 괘선은 모든 화면을 인쇄물처럼 보이게 하고
/// 제목 높이를 불필요하게 키워, 네이티브 화면에서는 한 줄만 사용한다.
struct ExamRule: View {
    var color: Color = Tokens.ink
    var body: some View {
        Rectangle()
            .fill(color.opacity(0.48))
            .frame(height: 1)
        .accessibilityHidden(true)
    }
}

/// 답안지 점선 구분선. 항목 사이를 카드 없이 나눈다.
struct DottedRule: View {
    var body: some View {
        HairlineShape()
            .stroke(Tokens.lineStrong, style: StrokeStyle(lineWidth: 1, dash: [1.5, 4]))
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

/// 섹션 제목 + 괘선. "단계별 채점 ────" 형태.
struct SectionRule: View {
    let title: String
    var body: some View {
        HStack(spacing: Tokens.Space.s3) {
            Text(title).font(.mCaption).foregroundStyle(Tokens.text3)
                .layoutPriority(1)
            Rectangle().fill(Tokens.line).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct HairlineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return p
    }
}

/// 수능 원문자(①②③) — 단계 번호. 세리프 숫자에 가는 원 테두리.
struct CircledNumber: View {
    let n: Int
    var color: Color = Tokens.text2
    var body: some View {
        Text("\(n)")
            .font(Font.stat(14, .semibold))
            .foregroundStyle(color)
            .frame(width: 25, height: 25)
            .overlay(Circle().strokeBorder(color, lineWidth: 1.2))
            .accessibilityLabel("\(n)단계")
    }
}

// MARK: - 컴포넌트

struct CardModifier: ViewModifier {
    var padding: CGFloat = Tokens.Space.s6   // 20→24: 카드 안 요소가 숨 쉬게
    func body(content: Content) -> some View {
        // 학습 표면: 테두리 없는 흰 카드 + 아주 옅은 그림자.
        // 1.5pt 테두리 카드는 화면을 와이어프레임처럼 보이게 했다.
        content
            .padding(padding)
            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
            // 그림자 색은 v3 웜 잉크(#1F1B16)가 남아 있었다 — 쿨그레이 v4 잉크로 맞춘다.
            .shadow(color: Color(hex: 0x17171F).opacity(0.055), radius: 9, y: 2)
    }
}

extension View {
    /// 기본 여백 24 — 호출부가 인자를 안 주면 이 값이 쓰인다.
    /// (CardModifier 의 기본값만 24 로 올렸다가 여기가 20 이라 전 화면이 그대로였던 이력)
    func card(padding: CGFloat = Tokens.Space.s6) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

/// 화면당 하나만 쓰는 주 버튼. 선택지를 늘리지 않는 것이 이 앱의 원칙이다.
///
/// Matths 두툼한 행동 버튼(퍽 프레스) — 단색 바이올렛 윗판 아래로 같은 색상의
/// 어두운 밑판이 3pt 비쳐서 물리 버튼처럼 보이고, 누르면 그 두께만큼 내려앉는다.
///
/// 3차 리디자인에서 그라데이션 윗판을 뺐다. CI 그라데이션은 뷰포트당 1회,
/// 브랜드 모먼트(마크·티어·축하) 전용이라는 규율 때문이다 — 화면마다 있는
/// 주 버튼이 그라데이션이면 그 규율이 처음부터 성립하지 않는다.
/// 블러 그림자도 없다: 인터랙티브 요소의 깊이는 하드 엣지(밑판)로만 표현한다.
struct ExtrudedButtonStyle: ButtonStyle {
    // 모션 게이트 — 앱의 주 버튼 18개 호출부가 전부 이 스타일을 쓰는데,
    // 여기만 게이트가 없어 '화면 모션' 을 꺼도 시스템 '동작 줄이기' 를 켜도
    // 눌림 애니메이션이 계속 돌았다(PressScaleStyle 에만 걸려 있었다, 감사 적발).
    // EnvironmentObject 는 ButtonStyle 에서 못 쓴다. AppStore.motionOn 이
    // 저장되는 같은 키를 직접 읽어 규칙 1(스위치는 하나)을 지킨다.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let userMotion = UserDefaults.standard.object(forKey: "matths.motion") as? Bool ?? true
        let motionOn = userMotion && !reduceMotion
        return configuration.label
            .font(.mBodyB)
            .foregroundStyle(isEnabled ? Tokens.onBrand : Tokens.text4)
            .frame(maxWidth: .infinity, minHeight: 52)   // 최소 터치 타겟 44pt 초과
            .background(
                ZStack {
                    // 밑판(압출) — brandViolet 과 같은 색상, 명도만 낮춘 고정 토큰
                    RoundedRectangle(cornerRadius: Tokens.Radius.md)
                        .fill(isEnabled ? Tokens.actionPrimaryPressed : Tokens.lineStrong)
                    RoundedRectangle(cornerRadius: Tokens.Radius.md)
                        .fill(isEnabled ? Tokens.actionPrimary : Tokens.line)
                        .padding(.bottom, isEnabled ? (pressed ? 0.5 : 3) : 0)
                }
            )
            .offset(y: isEnabled && pressed ? 2.5 : 0)
            .opacity(isEnabled ? 1 : 0.82)
            .animation(motionOn ? .easeOut(duration: 0.09) : nil, value: pressed)
    }
}

/// 기존 이름 — 호출부 40여 곳이 이 이름을 쓰므로 별칭으로 유지한다.
/// 새 코드는 어느 쪽을 써도 같은 단색 바이올렛 퍽 버튼이다.
typealias PrimaryButtonStyle = ExtrudedButtonStyle

/// 2.5D 접지 그림자 — 오브젝트 발밑에 깔리는 납작한 타원.
///
/// 블러 그림자 금지 규칙(인터랙티브 요소)의 우회가 아니라 역할 분담이다:
/// 버튼의 깊이는 하드 엣지 밑판이, 공중에 뜬 장식 오브젝트(맵 노드·마스코트)의
/// "바닥에 서 있음" 은 이 타원이 맡는다. 오브젝트 폭을 받아 비율로 그린다.
struct ContactShadow: View {
    /// 위에 얹히는 오브젝트의 폭 — 타원은 그 80% 폭으로 깔린다.
    var width: CGFloat

    var body: some View {
        Ellipse()
            .fill(Color.black.opacity(0.12))
            .frame(width: width * 0.8, height: width * 0.8 * 0.32)
            .blur(radius: 2)   // 접지감을 위한 최소 블러 — 이 이상 키우지 않는다
            .accessibilityHidden(true)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.mBodyB)
            .foregroundStyle(isEnabled ? Tokens.text1 : Tokens.text4)
            .padding(.horizontal, Tokens.Space.s5)
            .frame(minHeight: 44)
            .background(isEnabled ? Tokens.surface : Tokens.line, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.md)
                    .strokeBorder(isEnabled && configuration.isPressed ? Tokens.lineStrong : Tokens.line, lineWidth: 1.5)
            )
    }
}

/// 복습 상태 배지 — 대기 / 예정 / 완료
struct ReviewBadge: View {
    enum State { case pending, due, mastered

        var label: String {
            switch self {
            case .pending:  return "복습 대기"
            case .due:      return "복습 예정"
            case .mastered: return "복습 완료"
            }
        }
        /// 글자·아이콘용 잉크. 상태 "원색"(warning·success)은 면 채움용이라
        /// 흰 카드 위 11pt 글자로는 AA 미달이었다(감사 #0410 — warning 2.72:1).
        /// 토큰 파일 자신의 규정("문구·아이콘은 warningInk/successInk")대로 교체.
        /// 실측: warningInk 라이트 5.93:1 · successInk 5.51:1 (surface 위).
        var fg: Color {
            switch self {
            case .pending:  return Tokens.text3
            case .due:      return Tokens.warningInk
            case .mastered: return Tokens.successInk
            }
        }
        /// 상태 점(dot) 전용 — 점은 글자가 아니라 면이므로 채도 높은 원색을 유지한다.
        /// (색만으로 상태를 전하지 않는다 — 옆의 글자 레이블이 항상 함께 간다.)
        var dot: Color {
            switch self {
            case .pending:  return Tokens.text3
            case .due:      return Tokens.warning
            case .mastered: return Tokens.success
            }
        }
        var bg: Color {
            switch self {
            case .pending:  return Tokens.paper2
            case .due:      return Tokens.warningSoft
            case .mastered: return Tokens.successSoft
            }
        }
    }

    let state: State
    var text: String? = nil

    // 알약(캡슐) 배지를 쓰지 않는다. 화면마다 알약이 서너 개씩 떠 있는 것이
    // AI 로 만든 화면의 전형이고, 상태 표시는 점 하나와 글자로 충분하다.
    // 점의 색이 곧 상태다 — 대기(회색) / 예정(호박) / 완료(초록).
    // 점은 원색(dot), 글자는 대비 확보 잉크(fg)로 역할을 나눈다.
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(state.dot).frame(width: 6, height: 6)
            Text(text ?? state.label).font(.mMicro).foregroundStyle(state.fg)
        }
        .accessibilityElement(children: .combine)
    }
}

/// 진행률
struct ProgressBar: View {
    var value: Double            // 0...1
    var tint: Color = Tokens.primary
    var track: Color = Tokens.paper2

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(tint)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityLabel("진행률")
        .accessibilityValue("\(Int(value * 100))퍼센트")
    }
}
