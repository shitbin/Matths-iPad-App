//  LlamaLogSink.swift
//  Matths
//
//  llama.cpp 가 뱉는 로그를 **파일로 흘린다.**
//
//  왜 필요한가: 2026-07-29, 9B + 비전 프로젝터를 열다 `ggml_abort` 로 죽었다.
//  크래시 리포트는 "어디서 죽었는지"(clip_model_loader::load_tensors)까지만 말해 준다.
//  **왜** 죽었는지는 llama.cpp 가 abort 직전에 stderr 로 남기는 한 줄에 들어 있는데
//  (예: "failed to allocate buffer of size …"), 기기에서는 그 줄이 어디에도 안 남는다.
//  그래서 그 자리를 두 번이나 추측으로 건드렸고, 되던 것을 더 망가뜨렸다.
//
//  이제 추측하지 않는다. 한 줄이 나올 때마다 **즉시 디스크에 쓰고 닫는다** —
//  다음 줄에서 프로세스가 죽어도 앞 줄은 남는다. 그게 이 파일의 유일한 목적이다.
//
//  파일: Documents/llama.log (계정 슬롯 밖 — 크래시 분석은 계정과 무관하다)
//  꺼내는 법:
//    xcrun devicectl device copy from --device <UDID> \
//      --domain-type appDataContainer --domain-identifier kr.matths.app \
//      --source Documents/llama.log --destination /tmp/llama.log

import Foundation
import llama

enum LlamaLogSink {
    private static let queue = DispatchQueue(label: "matths.llamalog")
    private static var installed = false

    static var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("llama.log")
    }

    /// 로드 직전에 부른다. 두 번 불러도 한 번만 걸린다.
    static func install() {
        guard !installed else { return }
        installed = true
        // 새 실행이면 앞의 것을 밀어낸다 — 지난 크래시와 섞이면 읽을 수가 없다.
        rotate()
        write("=== llama 로그 시작 \(Date()) ===\n")
        llama_log_set({ level, text, _ in
            guard let text else { return }
            LlamaLogSink.write("[\(level.rawValue)] " + String(cString: text))
        }, nil)
        // **mtmd/clip 은 별도 로그 통로다.** 이걸 안 걸어 두면 비전이 죽어도
        // 파일에 한 줄도 안 남는다 — 7/29 실기에서 `mtmd_helper_eval_chunks` 가
        // 로그 없이 실패해, 실패한 쪽이 llama 인지 clip 인지조차 알 수 없었다.
        mtmd_log_set({ level, text, _ in
            guard let text else { return }
            LlamaLogSink.write("[clip \(level.rawValue)] " + String(cString: text))
        }, nil)
    }

    /// 우리 쪽 사건도 같은 파일에 섞어 둔다 — 시간순으로 읽혀야 원인이 보인다.
    static func note(_ s: String) { write("### \(s)\n") }

    private static func rotate() {
        let fm = FileManager.default
        let prev = fileURL.deletingLastPathComponent().appendingPathComponent("llama.prev.log")
        try? fm.removeItem(at: prev)
        try? fm.moveItem(at: fileURL, to: prev)   // 직전 실행분은 한 판 남긴다(크래시가 거기 있다)
    }

    private static func write(_ s: String) {
        queue.sync {
            guard let data = s.data(using: .utf8) else { return }
            // **매번 열고 닫는다.** 버퍼에 들고 있으면 abort 때 그대로 증발한다 —
            // 우리가 가장 알고 싶은 마지막 한 줄이 바로 그 버퍼에 있다.
            if let h = try? FileHandle(forWritingTo: fileURL) {
                defer { try? h.close() }
                _ = try? h.seekToEnd()
                try? h.write(contentsOf: data)
            } else {
                try? data.write(to: fileURL, options: .atomic)
            }
        }
    }
}
