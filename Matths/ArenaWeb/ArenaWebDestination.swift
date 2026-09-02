//  ArenaWebDestination.swift
//  Matths
//
//  아레나 웹 브리지가 열 수 있는 **목적지 표**.
//
//  왜 표가 따로 있나. 앱용 Bearer API 는 아레나를 **읽기 전용 4개**(스냅샷·룰북·
//  경기 목록·경기 1건)로만 열어 준다. 도전 걸기·초대 응답·상점 구매·우편함·증빙 제출·
//  페이백 계좌 확인 같은 **조작**은 서버에 세션(쿠키) 웹 라우트로만 있고, 서버는
//  우리가 고치지 않는다. 그래서 앱이 그 기능들을 갖는 유일한 방법은 로그인이 이어진
//  웹뷰로 **그 페이지 자체**를 여는 것이다(게시판이 이미 그렇게 살아 있다).
//
//  이 파일은 "어디를 여는가" 만 안다. 어떻게 로그인을 잇는지는 ArenaWebModel,
//  무엇을 그리는지는 ArenaWebScreen 이 맡는다.
//
//  경로는 origin/main 의 routes/goat-arena-routes.js 를 그대로 옮긴 것이다.
//  경로 문자열을 화면 여기저기에 직접 쓰지 않는 이유: 서버가 경로를 바꾸면
//  고칠 곳이 이 파일 하나여야 한다.
//
//  **문구 규칙**: title 은 웹 상단 메뉴(홈·티어 순위·UNRANKED·RANKED·상점·경기 규정)의
//  이름을 그대로 쓴다. 아레나 규칙·정산·페이백 설명을 앱에서 새로 쓰지 않는다 —
//  그 설명은 웹 페이지가 이미 정본으로 갖고 있고, 두 벌이 되는 순간 갈린다.

import Foundation

enum ArenaWebDestination: Hashable {
    /// GOAT Arena 시작 페이지. 웹 상단 HUD(홈·티어 순위·UNRANKED·RANKED·상점·규정·
    /// 우편함·프로필)가 여기서부터 모든 조작으로 이어진다 — 기본 진입점이다.
    case home
    /// 티어 순위표
    case rankings
    /// Unranked 전장 (서버 segment 코드 SUB)
    case unranked
    /// Unranked 도전 만들기
    case unrankedChallenge
    /// Ranked 전장 (서버 segment 코드 MAIN)
    case ranked
    /// Ranked 대전 준비 — 상향 도전·하위 초대·친선 초대가 모두 이 페이지에 있다
    case rankedBattle
    /// Ranked 상점
    case shop
    /// 상점에서 산 분석 아이템의 결과 페이지
    case shopAnalysis(effectId: String)
    /// Unranked 공식 규정
    case rulesUnranked
    /// Ranked 공식 규정
    case rulesRanked
    /// Arena 프로필 (페이백 계좌 확인·검토가 여기 있다)
    case profile
    /// 우편함 (경기 알림 · 전체 읽음)
    case mailbox
    /// 우편함 알림 1건
    case mailboxItem(notificationId: String)
    /// 경기 1건 — 준비·시작·풀이·증빙 제출이 모두 이 페이지 안에서 일어난다
    case match(matchId: String)
    /// 경기 보강 증빙 제출
    case matchSupplementalEvidence(matchId: String)
    /// segment 별 기능 상세 페이지 (/goat-arena/:segment/features/:featureKey)
    case feature(segment: Division, key: String)
    /// 표에 없는 아레나 경로를 열어야 할 때의 탈출구.
    /// 모델이 /goat-arena 로 시작하는지 다시 확인하므로 임의 주소로는 못 간다.
    case custom(path: String, title: String)

    enum Division: String, Hashable {
        case unranked = "sub"
        case ranked = "main"
    }

    /// `/goat-arena` 경로 트리의 정확한 소유권 검사. 단순 hasPrefix는
    /// `/goat-arena-admin` 같은 다른 서버 표면까지 아레나 브리지로 받아 버린다.
    static func owns(path: String) -> Bool {
        path == "/goat-arena" || path.hasPrefix("/goat-arena/")
    }

    // MARK: 경로

    var path: String {
        switch self {
        case .home:                 return "/goat-arena"
        case .rankings:             return "/goat-arena/rankings"
        case .unranked:             return "/goat-arena/sub"
        case .unrankedChallenge:    return "/goat-arena/sub/challenge"
        case .ranked:               return "/goat-arena/main"
        case .rankedBattle:         return "/goat-arena/main/battle"
        case .shop:                 return "/goat-arena/main/shop"
        case .shopAnalysis(let id): return "/goat-arena/main/shop/analyses/\(Self.escape(id))"
        case .rulesUnranked:        return "/goat-arena/rules/sub"
        case .rulesRanked:          return "/goat-arena/rules/main"
        case .profile:              return "/goat-arena/profile"
        case .mailbox:              return "/goat-arena/mailbox"
        case .mailboxItem(let id):  return "/goat-arena/mailbox/\(Self.escape(id))"
        case .match(let id):        return "/goat-arena/matches/\(Self.escape(id))"
        case .matchSupplementalEvidence(let id):
            return "/goat-arena/matches/\(Self.escape(id))/supplemental-evidence"
        // 이 값은 서버 URL 경로 성분(sub|main)이다. 브랜드 용어 계약(run-brand-contract)이
        // 브랜드 금칙어(경쟁 구분의 영문명)를 사용자 문자열에서 막는데, URL 리터럴도 같은 검사에 걸린다.
        // 검사를 느슨하게 푸는 대신 이름을 경로 성분답게 바꿔 계약을 그대로 지킨다.
        case .feature(let segment, let key):
            return "/goat-arena/\(segment.rawValue)/features/\(Self.escape(key))"
        case .custom(let path, _):  return path
        }
    }

    /// 경기 id·알림 id 는 서버가 준 문자열이다. 그대로 붙이면 슬래시 하나로 다른
    /// 경로가 만들어질 수 있으므로 경로 성분으로 인코딩한다.
    private static func escape(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(
            CharacterSet(charactersIn: "-._~"))) ?? value
    }

    // MARK: 표시

    /// 네이티브 셸의 제목. 웹 상단 메뉴 이름과 같은 말을 쓴다 —
    /// 앱에서 부르는 이름과 웹 페이지의 이름이 다르면 학생은 같은 곳인지 모른다.
    var title: String {
        switch self {
        case .home:                 return "GOAT Arena"
        case .rankings:             return "티어 순위"
        case .unranked:             return "UNRANKED"
        case .unrankedChallenge:    return "UNRANKED 도전"
        case .ranked:               return "RANKED"
        case .rankedBattle:         return "RANKED 대전"
        case .shop:                 return "상점"
        case .shopAnalysis:         return "분석 결과"
        case .rulesUnranked:        return "UNRANKED 규정"
        case .rulesRanked:          return "RANKED 규정"
        case .profile:              return "Arena 프로필"
        case .mailbox, .mailboxItem: return "우편함"
        case .match:                return "경기"
        case .matchSupplementalEvidence: return "보강 증빙"
        case .feature:              return "GOAT Arena"
        case .custom(_, let title): return title
        }
    }

    /// 경기 화면은 문항이 그대로 보이는 평가면이다. 앱의 네이티브 경기 화면
    /// (GoatArenaMatchPlayScreen)이 화면 보호를 받는데 웹으로 연 같은 경기가
    /// 무방비면, 보호는 "앱에서만 지키는 규칙" 이 되어 의미가 없다.
    var isProtectedAssessmentSurface: Bool {
        switch self {
        case .match, .matchSupplementalEvidence: return true
        default: return false
        }
    }

    /// 화면 보호 감사 이벤트에 남는 표면 이름.
    var protectionSurfaceName: String { "goat-arena-web" }

    // MARK: 딥링크 (matths://arena-web/<key>[/<id>])

    /// 딥링크·디버그 실행인자가 쓰는 짧은 이름. 목적지를 늘리면 여기도 같이 늘린다.
    var deepLinkKey: String {
        switch self {
        case .home:                 return "home"
        case .rankings:             return "rankings"
        case .unranked:             return "unranked"
        case .unrankedChallenge:    return "unranked-challenge"
        case .ranked:               return "ranked"
        case .rankedBattle:         return "ranked-battle"
        case .shop:                 return "shop"
        case .shopAnalysis:         return "shop-analysis"
        case .rulesUnranked:        return "rules-unranked"
        case .rulesRanked:          return "rules-ranked"
        case .profile:              return "profile"
        case .mailbox:              return "mailbox"
        case .mailboxItem:          return "mailbox-item"
        case .match:                return "match"
        case .matchSupplementalEvidence: return "supplemental-evidence"
        case .feature:              return "feature"
        case .custom:               return "custom"
        }
    }

    /// `matths://arena-web/mailbox` · `matths://arena-web/match/<matchId>` 같은 주소와
    /// 디버그 실행인자 `-arenaWeb match/<matchId>` 가 같은 파서를 쓴다.
    /// 모르는 이름이면 nil 을 돌려준다 — 임의 문자열이 경로가 되면 안 된다.
    static func parse(_ value: String) -> ArenaWebDestination? {
        let parts = value
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        guard let key = parts.first?.lowercased() else { return nil }
        let argument = parts.count > 1 ? parts[1] : nil
        switch key {
        case "home", "":            return .home
        case "rankings":            return .rankings
        case "unranked", "sub":     return .unranked
        case "unranked-challenge":  return .unrankedChallenge
        case "ranked", "main":      return .ranked
        case "ranked-battle", "battle": return .rankedBattle
        case "shop":                return .shop
        case "shop-analysis":       return argument.map { .shopAnalysis(effectId: $0) }
        case "rules-unranked":      return .rulesUnranked
        case "rules-ranked":        return .rulesRanked
        case "rules":               return .rulesUnranked
        case "profile":             return .profile
        case "mailbox":             return argument.map { .mailboxItem(notificationId: $0) } ?? .mailbox
        case "match":               return argument.map { .match(matchId: $0) }
        case "supplemental-evidence":
            return argument.map { .matchSupplementalEvidence(matchId: $0) }
        case "feature":
            guard parts.count > 2, let segment = Division(rawValue: parts[1].lowercased()) else {
                return nil
            }
            return .feature(segment: segment, key: parts[2])
        default:                    return nil
        }
    }

    /// 화면·디버그 목록에 쓸 기본 목적지들. 웹 상단 HUD 의 메뉴 순서와 같다.
    static let hudDestinations: [ArenaWebDestination] = [
        .home, .rankings, .unranked, .ranked, .shop, .rulesUnranked, .mailbox, .profile,
    ]
}
