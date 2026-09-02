//  SplashView.swift
//  Matths
//
//  부팅 화면 — 브랜드 네이비 위에 공식 심볼 하나가 자리를 잡는다.
//
//  구성: 네이비 전면 → 심볼이 첫 프레임부터 보인 채(옅게·살짝 커짐)
//        짧게 안착(오버슈트 없음) → 전체가 걷히며 홈이 나온다.
//  3차 리디자인에서 타자기식 글자 등장·괘선을 뺐다: 부팅은 브랜드 모먼트 하나로
//  족하고, 태그라인·진행 표시도 두지 않는다. 이후 손질에서 opacity 0 출발도
//  뺐다 — 심볼이 네이비에 묻혀 있는 빈 프레임을 만들지 않는다.
//
//  규칙:
//   - iOS 의 런치스크린은 정적이어야 한다. 이 뷰는 런치 직후 첫 프레임 위에
//     얹히는 인앱 애니메이션이다. (비디오 재생이 아니라
//     네이티브 애니메이션이라 다크 모드와 중단에 그대로 대응한다.)
//   - 바탕은 Tokens.brandNavy — 이 화면의 유일한 히어로 면이고, 심볼의 풀컬러
//     그라데이션이 이 뷰포트의 유일한 그라데이션이다(CI p.14 다크 면 위 권장).
//   - 손쉬운 사용 > 동작 줄이기 또는 프로필의 "화면 모션" 꺼짐이면
//     뛰지 않고 0.25초 크로스페이드로 즉시 걷힌다 (모션 스위치는 앱 전체에 하나뿐이다).
//   - 네이비는 고정 다크 면이라 스플래시 동안 preferredColorScheme(.dark)로
//     상태바를 밝은 글자로 고정한다. 퇴장 시작과 함께 걷혀 프로필 테마로 돌아간다.
//   - 총 0.8초 상한(0.55 + 퇴장 0.25). 앱 부트는 동기(디스크 읽기)라 스플래시가
//     가려 줄 실제 초기화 신호가 없다 — 그래서 이 시간은 전부 인위적 대기이고,
//     상한을 0.8초로 못박는다 (1754: 불필요한 최소 표시 시간을 두지 않는다).
//   - 장식 햅틱 금지 — 사용자 입력이 없는 애니메이션 중간의 진동은 뺐다 (1225).

import SwiftUI
import UIKit

struct SplashView: View {
    let onFinished: () -> Void

    /// 모션 스위치는 하나뿐이다(Motion.swift 규칙 1). 스플래시만 예외로 두면
    /// "화면 모션 끔" 을 켠 학생이 앱을 열 때마다 가장 큰 모션부터 보게 된다.
    @EnvironmentObject private var store: AppStore

    @State private var markSettled = false
    @State private var dismissed = false

    /// DEBUG 스크린샷용 배속. `-splash slow` 로 4배 느리게 잡을 수 있다.
    private var speed: Double {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("slow") ? 4 : 1
        #else
        1
        #endif
    }

    var body: some View {
        ZStack {
            Tokens.brandNavy.ignoresSafeArea()

            VStack {
                // 공식 심볼 — 타일이 아닌 풀컬러 단독. 네이비 자체가 타일 역할이라
                // 타일 위 타일이 되면 로고가 액자에 갇힌다.
                // 첫 프레임부터 0.68 로 보인 채 출발한다(0 출발 금지) —
                // 심볼이 네이비에 묻혀 있는 프레임이 생기지 않는다.
                BrandMark()
                    .frame(width: 132, height: 132)
                    .scaleEffect(markSettled ? 1 : 1.18)
                    .opacity(markSettled ? 1 : 0.68)
            }
        }
        .opacity(dismissed ? 0 : 1)
        // 네이비는 고정 다크 면 — 라이트 외관에서 상태바 글자가 어두워 안 보이는
        // 것을 막는다. 퇴장이 시작되면 바로 nil 로 걷어, 크로스페이드로 드러나는
        // 홈이 프로필 테마 설정(MatthsApp 의 preferredColorScheme)으로 그려진다.
        .preferredColorScheme(dismissed ? nil : .dark)
        .onAppear(perform: run)
        .accessibilityAddTraits(.isModal)
    }

    private func run() {
        // 동작 줄이기 또는 앱의 "화면 모션" 꺼짐 — 대기 없이 즉시 크로스페이드로 걷는다.
        // (총 소요 ≤0.25초 — 모션을 끈 사람을 정지 화면 앞에 세워 두지 않는다)
        if UIAccessibility.isReduceMotionEnabled || !store.motionOn {
            markSettled = true
            finish()
            return
        }

        let s = speed

        // 1. 심볼 안착 — easeOut, 오버슈트 없음.
        // 스프링·바운스는 보상 모먼트 전용이고 부팅은 보상이 아니다.
        withAnimation(.easeOut(duration: 0.40 * s)) {
            markSettled = true
        }

        // 2. 퇴장 — 0.55 + 퇴장 0.25 = 총 0.80초 상한.
        // 실제 부트 작업과 연동할 신호가 없는 순수 브랜드 모먼트라(파일 머리 주석)
        // 여기 숫자가 곧 사용자가 기다리는 전부다. 파일 머리의 약속과 같이 움직인다.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55 * s) { finish() }
    }

    private func finish() {
        withAnimation(.easeIn(duration: 0.25)) { dismissed = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: onFinished)
    }
}
