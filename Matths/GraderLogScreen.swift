//  GraderLogScreen.swift
//  Matths
//
//  채점 기록 보기 (디버그 전용) — 올린 사진 썸네일을 누르면 그 실행에서
//  로컬 모델이 주고받은 컨텍스트를 전부 펼쳐 본다.
//
//  왜 이런 모양인가: 결과가 이상할 때 알아야 하는 건 "무엇을 넣었더니 무엇이 나왔나"
//  딱 두 가지다. 그래서 단계별로 [보낸 프롬프트] / [받은 원문] 을 나란히 두고,
//  길이·소요 시간·토큰 한도까지 같이 적는다 (잘렸는지 판단하려면 한도가 필요하다).
//  긴 글은 접어 두되 원문은 손대지 않는다 — 요약하면 디버깅이 안 된다.

#if DEBUG
import SwiftUI

struct GraderLogScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var runs: [GraderRun] = []
    @State private var opened: GraderRun?
    @State private var copiedRun: UUID?

    var body: some View {
        NavigationStack {
            Group {
                if runs.isEmpty {
                    VStack(spacing: Tokens.Space.s3) {
                        Image(systemName: "tray")
                            .font(.system(size: 34)).foregroundStyle(Tokens.text4)
                        Text("아직 채점 기록이 없습니다")
                            .font(.mBodyB).foregroundStyle(Tokens.text2)
                        Text("사진을 올려 분석을 한 번 돌리면 여기에 쌓입니다.")
                            .font(.mCaption).foregroundStyle(Tokens.text3)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: Tokens.Space.s3) {
                            ForEach(runs) { run in
                                runCard(run)
                            }
                        }
                        .padding(Tokens.Space.s5)
                    }
                }
            }
            .background(Tokens.paper)
            .navigationTitle("채점 기록 (디버그)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("전체 삭제", role: .destructive) {
                        SheetGraderLog.clearAll(); runs = []
                    }
                    .disabled(runs.isEmpty)
                }
            }
        }
        .onAppear { runs = SheetGraderLog.load() }
        .compactHeightSheet(item: $opened) { run in GraderRunDetail(run: run) }
    }

    // 목록 카드 — 썸네일이 곧 버튼이다 (사용자 요청: "사진 썸네일을 누르면")
    private func runCard(_ run: GraderRun) -> some View {
        Button { opened = run } label: {
            HStack(alignment: .top, spacing: Tokens.Space.s4) {
                thumbnail(run)
                VStack(alignment: .leading, spacing: 4) {
                    Text(run.startedAt.formatted(date: .abbreviated, time: .standard))
                        .font(.mBodyB).foregroundStyle(Tokens.ink)
                    Text("호출 \(run.calls.count)회, \(Int(run.totalSeconds))초"
                         + (run.itemCount.map { ", 문항 \($0)개" } ?? ""))
                        .font(.mCaption).foregroundStyle(Tokens.text3)
                    if let f = run.failed {
                        Text("실패: \(f)").font(.mCaption).foregroundStyle(Tokens.danger)
                            .lineLimit(2)
                    }
                    // 어느 단계까지 갔는지 한 줄로
                    Text(run.calls.map(\.stage).joined(separator: ", "))
                        .font(.mMicro).foregroundStyle(Tokens.text4)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                VStack(spacing: Tokens.Space.s2) {
                    // 상세를 열 필요도 없이 바로 통짜 복사 (붙여 넣기가 목적일 때가 대부분)
                    Button {
                        UIPasteboard.general.string = GraderDump.text(run)
                        copiedRun = run.id
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { copiedRun = nil }
                    } label: {
                        Label(copiedRun == run.id ? "복사됨" : "복사",
                              systemImage: copiedRun == run.id ? "checkmark" : "doc.on.clipboard")
                            .font(.mMicro)
                            .foregroundStyle(copiedRun == run.id ? Tokens.success : Tokens.primary)
                    }
                    .buttonStyle(.plain)
                    Image(systemName: "chevron.right")
                        .font(.mCaption).foregroundStyle(Tokens.text4)
                }
            }
            .padding(Tokens.Space.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func thumbnail(_ run: GraderRun) -> some View {
        if let url = SheetGraderLog.imageURL(run), let ui = UIImage(contentsOfFile: url.path) {
            Image(uiImage: ui)
                .resizable().scaledToFill()
                .frame(width: 92, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                    .strokeBorder(Tokens.line, lineWidth: 1))
        } else {
            RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                .fill(Tokens.paper2)
                .frame(width: 92, height: 92)
                .overlay(Image(systemName: "photo").foregroundStyle(Tokens.text4))
        }
    }
}

/// 한 실행의 전체 컨텍스트
private struct GraderRunDetail: View {
    let run: GraderRun
    @Environment(\.dismiss) private var dismiss
    @State private var expanded: Set<UUID> = []
    @State private var copied = false

    private func copyAll() {
        UIPasteboard.general.string = plainDump()
        copied = true
        // 잠깐 표시했다가 되돌린다 — 계속 "복사됨" 이면 다음에 눌렀는지 알 수 없다
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { copied = false }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s5) {
                    if let url = SheetGraderLog.imageURL(run),
                       let ui = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: ui)
                            .resizable().scaledToFit()
                            .frame(maxHeight: 320)
                            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md))
                    }

                    Text("호출 \(run.calls.count)회, 총 \(Int(run.totalSeconds))초")
                        .font(.mCaption).foregroundStyle(Tokens.text3)

                    // 단계를 하나씩 펼쳐 읽는 건 사람이 볼 때 이야기고,
                    // 클로드에 붙여 넣을 때는 통짜 한 덩어리가 필요하다.
                    Button {
                        copyAll()
                    } label: {
                        Label(copied ? "클립보드에 복사됨" : "전체 컨텍스트 한 번에 복사",
                              systemImage: copied ? "checkmark.circle.fill" : "doc.on.clipboard")
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Text("프롬프트와 출력 전문이 한 덩어리로 복사됩니다. 그대로 붙여 넣으면 됩니다.")
                        .font(.mMicro).foregroundStyle(Tokens.text4)

                    ForEach(Array(run.calls.enumerated()), id: \.element.id) { i, call in
                        callCard(index: i + 1, call: call)
                    }
                }
                .padding(Tokens.Space.s5)
            }
            .background(Tokens.paper)
            .navigationTitle(run.startedAt.formatted(date: .omitted, time: .standard))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { copyAll() } label: {
                        Label(copied ? "복사됨" : "전체 복사",
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                }
            }
        }
    }

    private func callCard(index: Int, call: GraderCall) -> some View {
        let isOpen = expanded.contains(call.id)
        return VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Button {
                if isOpen { expanded.remove(call.id) } else { expanded.insert(call.id) }
            } label: {
                HStack(spacing: Tokens.Space.s3) {
                    Text("\(index)").font(.mStat).foregroundStyle(Tokens.text3)
                        .frame(width: 28, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(call.stage).font(.mBodyB).foregroundStyle(Tokens.ink)
                            if call.vision {
                                Text("VISION").font(.mMicro)
                                    .foregroundStyle(Tokens.onPrimary)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Tokens.primary, in: RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        // 잘렸는지 판단하려면 한도와 실제 길이를 같이 봐야 한다
                        Text("프롬프트 \(call.prompt.count)자, 출력 \(call.output.count)자, "
                             + "한도 \(call.maxTokens)토큰, \(String(format: "%.1f", call.seconds))초")
                            .font(.mMicro).foregroundStyle(Tokens.text3)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.mMicro).foregroundStyle(Tokens.text4)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                block("보낸 프롬프트", call.prompt, tint: Tokens.text2)
                block("받은 원문", call.output, tint: Tokens.primary)
            }
        }
        .padding(Tokens.Space.s4)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
    }

    private func block(_ title: String, _ body: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.mMicro).foregroundStyle(tint)
            // 원문 그대로. 선택·복사가 되어야 맥으로 옮겨 분석할 수 있다.
            Text(body.isEmpty ? "(비어 있음)" : body)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Tokens.text1)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(Tokens.Space.s3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Tokens.paper2, in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
        }
    }

    private func plainDump() -> String { GraderDump.text(run) }
}

/// 붙여 넣기용 통짜 덤프 — 목록과 상세가 같은 글을 쓴다.
/// 코드펜스로 감싸지 않는다: 안쪽에 ``` 가 든 출력이 흔해서 오히려 깨진다.
enum GraderDump {
    static func text(_ run: GraderRun) -> String {

        var s = """
        # Matths 채점 Pro 온디바이스 모델 실행 기록

        - 시작: \(run.startedAt.formatted(date: .abbreviated, time: .standard))
        - 호출: \(run.calls.count)회, 총 \(Int(run.totalSeconds))초
        - 결과: \(run.failed.map { "실패: \($0)" } ?? (run.itemCount.map { "문항 \($0)개 분석" } ?? "미완"))

        아래는 각 단계에서 모델에 보낸 프롬프트 전문과 모델이 뱉은 원문입니다.
        (vision 표시가 붙은 단계는 시험지 사진이 함께 들어갔습니다. 사진 자체는 여기 없습니다.)

        """
        for (i, c) in run.calls.enumerated() {
            s += """

            ==========================================
            [\(i + 1)/\(run.calls.count)] \(c.stage)\(c.vision ? " (vision)" : "")
            토큰 한도 \(c.maxTokens), 프롬프트 \(c.prompt.count)자, 출력 \(c.output.count)자, \(String(format: "%.1f", c.seconds))초
            ==========================================

            ----- 보낸 프롬프트 -----
            \(c.prompt)

            ----- 받은 원문 -----
            \(c.output.isEmpty ? "(빈 출력)" : c.output)

            """
        }
        return s
    }
}

#endif
