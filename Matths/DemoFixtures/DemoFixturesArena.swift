//  DemoFixturesArena.swift
//  Matths — DEBUG 데모 모드 픽스처: GOAT Arena · 29일 패키지 · Ranked 상점 · 레거시 랭킹전
//
//  **아레나 규정·정산 로직은 여기서 새로 짓지 않는다.** 값은 서버 계약서와
//  ServerAPI 의 Codable 정의가 요구하는 필드를 채우기만 한다. 규칙 문구는
//  룰북 픽스처(DemoRulebookFixture)가 서버 정책에서 그대로 가져온 것만 쓴다.

#if DEBUG
import Foundation

enum DemoArenaFixtures {

    // MARK: - GOAT Arena 읽기 정본 (/api/v1/goat-arena)
    //
    // Unranked(SUB) 29일 사이클 12일차, 배치 확정(골드), 방어자로 배정된 도전이 하나 있는
    // 상태. 티어·MMR·사이클 진행·페이백 조건이 모두 실제 값으로 보이도록 채웠다.

    static let snapshot = #"""
    {
      "arena": {
        "readModelVersion": "GOAT_ARENA_V1",
        "generatedAt": "@T+0s@",
        "state": "ACTIVE_CYCLE",
        "identity": {
          "displayName": "지우",
          "schoolName": "한영고등학교",
          "displayMode": "nickname"
        },
        "cycle": {
          "id": "demo-cycle-01",
          "status": "ACTIVE",
          "activeRanking": "SUB",
          "cycleDay": 12,
          "phase": "PAID_ACCESS",
          "startsOn": "@T-11d@",
          "paidAccessEndsOn": "@T+17d@",
          "day30ReviewOn": "@T+18d@",
          "access": {
            "paidAccessActive": true,
            "completionPassActive": false,
            "learningAccessActive": true,
            "paidAccessDaysRemaining": 17
          },
          "balances": {
            "refundAvailableDays": 14,
            "refundLockedDays": 1,
            "bonusAvailableDays": 17,
            "bonusLockedDays": 0,
            "source": "ACCESS_CYCLE_LEDGER_CACHE"
          },
          "attendance": {
            "cycleStreakDays": 12,
            "lastRecognizedDate": "@D-0@"
          },
          "challenges": {
            "completed": 11,
            "completedNormal": 10,
            "completedRevenge": 1,
            "requestCount": 13,
            "minimumRequired": 29,
            "requestLimit": 3,
            "newRequestCutoffDay": 29
          },
          "integrityState": "CLEAR",
          "autoRenewEnabled": false
        },
        "payback": {
          "state": "IN_PROGRESS",
          "canEvaluate": true,
          "eligible": false,
          "refundStatus": null,
          "conditions": [
            { "key": "CYCLE_ATTENDANCE", "current": 12, "required": 29, "met": false },
            { "key": "PAYBACK_SCORE", "current": 14, "required": 30, "met": false }
          ],
          "blockers": [
            { "code": "LOCKED_DAY_BALANCE", "fields": ["refundLockedDays"] }
          ]
        },
        "ranking": {
          "activeRanking": "SUB",
          "skill": {
            "status": "CONFIRMED",
            "mmr": 1287,
            "tier": "GOLD",
            "rankPoint": 62,
            "overallRank": 1842,
            "weeklyExamsUntilConfirmed": 0
          },
          "seat": {
            "status": "ACTIVE",
            "arenaPosition": 137,
            "mmrAtLastSeed": 1240,
            "seededAt": "@T-11d@",
            "seedWeekKey": "@WEEK@",
            "protectionUntil": null,
            "rankShieldUntil": null
          },
          "contract": "MMR_AND_ARENA_POSITION_ARE_SEPARATE"
        },
        "season": {
          "id": "demo-season-2026",
          "title": "2026 시즌",
          "status": "ACTIVE",
          "currentWeekKey": "@WEEK@",
          "startsAt": "@T-120d@",
          "endsAt": "@T+140d@"
        },
        "activeMatch": {
          "id": "demo-match-01",
          "status": "MATCHED",
          "role": "DEFENDER",
          "matchType": "NORMAL",
          "settlementRule": "도전자가 예치한 페이백 점수 1점만 정산합니다.",
          "activeRanking": "SUB",
          "myPositionBefore": 137,
          "opponentPositionBefore": 158,
          "stake": { "assetType": "PAYBACK_SCORE_DAY", "days": 1 },
          "startsBy": "@T+21h@",
          "submitsBy": "@T+22h@",
          "integrityState": "CLEAR",
          "availableActions": ["ACCEPT", "DECLINE"],
          "attempt": {
            "status": "READY",
            "startedAt": null,
            "endsAt": null,
            "submittedAt": null,
            "evidenceDeadlineAt": null,
            "evidenceRequired": false
          }
        },
        "pendingInvitation": null,
        "rankUpPresentation": null,
        "capabilities": {
          "paybackEvaluation": "READY",
          "mainArena": "READY",
          "challengeCommands": "ARENA_MATCH_V1"
        }
      }
    }
    """#

    // MARK: - 경기 명령

    static let matchCommandReceipt = #"""
    { "match": { "id": "demo-match-01", "status": "MATCHED", "integrityState": "CLEAR" } }
    """#

    static func matchCommandResponse(matchId: String, accepted: Bool) -> String {
        let id = DemoRouter.escaped(matchId)
        let status = accepted ? "READY" : "DECLINED"
        return #"""
        { "match": { "id": "\#(id)", "status": "\#(status)", "integrityState": "CLEAR" } }
        """#
    }

    static func matchStart(matchId: String, slot: Int) -> String {
        let id = DemoRouter.escaped(matchId)
        let number = max(1, min(slot, 5))
        return #"""
        {
          "attempt": {
            "attemptId": "demo-attempt-01",
            "matchId": "\#(id)",
            "participantRole": "CHALLENGER",
            "questionPackId": "fixture-question-pack",
            "questionPackVersion": "1",
            "scoringPolicyVersion": "RANKED-2026-08",
            "timingPolicyVersion": "RANKED-25M",
            "status": "IN_PROGRESS",
            "questionCount": 5,
            "currentQuestionNumber": \#(number),
            "timeLimitSeconds": 1500,
            "startedAt": "@T-2m@",
            "endsAt": "@T+23m@",
            "commonSubmitsBy": "@T+40m@",
            "networkReconnectGraceMs": 30000,
            "recognizedHeartbeatActiveMs": 120000,
            "submittedAt": null,
            "evidenceDeadlineAt": null,
            "evidenceRequired": false
          },
          "questionPack": \#(questionPackBody(matchId: id, slot: number))
        }
        """#
    }

    static func questionPack(matchId: String, slot: Int) -> String {
        #"""
        { "questionPack": \#(questionPackBody(matchId: DemoRouter.escaped(matchId), slot: slot)) }
        """#
    }

    private static func questionPackBody(matchId: String, slot: Int) -> String {
        let stems = [
            "자연수 $n$ 에 대하여 $f(n)$ 을 $n$ 의 양의 약수의 개수라 할 때, $f(n)=6$ 을 만족시키는 100 이하의 자연수 $n$ 의 개수를 구하시오.",
            "함수 $f(x)=x^3-3x^2+k$ 의 극댓값과 극솟값의 곱이 $-4$ 일 때, 상수 $k$ 의 값을 구하시오.",
            "등비수열의 첫째항이 3, 공비가 2일 때 첫째항부터 제7항까지의 합을 구하시오.",
            "$0 \\\\le x < 2\\\\pi$ 에서 방정식 $2\\\\sin^2 x - 3\\\\cos x = 0$ 의 모든 실근의 합을 $a\\\\pi$ 라 할 때 $6a$ 의 값을 구하시오.",
            "서로 다른 5개의 문자를 일렬로 나열할 때 특정한 두 문자가 이웃하지 않는 경우의 수를 구하시오.",
        ]
        let index = max(0, min(slot - 1, stems.count - 1))
        return #"""
        {
          "questionPackId": "fixture-question-pack",
          "matchId": "\#(matchId)",
          "participantRole": "CHALLENGER",
          "packVersion": "1",
          "curriculumVersion": "2026-08",
          "questionVersion": "1",
          "scoringPolicyVersion": "RANKED-2026-08",
          "questionCount": 5,
          "currentQuestionNumber": \#(index + 1),
          "timeLimitSeconds": 1500,
          "questions": [
            {
              "slot": \#(index + 1),
              "questionVersionId": "demo-question-\#(index + 1)",
              "stem": "\#(stems[index])",
              "choices": null,
              "inputMode": "SHORT_ANSWER",
              "scoreWeight": 20.0,
              "targetDifficulty": 0.42,
              "calibratedDifficulty": 0.38,
              "advanced": \#(index >= 3 ? "true" : "false"),
              "visualizationJSON": null,
              "savedAnswer": null
            }
          ],
          "sealedAt": "@T-2m@"
        }
        """#
    }

    static func matchEvent(matchId: String, template: String, body: [String: Any]?) -> String {
        let id = DemoRouter.escaped(matchId)
        let type: String
        if template.hasSuffix("heartbeat") { type = "HEARTBEAT" }
        else if template.hasSuffix("focus") { type = "FOCUS" }
        else if template.hasSuffix("answers") { type = "ANSWER_SAVED" }
        else { type = "NETWORK_STATE" }
        let slot = DemoRouter.int(body, "questionSlot").map(String.init) ?? "null"
        let network = (body?["networkState"] as? String).map { #""\#($0)""# } ?? "null"
        return #"""
        {
          "event": {
            "eventId": "demo-event-\#(type.lowercased())",
            "attemptId": "demo-attempt-01",
            "matchId": "\#(id)",
            "eventType": "\#(type)",
            "clientEventId": "demo-client-event",
            "serverSequence": 42,
            "serverOccurredAt": "@T+0s@",
            "questionSlot": \#(slot),
            "networkState": \#(network),
            "recognizedActiveIntervalMs": 5000,
            "answerStored": \#(type == "ANSWER_SAVED" ? "true" : "false")
          }
        }
        """#
    }

    static func matchSubmission(matchId: String) -> String {
        let id = DemoRouter.escaped(matchId)
        return #"""
        {
          "attempt": {
            "submissionRecordId": "demo-submission-01",
            "attemptId": "demo-attempt-01",
            "matchId": "\#(id)",
            "participantRole": "DEFENDER",
            "questionPackId": "demo-pack-01",
            "submissionId": "demo-submission-id-01",
            "submittedAt": "@T+0s@",
            "evidenceDeadlineAt": "@T+60s@",
            "evidenceRequired": true,
            "lastAcceptedServerSequence": 87,
            "recognizedHeartbeatActiveMs": 1740000,
            "answerCount": 5
          }
        }
        """#
    }

    // MARK: - Ranked 신청 시트 (/goat-arena/matches/main/*)

    static let mainMatchOptions = #"""
    {
      "schemaVersion": "GOAT_ARENA_MAIN_ACTIONS_V1",
      "eligible": true,
      "reasonCodes": [],
      "currentTier": "GOLD",
      "availableLearningDays": 17,
      "matchmakingRestrictedUntil": null,
      "hasActiveMatch": false,
      "requestLocked": false,
      "sentInvitations": [
        {
          "id": "demo-invitation-01",
          "status": "PENDING",
          "targetTier": "SILVER",
          "stakeDays": 1,
          "reservedLearningDays": 1,
          "createdAt": "@T-5h@",
          "canCancel": true
        }
      ],
      "upwardTargets": [
        { "tier": "PLATINUM", "gap": 1, "minimumStakeDays": 1, "maximumStakeDays": 5, "available": true },
        { "tier": "EMERALD", "gap": 2, "minimumStakeDays": 2, "maximumStakeDays": 5, "available": true },
        { "tier": "DIAMOND", "gap": 3, "minimumStakeDays": 3, "maximumStakeDays": 5, "available": false }
      ],
      "lowerTargets": [
        { "tier": "SILVER", "gap": 1, "minimumStakeDays": 1, "maximumStakeDays": 5, "available": true },
        { "tier": "BRONZE", "gap": 2, "minimumStakeDays": 2, "maximumStakeDays": 5, "available": true }
      ]
    }
    """#

    static let mainUpwardReceipt = #"""
    {
      "kind": "MATCH",
      "match": { "id": "demo-main-match-01", "status": "MATCHED", "integrityState": "CLEAR" },
      "invitation": null
    }
    """#

    static let mainInvitationReceipt = #"""
    {
      "kind": "INVITATION",
      "match": null,
      "invitation": {
        "id": "demo-invitation-02",
        "status": "PENDING",
        "targetTier": "SILVER",
        "stakeDays": 1
      }
    }
    """#

    // 계좌 원문·예금주는 GET 픽스처에도 넣지 않는다. 실제 서버 읽기 계약과 같이
    // 은행명·끝 4자리·확인 시각만 화면으로 돌아온다.
    static let paybackAccountStatus = #"""
    {
      "schemaVersion": "GOAT_ARENA_PAYBACK_ACCOUNT_V1",
      "account": {
        "confirmed": true,
        "bankName": "토스뱅크",
        "last4": "2195",
        "confirmedAt": "@T-3d@"
      },
      "payoutEligible": true,
      "bankSuggestions": [
        "국민은행", "신한은행", "우리은행", "하나은행", "농협은행",
        "기업은행", "카카오뱅크", "토스뱅크", "케이뱅크"
      ]
    }
    """#

    static func paybackAccountConfirmation(
        bankName: String,
        accountNumber: String
    ) -> String {
        let safeBank = DemoRouter.escaped(bankName.isEmpty ? "토스뱅크" : bankName)
        let digits = accountNumber.filter(\.isNumber)
        let last4 = DemoRouter.escaped(String(digits.suffix(4)))
        return #"""
        {
          "schemaVersion": "GOAT_ARENA_PAYBACK_ACCOUNT_V1",
          "account": {
            "confirmed": true,
            "bankName": "\#(safeBank)",
            "last4": "\#(last4)",
            "confirmedAt": "@T+0s@"
          }
        }
        """#
    }

    static func invitationCancelled(id: String) -> String {
        let value = DemoRouter.escaped(id)
        return #"""
        {
          "kind": "INVITATION",
          "invitation": {
            "id": "\#(value)",
            "status": "CANCELLED",
            "releasedLearningDays": 1,
            "burnedLearningDays": 0
          }
        }
        """#
    }

    // MARK: - Ranked 상점 (/goat-arena/main/shop)
    //
    // 상품명·설명·환불 조건은 서버 ipadArenaShopAdapter 의 표시 문구를 그대로 쓴다.

    static let shop = #"{ "shop": \#(shopBody) }"#

    static let shopPurchase = #"""
    {
      "receipt": {
        "replayed": false,
        "purchase": {
          "id": "demo-purchase-03",
          "itemCode": "MATCH_ANALYSIS",
          "displayName": "Arena 경기 분석권",
          "policyVersionCode": "MAIN-SHOP-V1",
          "priceDays": 1,
          "beforeAvailableDays": 17,
          "afterAvailableDays": 16,
          "status": "APPLIED",
          "purchasedAt": "@T+0s@",
          "reversedAt": null,
          "reversalReason": "",
          "relatedMatchId": "demo-settled-match-01",
          "relatedInvitationId": null
        },
        "effect": {
          "id": "demo-effect-03",
          "itemCode": "MATCH_ANALYSIS",
          "status": "APPLIED",
          "startsAt": "@T+0s@",
          "endsAt": null,
          "appliedAt": "@T+0s@",
          "analysisState": "PENDING",
          "relatedMatchId": "demo-settled-match-01",
          "relatedInvitationId": null
        },
        "matchId": "demo-settled-match-01",
        "beforeAvailableDays": 17,
        "afterAvailableDays": 16,
        "expectedEffectEndsAt": null,
        "demotionRisk": "NORMAL"
      },
      "shop": \#(shopBody)
    }
    """#

    private static let shopBody = #"""
    {
      "generatedAt": "@T+0s@",
      "wallet": { "availableLearningDays": 17, "minimumBalanceAfterPurchase": 1 },
      "policy": {
        "versionCode": "MAIN-SHOP-V1",
        "displayName": "Ranked 상점 정책 v1",
        "effectiveFrom": "2026-08-01T15:00:00.000Z",
        "sundayLocked": false,
        "sundayLockMessage": "일요일 15:00부터 월요일 00:00까지 Arena 정산 중에는 새 상점 기능을 적용할 수 없습니다.",
        "demotionMessage": "구매 뒤 최소 1일의 학습일을 남겨야 하며, 모든 잔액이 소진되고 정산이 끝나면 Unranked로 전환됩니다.",
        "nonRefundableMessage": "효과가 정상 적용된 뒤에는 임의 취소할 수 없습니다. 서버 처리 실패 시에는 정책에 따라 자동 반환합니다."
      },
      "items": [
        {
          "itemCode": "MATCH_ANALYSIS",
          "displayName": "Arena 경기 분석권",
          "priceDays": 1,
          "releasePhase": 1,
          "eyebrow": "경기 복습",
          "description": "정산이 끝난 내 경기의 문항별 결과·풀이시간·취약 개념을 분석하고 맞춤 복습 순서를 제공합니다.",
          "targetType": "MATCH",
          "durationLabel": "경기 한 건 분석",
          "refundCondition": "5분 안에 두 번 재시도한 뒤에도 생성하지 못하면 구매를 자동 취소하고 1일을 반환합니다.",
          "purchasePreview": {
            "beforeAvailableDays": 17,
            "afterAvailableDays": 16,
            "purchaseEligible": true,
            "expectedEffectEndsAt": null,
            "daysUntilAvailableBalanceExhaustion": 16,
            "demotionRisk": "NORMAL"
          }
        },
        {
          "itemCode": "DEFENSE_REST",
          "displayName": "방어 휴식권",
          "priceDays": 1,
          "releasePhase": 1,
          "eyebrow": "일정 관리",
          "description": "24시간 동안 앞으로 배정될 일반 상향 공격의 의무 방어 후보에서 제외됩니다.",
          "targetType": "NONE",
          "durationLabel": "24시간",
          "refundCondition": "방어 편의 기능은 공통 7일에 한 번만 사용할 수 있으며 정상 적용 뒤에는 임의 취소할 수 없습니다.",
          "purchasePreview": {
            "beforeAvailableDays": 17,
            "afterAvailableDays": 16,
            "purchaseEligible": true,
            "expectedEffectEndsAt": "@T+1d@",
            "daysUntilAvailableBalanceExhaustion": 16,
            "demotionRisk": "NORMAL"
          }
        },
        {
          "itemCode": "DEFENSE_SCHEDULE_PROTECTION",
          "displayName": "방어 일정 보호권",
          "priceDays": 2,
          "releasePhase": 2,
          "eyebrow": "일정 보호",
          "description": "조건을 충족한 의무 방어 경기를 승패 없이 종료하고 공격자에게 1일을 보상합니다.",
          "targetType": "MATCH",
          "durationLabel": "경기 배정 후 3시간 이내",
          "refundCondition": "적용 즉시 경기 종료·공격자 보상·학습일수 차감이 확정되므로 사용 뒤에는 취소할 수 없습니다.",
          "purchasePreview": {
            "beforeAvailableDays": 17,
            "afterAvailableDays": 15,
            "purchaseEligible": false,
            "expectedEffectEndsAt": null,
            "daysUntilAvailableBalanceExhaustion": 15,
            "demotionRisk": "NORMAL"
          }
        },
        {
          "itemCode": "INVITATION_ACCELERATION",
          "displayName": "초대 매칭 가속권",
          "priceDays": 1,
          "releasePhase": 2,
          "eyebrow": "초대 경기",
          "description": "대기 중인 Ranked 초대 요청 한 건의 매칭 우선순위를 48시간 동안 높입니다.",
          "targetType": "INVITATION",
          "durationLabel": "48시간 또는 경기 성립 시까지",
          "refundCondition": "매칭 성립을 보장하지 않으며 정상 적용 뒤에는 임의 취소할 수 없습니다.",
          "purchasePreview": {
            "beforeAvailableDays": 17,
            "afterAvailableDays": 16,
            "purchaseEligible": false,
            "expectedEffectEndsAt": null,
            "daysUntilAvailableBalanceExhaustion": 16,
            "demotionRisk": "NORMAL"
          }
        },
        {
          "itemCode": "MAIN_PROFILE_BORDER",
          "displayName": "Ranked 프로필 테두리",
          "priceDays": 2,
          "releasePhase": 1,
          "eyebrow": "시즌 장식",
          "description": "현재 시즌 동안 Ranked 프로필·랭킹·경기 결과에 전용 테두리를 적용합니다.",
          "targetType": "NONE",
          "durationLabel": "현재 시즌 종료까지",
          "refundCondition": "시즌 종료 뒤 자동 만료되며 환불하거나 다른 사용자에게 이전할 수 없습니다.",
          "purchasePreview": {
            "beforeAvailableDays": 17,
            "afterAvailableDays": 15,
            "purchaseEligible": true,
            "expectedEffectEndsAt": "@T+140d@",
            "daysUntilAvailableBalanceExhaustion": 15,
            "demotionRisk": "NORMAL"
          }
        },
        {
          "itemCode": "STYLE_ENTRANCE",
          "displayName": "스타일 칭호·입장 연출",
          "priceDays": 1,
          "releasePhase": 1,
          "eyebrow": "시즌 장식",
          "description": "구매형 스타일 칭호와 경기 입장 연출을 적용하며 승패 판정에는 영향을 주지 않습니다.",
          "targetType": "NONE",
          "durationLabel": "현재 시즌 종료까지",
          "refundCondition": "정상 적용 뒤에는 임의 취소할 수 없으며 시즌 마지막 10일 구매분만 다음 시즌까지 한 번 이월됩니다.",
          "purchasePreview": {
            "beforeAvailableDays": 17,
            "afterAvailableDays": 16,
            "purchaseEligible": true,
            "expectedEffectEndsAt": "@T+140d@",
            "daysUntilAvailableBalanceExhaustion": 16,
            "demotionRisk": "NORMAL"
          }
        }
      ],
      "effects": [
        {
          "id": "demo-effect-01",
          "itemCode": "MATCH_ANALYSIS",
          "status": "ANALYSIS_READY",
          "startsAt": "@T-2d@",
          "endsAt": null,
          "appliedAt": "@T-2d@",
          "analysisState": "READY",
          "relatedMatchId": "demo-settled-match-01",
          "relatedInvitationId": null
        },
        {
          "id": "demo-effect-02",
          "itemCode": "DEFENSE_REST",
          "status": "APPLIED",
          "startsAt": "@T-6h@",
          "endsAt": "@T+18h@",
          "appliedAt": "@T-6h@",
          "analysisState": "NONE",
          "relatedMatchId": null,
          "relatedInvitationId": null
        }
      ],
      "purchases": [
        {
          "id": "demo-purchase-01",
          "itemCode": "MATCH_ANALYSIS",
          "displayName": "Arena 경기 분석권",
          "policyVersionCode": "MAIN-SHOP-V1",
          "priceDays": 1,
          "beforeAvailableDays": 20,
          "afterAvailableDays": 19,
          "status": "APPLIED",
          "purchasedAt": "@T-2d@",
          "reversedAt": null,
          "reversalReason": "",
          "relatedMatchId": "demo-settled-match-01",
          "relatedInvitationId": null
        },
        {
          "id": "demo-purchase-02",
          "itemCode": "DEFENSE_REST",
          "displayName": "방어 휴식권",
          "policyVersionCode": "MAIN-SHOP-V1",
          "priceDays": 1,
          "beforeAvailableDays": 19,
          "afterAvailableDays": 18,
          "status": "APPLIED",
          "purchasedAt": "@T-6h@",
          "reversedAt": null,
          "reversalReason": "",
          "relatedMatchId": null,
          "relatedInvitationId": null
        }
      ],
      "analysisTargets": [
        { "id": "demo-settled-match-01", "divisionLabel": "Unranked", "matchTypeLabel": "공식 경기", "occurredAt": "@T-2d@" },
        { "id": "demo-settled-match-02", "divisionLabel": "Unranked", "matchTypeLabel": "재대결", "occurredAt": "@T-6d@" },
        { "id": "demo-settled-match-03", "divisionLabel": "Ranked", "matchTypeLabel": "초대 경기", "occurredAt": "@T-13d@" }
      ],
      "defenseProtectionTargets": [],
      "invitations": [
        {
          "id": "demo-invitation-01",
          "targetTier": "SILVER",
          "stakeDays": 1,
          "status": "PENDING",
          "createdAt": "@T-5h@",
          "acceleratedAt": null,
          "accelerationEndsAt": null
        }
      ]
    }
    """#

    static func shopAnalysis(effectId: String) -> String {
        let id = DemoRouter.escaped(effectId)
        return #"""
        {
          "analysis": {
            "id": "\#(id)",
            "status": "APPLIED",
            "analysisState": "READY",
            "relatedMatchId": "demo-settled-match-01",
            "result": "WIN",
            "score": 80.0,
            "correctCount": 4,
            "totalSolveTimeMs": 1612000,
            "incorrectQuestionKeys": ["demo-question-4"],
            "weakSkills": ["삼각방정식 치환", "정의역 제한 확인"],
            "reviewProblemCount": 6,
            "checklist": [
              "치환 뒤 새 변수의 범위를 먼저 적는다.",
              "$\\cos x$ 로 정리한 뒤 이차방정식의 실근 조건을 확인한다.",
              "구한 해가 주어진 구간 안에 있는지 마지막에 한 번 더 본다."
            ],
            "questionReviews": [
              {
                "number": 4,
                "questionKey": "demo-question-4",
                "courseId": "algebra",
                "typeId": "trig-equation",
                "skillTags": ["삼각방정식", "치환"],
                "prompt": "$0 \\le x < 2\\pi$ 에서 $2\\sin^2 x - 3\\cos x = 0$ 의 모든 실근의 합을 구하시오.",
                "submittedAnswer": "4",
                "correctAnswer": "8",
                "correct": false,
                "pointsAwarded": 0.0,
                "responseTimeMs": 486000,
                "solution": "$\\sin^2 x = 1-\\cos^2 x$ 로 바꾸면 $2\\cos^2 x + 3\\cos x - 2 = 0$ 이 됩니다.",
                "referenceSolutionProcess": [
                  { "step": 1, "explanation": "$\\sin^2 x$ 를 $1-\\cos^2 x$ 로 바꿔 하나의 삼각비로 정리합니다." },
                  { "step": 2, "explanation": "$t=\\cos x$ 로 두면 $2t^2+3t-2=0$ 이고 $t=1/2$ 만 범위 안에 있습니다." },
                  { "step": 3, "explanation": "$\\cos x = 1/2$ 의 해는 $x = \\pi/3$ 과 $x = 5\\pi/3$ 입니다." }
                ],
                "referenceFinalCheck": "치환한 $t$ 의 범위 $-1 \\le t \\le 1$ 을 만족하는 해만 남겼는지 확인합니다."
              },
              {
                "number": 5,
                "questionKey": "demo-question-5",
                "courseId": "probability-statistics",
                "typeId": "permutation-adjacent",
                "skillTags": ["순열", "여사건"],
                "prompt": "서로 다른 5개의 문자를 일렬로 나열할 때 특정한 두 문자가 이웃하지 않는 경우의 수를 구하시오.",
                "submittedAnswer": "72",
                "correctAnswer": "72",
                "correct": true,
                "pointsAwarded": 20.0,
                "responseTimeMs": 214000,
                "solution": "전체 $5!=120$ 에서 두 문자가 이웃하는 $2 \\times 4! = 48$ 을 뺍니다.",
                "referenceSolutionProcess": [
                  { "step": 1, "explanation": "전체 나열 방법은 $5! = 120$ 가지입니다." },
                  { "step": 2, "explanation": "두 문자를 묶어 하나로 보면 $4!$ 이고 묶음 안에서 $2!$ 이므로 48가지입니다." }
                ],
                "referenceFinalCheck": "여사건을 쓸 때 묶음 내부 순서를 빠뜨리지 않았는지 확인합니다."
              }
            ],
            "generatedAt": "@T-2d@",
            "purchasedAt": "@T-2d@"
          }
        }
        """#
    }

    // MARK: - 29일 패키지 / 레거시 랭킹전

    static let accessEconomy = #"""
    {
      "economy": {
        "state": "ACTIVE",
        "cycleId": "demo-cycle-01",
        "access": {
          "paidAccessDays": 17,
          "refundChallengeDays": 14,
          "bonusAccessDays": 3,
          "lockedDays": 1,
          "paidAccessStartsAt": "@T-11d@",
          "paidAccessEndsAt": "@T+17d@"
        },
        "refund": {
          "status": null,
          "eligible": false,
          "day30CompletionPassAvailable": false,
          "streakDays": 12,
          "targetStreakDays": 29,
          "targetChallengeDays": 30,
          "paybackAmountKRW": 29000,
          "completedAt": null
        },
        "ranking": {
          "activeRanking": "SUB",
          "skillMMR": 1287,
          "rankTier": "GOLD",
          "ladderPosition": 137,
          "mainRankingEnteredAt": null,
          "rankShieldUntil": null
        },
        "purchase": {
          "allowed": false,
          "blockers": [
            { "code": "ACTIVE_CYCLE_REMAINING", "message": "이용 중인 29일 패키지가 끝난 뒤에 다시 구매할 수 있습니다." }
          ]
        }
      }
    }
    """#

    static let legacyArena = #"""
    {
      "arena": {
        "locked": false,
        "mmr": 1287,
        "tier": "GOLD",
        "tierLabel": "골드",
        "rankPoint": 62,
        "division": 2,
        "status": "CONFIRMED",
        "weeklyExamsUntilConfirmed": 0,
        "overallRank": 1842,
        "percentile": 21.4,
        "recentPerformances": [64.2, 71.0, 58.5, 77.3]
      },
      "ladder": [
        { "name": "BRONZE", "label": "브론즈", "minMmr": 0, "maxMmr": 799, "maxTopPercentile": null },
        { "name": "SILVER", "label": "실버", "minMmr": 800, "maxMmr": 1099, "maxTopPercentile": null },
        { "name": "GOLD", "label": "골드", "minMmr": 1100, "maxMmr": 1399, "maxTopPercentile": null },
        { "name": "PLATINUM", "label": "플래티넘", "minMmr": 1400, "maxMmr": 1699, "maxTopPercentile": null },
        { "name": "EMERALD", "label": "에메랄드", "minMmr": 1700, "maxMmr": 1999, "maxTopPercentile": null },
        { "name": "DIAMOND", "label": "다이아몬드", "minMmr": 2000, "maxMmr": 2299, "maxTopPercentile": null },
        { "name": "MASTER", "label": "마스터", "minMmr": 2300, "maxMmr": 2599, "maxTopPercentile": 5.0 },
        { "name": "GRANDMASTER", "label": "그랜드마스터", "minMmr": 2600, "maxMmr": 2899, "maxTopPercentile": 1.0 },
        { "name": "CHALLENGER", "label": "챌린저", "minMmr": 2900, "maxMmr": null, "maxTopPercentile": 0.1 }
      ],
      "identity": {
        "displayName": "지우",
        "schoolName": "한영고등학교",
        "displayMode": "닉네임"
      }
    }
    """#

    static let legacyLeaderboard = #"""
    { "total": 8421, \#(leaderboardRows) }
    """#

    static func accessLeaderboard(pool: String) -> String {
        // 요청한 풀을 그대로 되돌려주지 않으면 ServerAPI 가 RANKING_POOL_MISMATCH 로 막는다.
        let normalized = pool.uppercased() == "MAIN" ? "MAIN" : "SUB"
        return #"""
        { "ranking": "\#(normalized)", "total": 8421, \#(leaderboardRows) }
        """#
    }

    /// 이름 길이·MMR 자릿수·티어를 섞어야 순위표 셀의 줄바꿈이 실제로 시험된다.
    private static let leaderboardRows = #"""
    "top": [
      { "userId": "demo-u1", "name": "정민서", "rank": 1, "mmr": 2947, "tier": "CHALLENGER", "tierLabel": "챌린저", "rankPoint": 98, "division": 1, "status": "CONFIRMED", "isMe": false },
      { "userId": "demo-u2", "name": "라이트닝볼트수학마스터", "rank": 2, "mmr": 2881, "tier": "GRANDMASTER", "tierLabel": "그랜드마스터", "rankPoint": 91, "division": 1, "status": "CONFIRMED", "isMe": false },
      { "userId": "demo-u3", "name": "윤", "rank": 3, "mmr": 2740, "tier": "GRANDMASTER", "tierLabel": "그랜드마스터", "rankPoint": 74, "division": 2, "status": "CONFIRMED", "isMe": false },
      { "userId": "demo-u4", "name": "김도현", "rank": 4, "mmr": 2612, "tier": "GRANDMASTER", "tierLabel": "그랜드마스터", "rankPoint": 52, "division": 3, "status": "PROVISIONAL", "isMe": false },
      { "userId": "demo-u5", "name": "박서연", "rank": 5, "mmr": 2488, "tier": "MASTER", "tierLabel": "마스터", "rankPoint": 63, "division": 2, "status": "CONFIRMED", "isMe": false },
      { "userId": "demo-u6", "name": "이준우", "rank": 6, "mmr": 2301, "tier": "MASTER", "tierLabel": "마스터", "rankPoint": 8, "division": 4, "status": "CONFIRMED", "isMe": false },
      { "userId": "demo-u7", "name": "최하늘", "rank": 7, "mmr": 2154, "tier": "DIAMOND", "tierLabel": "다이아몬드", "rankPoint": 51, "division": 2, "status": "CONFIRMED", "isMe": false },
      { "userId": "demo-u8", "name": "한지민", "rank": 8, "mmr": 2007, "tier": "DIAMOND", "tierLabel": "다이아몬드", "rankPoint": 2, "division": 4, "status": "PROVISIONAL", "isMe": false },
      { "userId": "demo-u9", "name": "오수빈", "rank": 9, "mmr": 1893, "tier": "EMERALD", "tierLabel": "에메랄드", "rankPoint": 64, "division": 2, "status": "CONFIRMED", "isMe": false },
      { "userId": "demo-u10", "name": "장태윤", "rank": 10, "mmr": 1802, "tier": "EMERALD", "tierLabel": "에메랄드", "rankPoint": 34, "division": 3, "status": "CONFIRMED", "isMe": false }
    ],
    "me": { "userId": "demo-me", "name": "지우", "rank": 1842, "mmr": 1287, "tier": "GOLD", "tierLabel": "골드", "rankPoint": 62, "division": 2, "status": "CONFIRMED", "isMe": true }
    """#
}
#endif
