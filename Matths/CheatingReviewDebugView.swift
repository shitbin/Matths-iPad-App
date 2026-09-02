//  CheatingReviewDebugView.swift
//  Matths
//
//  DEBUG에서만 보이는 로컬 판정 확인 카드. 학생용 제재 UI가 아니다.

#if DEBUG
import SwiftUI

struct CheatingReviewDebugCard: View {
    let record: CheatingReviewRecord

    private var result: CheatingDetectionResult { record.displayResult }

    private var verdictColor: Color {
        guard record.state == .completed else { return Tokens.warning }
        switch result.verdict {
        case .normal:       return Tokens.success
        case .suspicious:   return Tokens.danger
        case .inconclusive: return Tokens.warning
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            HStack(spacing: Tokens.Space.s2) {
                Image(systemName: "eye.trianglebadge.exclamationmark")
                Text("로컬 검토 · DEBUG").font(.mCaption)
                Spacer()
                Text(record.state == .pending ? "검사 중" : result.verdict.koreanLabel)
                    .font(.mMicro).foregroundStyle(verdictColor)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .overlay(Capsule().strokeBorder(verdictColor.opacity(0.6)))
            }
            .foregroundStyle(Tokens.text2)

            if record.state == .completed {
                Text("신뢰도 \(Int((result.confidence * 100).rounded()))% · \(result.reason)")
                    .font(.mCaption).foregroundStyle(Tokens.text2)
                    .fixedSize(horizontal: false, vertical: true)

                if result.evidence.isEmpty {
                    Text("좌표 근거 없음")
                        .font(.mMicro).foregroundStyle(Tokens.text4)
                } else {
                    ForEach(Array(result.evidence.enumerated()), id: \.offset) { _, evidence in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(evidence.kind.rawValue) · \(Int((evidence.confidence * 100).rounded()))%"
                                 + (evidence.isStrong ? " · 강한 근거" : ""))
                                .font(.mMicro).foregroundStyle(evidence.isStrong ? verdictColor : Tokens.text3)
                            Text("“\(evidence.quote)”")
                                .font(.mCaption).foregroundStyle(Tokens.ink)
                            Text(boxText(evidence.box))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Tokens.text4)
                        }
                    }
                }
            } else {
                HStack(spacing: Tokens.Space.s2) {
                    ProgressView().controlSize(.small)
                    Text("기존 온디바이스 비전 모델로 이미지 1회를 검사합니다.")
                        .font(.mCaption).foregroundStyle(Tokens.text3)
                }
            }

            Text("검토 기록만 저장 · 자동 제재/랭킹 반영 없음")
                .font(.mMicro).foregroundStyle(Tokens.text4)
        }
        .padding(Tokens.Space.s4)
        .background(Tokens.paper2, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.md)
            .strokeBorder(verdictColor.opacity(0.35), lineWidth: 1))
    }

    private func boxText(_ box: CheatingEvidenceBox) -> String {
        let values = [box.minX, box.minY, box.maxX, box.maxY]
            .map { String(Int(($0 * 1000).rounded())) }
            .joined(separator: ",")
        return "bbox [\(values)]"
    }
}
#endif
