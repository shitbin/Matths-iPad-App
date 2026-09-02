//  SheetGraderLog.swift
//  Matths
//
//  채점 Pro 실행 기록 — 로컬 모델이 실제로 주고받은 것을 통째로 남긴다.
//
//  왜 필요한가: 결과가 이상할 때(엉뚱한 해설, 분석 보류) 화면만 봐서는 원인을 못 짚는다.
//  어떤 프롬프트를 넣었고 모델이 뭐라고 뱉었는지가 있어야 프롬프트를 고칠지,
//  컨텍스트를 늘릴지, 파서를 고칠지 판단할 수 있다. 실제로 2026-07-29 의
//  "$3^{-1/2}$ 를 $3^{2/1}$ 로 읽고 그 위에 해설을 쌓은" 사고가 그랬다.
//
//  **디버그 빌드에서만 쓴다.** 학생 필기가 그대로 들어가므로 배포본에 남기지 않는다.
//  기록은 계정 슬롯 안(DataScope)에 두어 계정이 바뀌면 섞이지 않는다.

import Foundation
import UIKit

/// 한 번의 LLM 호출
struct GraderCall: Codable, Identifiable {
    var id = UUID()
    /// SheetGrader.Stage.rawValue
    var stage: String
    /// 이미지를 함께 넣은 호출인가 (비전 단계)
    var vision: Bool
    var maxTokens: Int
    var prompt: String
    var output: String
    /// 걸린 시간(초)
    var seconds: Double
    var at: Date
}

/// 한 번의 채점 실행
struct GraderRun: Codable, Identifiable {
    var id = UUID()
    var startedAt: Date
    /// 슬롯 안에 복사해 둔 원본 사진 파일명 (썸네일·원본 겸용)
    var imageFile: String?
    var calls: [GraderCall] = []
    /// 끝난 뒤 요약 — 목록에서 한눈에 보려고
    var finishedAt: Date?
    var itemCount: Int?
    var failed: String?

    var totalSeconds: Double {
        guard let f = finishedAt else { return calls.reduce(0) { $0 + $1.seconds } }
        return f.timeIntervalSince(startedAt)
    }
}

@MainActor
enum SheetGraderLog {
    /// 기록 폴더 — 계정 슬롯 안
    static var dir: URL {
        let d = DataScope.url("grader-runs")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    private static var indexURL: URL { dir.appendingPathComponent("index.json") }

    /// 최근 것이 앞으로 온다
    static func load() -> [GraderRun] {
        guard let data = try? Data(contentsOf: indexURL),
              let runs = try? JSONDecoder().decode([GraderRun].self, from: data) else { return [] }
        return runs.sorted { $0.startedAt > $1.startedAt }
    }

    private static func save(_ runs: [GraderRun]) {
        // 무한히 쌓이면 슬롯이 커진다 — 최근 12회만 남기고 사진도 같이 지운다
        let kept = Array(runs.sorted { $0.startedAt > $1.startedAt }.prefix(12))
        let keptFiles = Set(kept.compactMap(\.imageFile))
        if let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) {
            for f in files where f != "index.json" && !keptFiles.contains(f) {
                try? FileManager.default.removeItem(at: dir.appendingPathComponent(f))
            }
        }
        if let data = try? JSONEncoder().encode(kept) {
            try? data.write(to: indexURL, options: .atomic)
        }
    }

    // MARK: 기록하기

    /// 실행 시작 — 사진을 슬롯 안에 복사해 둔다(원본은 임시 파일이라 곧 사라진다)
    static func begin(imagePath: String?) -> UUID {
        var run = GraderRun(startedAt: Date())
        if let src = imagePath, let img = UIImage(contentsOfFile: src) {
            // 원본 그대로면 무거워서 긴 변 1400 으로 줄여 둔다(판독 근거로는 충분)
            let name = "\(run.id.uuidString).jpg"
            if let data = downscaled(img, longSide: 1400).jpegData(compressionQuality: 0.85) {
                try? data.write(to: dir.appendingPathComponent(name))
                run.imageFile = name
            }
        }
        var runs = load(); runs.insert(run, at: 0); save(runs)
        return run.id
    }

    static func append(_ runID: UUID, _ call: GraderCall) {
        var runs = load()
        guard let i = runs.firstIndex(where: { $0.id == runID }) else { return }
        runs[i].calls.append(call)
        save(runs)
    }

    static func finish(_ runID: UUID, itemCount: Int?, failed: String?) {
        var runs = load()
        guard let i = runs.firstIndex(where: { $0.id == runID }) else { return }
        runs[i].finishedAt = Date()
        runs[i].itemCount = itemCount
        runs[i].failed = failed
        save(runs)
    }

    static func imageURL(_ run: GraderRun) -> URL? {
        run.imageFile.map { dir.appendingPathComponent($0) }
    }

    static func clearAll() {
        try? FileManager.default.removeItem(at: dir)
    }

    private static func downscaled(_ img: UIImage, longSide: CGFloat) -> UIImage {
        let long = max(img.size.width, img.size.height)
        guard long > longSide else { return img }
        let scale = longSide / long
        let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        return UIGraphicsImageRenderer(size: size).image { _ in
            img.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
