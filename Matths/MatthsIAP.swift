//  MatthsIAP.swift
//  Matths
//
//  App Store 인앱 결제 — StoreKit 2.
//
//  ■ 왜 이 파일이 생겼는가
//
//  지금까지 결제는 웹 한 갈래였다. 앱은 /api/v1/commerce/handoffs 로 2분짜리 일회용 URL 을
//  받아 SFSafariViewController 로 토스 결제창을 열었다(CommerceHubScreen). 그 구조는 iOS 에서
//  **심사지침 3.1.1 정면 위반**이다 — 앱 안에서 쓰는 디지털 콘텐츠는 인앱 결제로만 팔 수 있다.
//  그래서 iOS 빌드에서는 웹 결제 경로를 닫고 이 파일이 그 자리를 대신한다.
//  (웹 브라우저에서 토스로 결제하는 길은 그대로 살아 있다. 막는 것은 iOS 앱 안에서일 뿐이다.)
//
//  ■ 왜 상품 유형에 의존하지 않는가
//
//  자동갱신 구독으로 낼지 비갱신 구독으로 낼지는 App Store Connect 에서 정하는 값이고
//  아직 확정되지 않았다. 다행히 **구매 흐름은 두 유형이 같다**:
//      상품 조회 → 구매 → 서명 검증 → 서버에 JWS 전달 → 서버가 권한 부여 → finish()
//  달라지는 것은 서버가 만료를 어떻게 계산하느냐뿐이다(자동갱신이면 애플의 expiresDate 를
//  그대로 쓰고, 비갱신이면 서버가 29일을 센다). 그래서 이 파일은 유형을 묻지 않는다.
//
//  ■ finish() 를 언제 부르는가 — 이 파일에서 가장 중요한 규칙
//
//  **서버가 권한을 준 뒤에만** finish() 한다. 먼저 finish() 하면 애플은 그 거래를 완료로 보고
//  다시 주지 않는다. 그 사이 서버 호출이 실패하면 학생은 돈을 냈는데 학습권이 없고,
//  복구할 근거도 사라진다. 반대로 finish() 를 늦게 하면 애플이 계속 재전달해 줄 뿐이라
//  손해가 없다. 그래서 실패 시 finish() 하지 않고 남겨 둔다 — 다음 실행 때 재시도한다.
//
//  ■ Transaction.updates 리스너가 왜 필수인가
//
//  구매가 purchase() 의 반환값으로만 오지 않는다. 다음은 전부 앱이 구매 화면을 떠난 **뒤에** 온다:
//    · **구입 요청(Ask to Buy)** — 부모가 나중에 승인한다. 우리 사용자층이 고등학생이라
//      이 경로가 예외가 아니라 일상이다. 리스너가 없으면 승인이 나도 앱은 모른다.
//    · 자동갱신 구독의 갱신
//    · 다른 기기에서 한 구매
//    · 애플이 처리한 환불·취소(revocationDate)
//  그래서 앱 실행 직후부터 리스너를 띄우고 앱이 사는 내내 유지한다.
//
//  ■ appAccountToken 을 왜 붙이는가
//
//  서버는 App Store Server Notifications V2 를 **세션 없이** 받는다. 환불 통지가 왔을 때
//  "이게 누구 거래인가"를 알아야 학습권을 회수할 수 있다. 방법이 둘인데 둘 다 쓴다:
//    ① appAccountToken — 구매 시 우리가 심는 UUID. 거래와 통지에 그대로 실려 돌아온다.
//    ② 서버가 redeem 시점에 originalTransactionId → userId 를 저장.
//  ②만 있으면 redeem 호출이 서버에 닿지 못한 거래를 영영 못 찾는다. ①이 그 구멍을 막는다.
//
//  ■ 서버에 필요한 것 (코덱스 담당)
//
//      POST /api/v1/commerce/apple/redeem     (Bearer)
//        body: { jws, productCode, appAccountToken }
//        · jws 를 애플 루트 인증서로 검증(서명·bundleId·environment)
//        · productCode 를 신뢰하지 말 것 — **JWS 안의 productId 가 진실원**이다.
//          body 의 productCode 는 로깅·대조용이다.
//        · originalTransactionId 로 멱등 처리(같은 거래가 여러 번 와도 사이클 하나)
//        · AccessCycle 생성 후 { granted: true, ... } 반환
//      POST /api/v1/commerce/apple/notifications   (애플 → 서버, 인증 없음)
//        · ASSN V2. REFUND / REVOKE / DID_RENEW / EXPIRED 처리
//
//  이 두 경로가 없으면 결제는 되지만 학습권이 안 열린다.

import Foundation
import StoreKit

// MARK: - 상품 정의

/// App Store Connect 의 제품 ID ↔ 서버 상품 코드.
///
/// 제품 ID는 App Store Connect 에 등록한 문자열과 **글자 하나까지 같아야** 한다.
/// 다르면 Product.products(for:) 가 조용히 빈 배열을 준다 — 오류가 아니라 빈 값이라
/// "상품이 없다"는 화면만 뜨고 원인이 안 보인다. 그래서 아래 목록이 단일 진실원이다.
enum MatthsProduct: String, CaseIterable {
    /// 29일 학습권 패키지 — 모의고사·배치고사·GOAT Arena 포함.
    case learningPass = "kr.matths.app.pass.29d"
    /// 주간 공식 모의고사 이용권 — 학습권과 권한을 섞지 않는 별도 상품.
    case mockExamOnly = "kr.matths.app.mock.30d"

    /// 서버 checkoutService 가 쓰는 상품 코드.
    var serverCode: String {
        switch self {
        case .learningPass: return "LEARNING_PACKAGE_29"
        case .mockExamOnly: return "MOCK_EXAM_ONLY"
        }
    }

    init?(serverCode: String) {
        guard let match = MatthsProduct.allCases.first(where: { $0.serverCode == serverCode })
        else { return nil }
        self = match
    }

    static var allIdentifiers: Set<String> {
        Set(allCases.map(\.rawValue))
    }
}

// MARK: - 구매 결과

enum MatthsPurchaseOutcome: Equatable {
    /// 결제와 서버 권한 부여가 모두 끝났다.
    case granted
    /// 사용자가 시트를 닫았다. 오류가 아니다 — 아무것도 띄우지 않는다.
    case cancelled
    /// 구입 요청(Ask to Buy) 대기. 부모가 승인하면 리스너가 마저 처리한다.
    case pendingApproval
}

// MARK: - 스토어

@MainActor
final class MatthsIAPStore: ObservableObject {

    static let shared = MatthsIAPStore()

    /// App Store 에서 받아 온 상품. 비어 있으면 화면이 가격을 못 그린다.
    @Published private(set) var products: [Product] = []
    @Published private(set) var loading = false
    /// 진행 중인 구매의 제품 ID. 버튼 중복 탭을 막는다.
    @Published private(set) var purchasing: String?
    /// 화면에 띄울 오류. nil 이면 문제 없음.
    @Published private(set) var lastError: String?
    /// 복원·지연 승인처럼 구매 시트 밖에서 끝난 성공을 사용자에게 알려 준다.
    @Published private(set) var lastNotice: String?
    /// 리스너가 뒤늦게 권한을 받아 냈을 때 올라간다. 화면이 이 값을 보고 새로고침한다.
    @Published private(set) var entitlementRevision = 0

    private var updatesTask: Task<Void, Never>?

    private init() {}

    // MARK: 수명

    /// 앱 실행 직후 한 번 부른다. 리스너를 띄우고 밀린 거래를 회수한다.
    ///
    /// **구매 화면에서 부르면 늦다.** Ask to Buy 승인은 학생이 앱을 다시 켤 때 도착하는데,
    /// 그때 학생이 상점 화면으로 들어가리라는 보장이 없다.
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.redeem(update, source: .listener)
            }
        }
        Task { await reconcileUnfinished() }
    }

    deinit { updatesTask?.cancel() }

    // MARK: 상품 조회

    func loadProducts(preservingFeedback: Bool = false) async {
        loading = true
        defer { loading = false }
        if !preservingFeedback { lastNotice = nil }
        do {
            let fetched = try await Product.products(for: MatthsProduct.allIdentifiers)
            // App Store Connect 등록 순서는 보장되지 않는다. 우리 열거 순서로 고정한다.
            let order = MatthsProduct.allCases.map(\.rawValue)
            products = fetched.sorted {
                (order.firstIndex(of: $0.id) ?? .max) < (order.firstIndex(of: $1.id) ?? .max)
            }
            let fetchedIDs = Set(fetched.map(\.id))
            let missingIDs = MatthsProduct.allIdentifiers.subtracting(fetchedIDs)
            if fetchedIDs.isEmpty {
                // 빈 배열은 오류로 오지 않는다. 여기서 잡지 않으면 원인 모를 빈 화면이 된다.
                if !preservingFeedback || lastError == nil {
                    lastError = "App Store에서 상품을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요."
                }
            } else if !missingIDs.isEmpty {
                // 일부만 돌아오는 것도 실패다. 이전 구현은 하나라도 받아 오면 오류를
                // 지워서, 누락된 카드에 영구 비활성 `결제` 버튼만 남겼다.
                if !preservingFeedback || lastError == nil {
                    lastError = "일부 App Store 상품을 불러오지 못했습니다. 다시 시도해 주세요."
                }
            } else if !preservingFeedback {
                lastError = nil
            }
        } catch {
            products = []
            if !preservingFeedback || lastError == nil {
                lastError = Self.readable(error)
            }
        }
    }

    func product(for item: MatthsProduct) -> Product? {
        products.first { $0.id == item.rawValue }
    }

    // MARK: 구매

    func purchase(_ item: MatthsProduct) async -> MatthsPurchaseOutcome {
        guard let product = product(for: item) else {
            lastError = "상품 정보를 불러오는 중입니다. 잠시 후 다시 시도해 주세요."
            return .cancelled
        }
        guard purchasing == nil else { return .cancelled }

        purchasing = product.id
        defer { purchasing = nil }
        lastError = nil
        lastNotice = nil

        do {
            // 구매 시트를 열기 전에 계정의 Bearer·슬롯·UUID를 한 벌로 고정한다.
            // Ask to Buy 창이 떠 있는 동안 로그인이 바뀌어도 새 계정 토큰으로 앞 계정
            // 거래를 redeem하지 않는다.
            guard let authorization = ServerAPI.captureAuthorization() else {
                lastError = "로그인한 뒤 결제를 다시 시도해 주세요."
                return .cancelled
            }
            let ownerSlot = DataScope.slot
            let proposedToken = Self.appAccountToken()
            let boundToken = try await ServerAPI.bindAppleAppAccountToken(
                proposed: proposedToken,
                authorization: authorization)
            let result = try await product.purchase(options: [
                .appAccountToken(boundToken)
            ])
            switch result {
            case .success(let verification):
                return await redeem(
                    verification,
                    source: .purchase,
                    authorization: authorization,
                    ownerSlot: ownerSlot) ? .granted : .cancelled

            case .userCancelled:
                // 사용자가 스스로 닫았다. 오류 문구를 띄우면 오히려 방해다.
                return .cancelled

            case .pending:
                // 구입 요청(Ask to Buy) 또는 SCA 추가 인증. 승인되면 리스너가 받는다.
                lastError = nil
                return .pendingApproval

            @unknown default:
                lastError = "결제 상태를 확인하지 못했습니다."
                return .cancelled
            }
        } catch {
            lastError = Self.readable(error)
            return .cancelled
        }
    }

    /// 기기 변경·재설치 복원. 애플과 동기화한 뒤 살아 있는 권한을 서버에 다시 알린다.
    func restore() async {
        loading = true
        defer { loading = false }
        lastError = nil
        lastNotice = nil
        guard let authorization = ServerAPI.captureAuthorization() else {
            lastError = "로그인한 뒤 구매 내역 복원을 다시 시도해 주세요."
            return
        }
        let ownerSlot = DataScope.slot
        var syncError: String?
        do {
            // 모듈 이름을 붙여야 한다 — 이 앱에도 AppStore 클래스가 있어서
            // 이름만 쓰면 우리 것이 StoreKit 의 것을 가린다.
            try await StoreKit.AppStore.sync()
        } catch {
            // sync 실패해도 currentEntitlements 는 캐시로 답할 수 있다. 멈추지 않는다.
            syncError = Self.readable(error)
        }
        var matched = 0
        var restored = 0
        var failed = 0
        for await entitlement in Transaction.currentEntitlements {
            let transaction: Transaction
            switch entitlement {
            case .verified(let value), .unverified(let value, _):
                transaction = value
            }
            guard MatthsProduct(rawValue: transaction.productID) != nil else { continue }
            matched += 1
            if await redeem(
                entitlement,
                source: .restore,
                authorization: authorization,
                ownerSlot: ownerSlot) {
                restored += 1
            } else {
                failed += 1
            }
        }
        if restored > 0 {
            // AppStore.sync() 가 실패했더라도 캐시 거래를 서버에 반영했다면 복원은
            // 성공이다. 앞선 네트워크 오류를 남겨 성공을 실패처럼 보이지 않는다.
            if failed == 0 { lastError = nil }
            lastNotice = failed == 0
                ? "구매 내역을 복원했습니다."
                : "일부 구매 내역을 복원했습니다. 나머지는 다시 시도해 주세요."
        } else if matched == 0 {
            lastError = syncError ?? "이 Apple 계정에서 복원할 구매 내역이 없습니다."
        } else if lastError == nil {
            lastError = syncError ?? "구매 내역을 복원하지 못했습니다. 잠시 후 다시 시도해 주세요."
        }
    }

    // MARK: 서버 반영

    private enum RedeemSource { case purchase, listener, restore }

    /// 서명을 확인하고 서버에 권한을 요청한다. **성공했을 때만** finish() 한다.
    @discardableResult
    private func redeem(
        _ verification: VerificationResult<Transaction>,
        source: RedeemSource,
        authorization suppliedAuthorization: ServerAPI.AuthorizationSnapshot? = nil,
        ownerSlot: String? = nil
    ) async -> Bool {
        let transaction: Transaction
        switch verification {
        case .verified(let value):
            transaction = value
        case .unverified(_, let error):
            // 서명이 안 맞는 거래다. 서버로 보내지 않고 finish() 도 하지 않는다.
            // 정상 사용자에게는 거의 안 생기고, 생겼다면 서버가 어차피 거절한다.
            #if DEBUG
            print("StoreKit 거래 서명 검증 실패:", error)
            #endif
            lastError = "결제 정보를 확인하지 못했습니다. App Store 계정을 확인한 뒤 구매 복원을 다시 시도해 주세요."
            return false
        }

        // 환불·취소된 거래는 권한을 주면 안 된다. 서버도 ASSN 으로 알게 되지만,
        // 여기서 먼저 걸러야 복원 흐름에서 잘못 열리지 않는다.
        if transaction.revocationDate != nil {
            await transaction.finish()
            entitlementRevision += 1
            return false
        }

        // 우리 상품이 아닌 거래는 남겨 둘 이유가 없다. 안 끝내면 매번 다시 온다.
        guard let item = MatthsProduct(rawValue: transaction.productID) else {
            await transaction.finish()
            return false
        }

        guard let authorization = suppliedAuthorization ?? ServerAPI.captureAuthorization() else {
            lastError = "구매를 반영하려면 Matths 계정으로 로그인해 주세요. 거래는 사라지지 않습니다."
            return false
        }

        do {
            _ = try await ServerAPI.redeemAppleTransaction(
                jws: verification.jwsRepresentation,
                productCode: item.serverCode,
                appAccountToken: transaction.appAccountToken?.uuidString,
                authorization: authorization)
            await transaction.finish()
            let stillSameAccount = ownerSlot == nil || ownerSlot == DataScope.slot
            if stillSameAccount { entitlementRevision += 1 }
            if source != .restore {
                lastError = nil
                lastNotice = stillSameAccount
                    ? (source == .listener
                        ? "구매 승인이 완료되어 이용권이 열렸습니다."
                        : "결제가 완료되어 이용권이 열렸습니다.")
                    : "구매를 시작한 Matths 계정에 이용권을 반영했습니다."
            }
            return true
        } catch {
            // finish() 하지 않는다 — 애플이 다음 실행 때 다시 준다(파일 머리 참조).
            lastError = Self.readable(error)
            return false
        }
    }

    /// 지난 실행에서 서버 반영에 실패해 남아 있는 거래를 회수한다.
    private func reconcileUnfinished() async {
        for await unfinished in Transaction.unfinished {
            _ = await redeem(unfinished, source: .listener)
        }
    }

    // MARK: appAccountToken
    //
    // 계정 슬롯마다 고정된 UUID 하나. 기기를 지우면 새로 생기지만, 그때는 서버가
    // originalTransactionId 로 이미 알고 있다(파일 머리 ② 경로).

    private static func appAccountToken() -> UUID {
        let key = DataScope.defaultsKey("matths.iap.appAccountToken", for: DataScope.slot)
        if let stored = UserDefaults.standard.string(forKey: key),
           let uuid = UUID(uuidString: stored) {
            return uuid
        }
        let fresh = UUID()
        UserDefaults.standard.set(fresh.uuidString, forKey: key)
        return fresh
    }

    // MARK: 오류 문구

    private static func readable(_ error: Error) -> String {
        if let apiError = error as? ServerAPIError {
            return apiError.errorDescription ?? "서버 오류"
        }
        if let skError = error as? StoreKitError {
            switch skError {
            case .networkError:
                return "네트워크 연결을 확인해 주세요."
            case .userCancelled:
                return ""
            case .notAvailableInStorefront:
                return "현재 App Store 국가에서는 구매할 수 없습니다."
            case .notEntitled:
                return "이 Apple 계정으로는 구매할 수 없습니다."
            default:
                return "App Store와 통신하지 못했습니다. 잠시 후 다시 시도해 주세요."
            }
        }
        if let purchaseError = error as? Product.PurchaseError {
            switch purchaseError {
            case .productUnavailable:
                return "지금은 구매할 수 없는 상품입니다."
            case .purchaseNotAllowed:
                return "기기 설정에서 인앱 구입이 제한되어 있습니다. 스크린 타임 설정을 확인해 주세요."
            case .ineligibleForOffer:
                return "이 혜택은 사용할 수 없는 계정입니다."
            default:
                return "결제를 완료하지 못했습니다."
            }
        }
        #if DEBUG
        print("StoreKit 처리 실패:", error)
        #endif
        return "결제를 처리하지 못했습니다. App Store 연결을 확인한 뒤 다시 시도해 주세요."
    }
}

// MARK: - 서버 경계
//
// ServerAPI.swift 가 아니라 여기에 두는 이유는 NotificationInbox.swift 와 같다 —
// tests/run-sync-contract.sh 가 ServerAPI.swift 를 **부분 파일 목록으로** 컴파일해서,
// 이 파일에만 있는 타입을 저기서 참조하면 그 검사가 깨진다.

extension ServerAPI {

    struct AppleAppAccountTokenResponse: Codable {
        var token: String
    }

    struct AppleRedeemResponse: Codable {
        /// 서버가 학습권을 열었는가. false 면 이유가 message 에 온다.
        var granted: Bool
        /// 이미 처리된 거래를 다시 보냈을 때 true. 오류가 아니다.
        var duplicate: Bool?
        var message: String?
        /// 서버가 계산한 만료 시각(ISO8601). 화면이 남은 기간을 그릴 때 쓴다.
        var expiresAt: String?
    }

    /// 애플 거래를 서버에 제출해 학습권을 연다.
    ///
    /// productCode 를 함께 보내지만 **서버는 이 값을 신뢰하면 안 된다** — 앱이 보내는 값이라
    /// 위조 가능하다. 진실원은 jws 안의 productId 다. 이 값은 대조·로깅용이다.
    @discardableResult
    static func redeemAppleTransaction(
        jws: String,
        productCode: String,
        appAccountToken: String?,
        authorization: AuthorizationSnapshot
    ) async throws -> AppleRedeemResponse {
        var body: [String: Any] = ["jws": jws, "productCode": productCode]
        if let appAccountToken { body["appAccountToken"] = appAccountToken }
        let response: AppleRedeemResponse = try await request(
            "POST", "/api/v1/commerce/apple/redeem", body: body, authed: true,
            authorization: authorization)
        guard response.granted else {
            throw ServerAPIError(
                message: response.message ?? "학습권을 열지 못했습니다. 고객센터로 문의해 주세요.",
                code: "APPLE_REDEEM_NOT_GRANTED")
        }
        return response
    }

    /// StoreKit 시트를 열기 전에 UUID를 현재 서버 사용자에게 귀속한다.
    static func bindAppleAppAccountToken(
        proposed: UUID,
        authorization: AuthorizationSnapshot
    ) async throws -> UUID {
        let response: AppleAppAccountTokenResponse = try await request(
            "POST",
            "/api/v1/commerce/apple/account-token",
            body: ["proposedToken": proposed.uuidString.lowercased()],
            authed: true,
            authorization: authorization)
        guard let token = UUID(uuidString: response.token) else {
            throw ServerAPIError(
                message: "서버가 올바르지 않은 결제 계정 식별자를 보냈습니다.",
                code: "APPLE_APP_ACCOUNT_TOKEN_INVALID")
        }
        return token
    }
}
