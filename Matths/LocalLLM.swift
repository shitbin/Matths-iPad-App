//  LocalLLM.swift
//  Matths
//
//  llama.cpp XCFramework 브리지 — Qwen/DeepSeek와 DEBUG Ling GGUF를 기기 안에서 돌린다.
//
//  API 는 2026-07 기준 최신 이름을 쓴다 (구명은 DEPRECATED):
//    llama_model_load_from_file / llama_init_from_model / llama_vocab_is_eog /
//    llama_memory_* (구 kv_cache API 대체).
//  멀티턴 최적화: 직전 호출과의 "토큰 프리픽스 공통 구간" 은 KV 캐시에 남기고
//  (llama_memory_seq_rm 으로 그 뒤만 제거) 새 구간만 디코드한다 —
//  examples/simple-chat 의 prev_len 델타 패턴의 토큰 판.
//
//  시뮬레이터는 CPU 전용(n_gpu_layers=0, 공식 예제와 동일), 실기기는 Metal 전체 오프로드.

import Foundation
import UIKit       // 비전 재시도에서 사진을 줄인다
import os          // os_proc_available_memory — 남은 메모리 실측
import llama

final class LlamaEngine: LLMEngine, @unchecked Sendable {
    private var model: OpaquePointer?
    private var ctx: OpaquePointer?
    private var vocab: OpaquePointer?
    private var lastTokens: [llama_token] = []   // KV 프리픽스 재사용 기준
    private let queue = DispatchQueue(label: "matths.llama", qos: .userInitiated)
    private var loadedFile: String?

    /// 비전(mtmd) 컨텍스트 — models/ 에 mmproj-*.gguf 가 있을 때만 열린다.
    /// b10159 XCFramework 에 mtmd 심볼·헤더가 포함돼 import llama 로 바로 쓴다.
    private var mtmd: OpaquePointer?

    var isLoaded: Bool { ctx != nil }
    var modelIdentifier: String { queue.sync { loadedFile ?? "" } }
    var visionReady: Bool { mtmd != nil }
    /// 이 컨텍스트가 감당하는 토큰 수 — 대화 이력을 얼마나 실을지 정하는 예산
    var contextTokens: Int { ctx.map { Int(llama_n_ctx($0)) } ?? 0 }

    enum EngineError: LocalizedError {
        case loadFailed(String), decodeFailed(Int32), notLoaded, ctxFull
        var errorDescription: String? {
            switch self {
            case .loadFailed(let p): return "모델을 열지 못함: \(p)"
            case .decodeFailed(let c):
                // 숫자만 던지면 사용자는 아무것도 할 수 없다 — 뜻과 다음 행동을 적는다.
                switch c {
                case -14: return "사진을 읽지 못했습니다 — 기기 메모리가 부족합니다. "
                                 + "다른 앱을 닫고 다시 시도해 주세요."
                case -10, -11: return "사진 파일을 열지 못했습니다 — 다시 찍거나 다른 사진으로 시도해 주세요."
                case -12, -13: return "사진과 질문을 함께 넣지 못했습니다 (토크나이즈 실패)."
                default: return "디코드 실패 (\(c))"
                }
            case .notLoaded: return "모델이 로드되지 않음"
            case .ctxFull: return "대화가 컨텍스트 한도에 닿음 — 대화 지우기 후 다시"
            }
        }
    }

    func load(modelPath: String) throws {
        try queue.sync {
            guard ctx == nil else { return }
            // llama.cpp 로그를 파일로 돌린다 — abort 직전 줄을 잃지 않기 위해서다.
            // (2026-07-29: 그 줄이 없어서 원인을 두 번 추측했고 둘 다 틀렸다)
            LlamaLogSink.install()
            LlamaLogSink.note("load 시작: \((modelPath as NSString).lastPathComponent)")
            llama_backend_init()
            let big = ModelDownloader.hasLargeMemory
            let is9B = (modelPath as NSString).lastPathComponent.contains("9B")
            let isDeepSeek7B = (modelPath as NSString).lastPathComponent
                .contains("DeepSeek-R1-Distill-Qwen-7B")
            let isLing3 = (modelPath as NSString).lastPathComponent
                .contains("Ling-3.0-tiny")
            let isQwen25VL = (modelPath as NSString).lastPathComponent
                .contains("Qwen2.5-VL")
            // 메모리 빠듯한 조합(8GB 기기 + 9B)에서는 GPU 오프로드를 줄여야 한다.
            // Metal 로 올린 가중치는 실제 메모리를 점유하고 회수도 안 되지만,
            // CPU 쪽에 남은 층은 mmap(파일 백업, 정리 가능)이라 압박 시 회수된다.
            // 전부 올리면 로드 도중 jetsam 에 죽는다 — 실기 확인(8GB, 9B 경량).
            let tightVisionMemory = !big && is9B
            let tightTextMemory = !big && (isDeepSeek7B || isLing3)
            let tightMemory = tightVisionMemory || tightTextMemory
            // 비전을 켤 참인가 — 오프로드·디바이스 선택을 여기서 같이 정한다.
            // (#if 안에 두면 시뮬 빌드에서 스코프 밖이 된다)
            // 비전을 켤 참인가.
            //
            // 기본 규칙: 메모리가 빠듯한 조합(8GB + 9B)에서는 프로젝터를 얹지 않는다.
            // 본체+프로젝터+계산버퍼가 한도를 넘어 로드 중 jetsam 에 죽기 때문이다.
            //
            // 그런데 그 규칙 때문에 **9B 로는 시험지 사진을 아예 못 본다.**
            // 8GB 기기에서 9B 를 고르면 `loadFailed("mmproj 없음")` 으로 끝난다
            // (2026-07-29 실기 — 9B 경량으로 바꿔 돌려 보려다 여기서 막혔다).
            // 디버그로 체급을 **직접 고른 경우**는 그 실험이 목적이므로 빗장을 푼다.
            // 죽으면 아래 크래시 래치가 다음 실행에서 자동으로 비전을 꺼 준다.
            // 조건은 **하나뿐이다: 메모리가 빠듯한가.**
            //
            // 예전엔 `!tightMemory && !hasLargeMemory` 였다. 뒤 조건이 뒤집혀 있어서
            // **메모리가 넉넉한 기기일수록 비전이 꺼졌다.** 그 결과 AI 튜터의 사진
            // 첨부 버튼(`tutor.visionAvailable` 로 그린다)이 아예 안 나타났고,
            // "사진 첨부 기능을 넣어라" 는 말을 몇 번이나 듣게 됐다 —
            // 기능은 있었고, 켜지는 조건이 틀렸던 것이다. (2026-07-29)
            var visionAllowed = !tightVisionMemory
            #if DEBUG
            if ModelDownloader.debugForcedTier != nil { visionAllowed = true }
            #endif
            let willTryVision = visionAllowed
                && ModelDownloader.visionFileReady(near: modelPath)
                && ModelDownloader.visionFileReady(near: modelPath)
                && !ModelDownloader.visionDisabled(for: (modelPath as NSString).lastPathComponent)

            var mparams = llama_model_default_params()
            #if targetEnvironment(simulator)
            mparams.n_gpu_layers = 0          // 시뮬은 CPU 전용 (공식 예제 규약)
            #else
            // 기본은 전체 오프로드(Metal). 단 메모리가 빠듯한 조합은 GPU 버퍼에
            // 가중치를 올리는 순간 할당이 실패하고, llama.cpp 가 그 널을
            // 검사 없이 역참조해 ggml_metal_buffer_is_shared 에서 즉사한다
            // (기기 리포트 0604·0605 — 부분 오프로드 12, 전체 99 둘 다 동일).
            // 그 티어만 CPU 경로로 간다: 가중치는 mmap(파일 백업)이라 실제 메모리를
            // 덜 잡고 압박 시 회수도 된다. 대신 느리다 — 사용자가 감수한 선택.
            // 비전을 켤 참이면 가중치를 GPU 상주로 올리지 않는다. Metal 버퍼는
            // 실제 메모리를 잡고 회수되지 않아서, 프로젝터·계산버퍼와 합쳐 한도를 넘는다.
            // CPU 경로는 mmap(파일 백업)이라 압박 시 회수된다 — 느리지만 죽지 않는다.
            // DeepSeek 7B 텍스트는 4K KV/batch 제한은 유지하되 3.6GB Q3 가중치는
            // M2 8GB의 Metal에 들어간다. 종전에는 'tightTextMemory'를 비전/9B와
            // 같은 CPU-only 조건으로 묶어 실기에서 동일 깨진 토큰을 반복했다.
            mparams.n_gpu_layers = (tightVisionMemory || willTryVision) ? 0 : 99
            #endif

            // ⚠️ n_gpu_layers = 0 은 **가중치만** CPU 로 보낸다. 계산 그래프는 여전히
            //    Metal 백엔드에 잡히고, 그 예약(graph_reserve)에서 버퍼 할당이 실패하면
            //    llama.cpp 가 널을 검사 없이 역참조해 ggml_metal_buffer_is_shared 에서
            //    즉사한다 — 기기 리포트 162054·162124·162152 가 전부 이 자리다.
            //    그래서 저메모리 티어에서는 **디바이스 목록에서 Metal 을 아예 뺀다.**
            //    (llama_model_params.devices 는 NULL 종단 목록. CPU 만 남긴다)
            let cpuOnly = tightVisionMemory || willTryVision
            var devices: [ggml_backend_dev_t?] = []
            if cpuOnly {
                for i in 0..<ggml_backend_dev_count() {
                    if let d = ggml_backend_dev_get(i),
                       ggml_backend_dev_type(d) == GGML_BACKEND_DEVICE_TYPE_CPU {
                        devices.append(d)
                    }
                }
                devices.append(nil)      // NULL 종단
            }

            // devices 포인터는 로드가 끝날 때까지 살아 있어야 한다
            let loaded: OpaquePointer? = devices.isEmpty
                ? llama_model_load_from_file(modelPath, mparams)
                : devices.withUnsafeMutableBufferPointer { buf -> OpaquePointer? in
                    mparams.devices = buf.baseAddress
                    return llama_model_load_from_file(modelPath, mparams)
                }
            guard let m = loaded else {
                llama_backend_free()
                throw EngineError.loadFailed((modelPath as NSString).lastPathComponent)
            }
            // ── 비전 프로젝터를 **컨텍스트보다 먼저** 연다 ───────────────────
            //
            // 이유가 전부 여기 있다: llama_init_from_model 은 실패하면 nil 을 주지만
            // (=Swift 로 복구 가능), mtmd_init_from_file 은 실패하면 ggml_abort 로
            // 프로세스를 죽인다(=복구 불가). 그러면 **죽을 수 있는 쪽을 메모리가
            // 가장 넉넉할 때 먼저** 태워야 한다. KV 를 먼저 잡아 놓고 프로젝터를
            // 올리려다 죽은 것이 7/29 새벽 크래시 0558·0600 의 실체였다.
            //
            // 열 조건: 프로젝터 파일이 있고, 이 모델로 지난번에 죽은 적이 없고,
            // 메모리가 빠듯한 조합(8GB + 9B)이 아닐 것. 4B(2.55GB)+프로젝터(0.64GB)는
            // 8GB 기기에서도 들어간다 — 그래서 기기 전면 차단은 과했다.
            let dir = (modelPath as NSString).deletingLastPathComponent
            let modelFile = (modelPath as NSString).lastPathComponent
            // 프로젝터는 **여는 모델 기준**으로 고른다 (권장 티어 기준이 아니라).
            let wantMM = ModelDownloader.mmprojFile(for: modelFile)
            var visionOn = false
            if willTryVision,
               !ModelDownloader.visionDisabled(for: modelFile),
               let files = try? FileManager.default.contentsOfDirectory(atPath: dir),
               let mm = files.first(where: {
                   $0 == wantMM && LocalAIModelPack.fileReady($0)
               }) {
                // ── 넣기 전에 **잰다.** ─────────────────────────────────
                // 프로젝터는 mmap 이 아니라 **통짜 malloc** 이다(본체는 mmap).
                // 자리가 모자라면 llama.cpp 는 nil 을 돌려주지 않고 ggml_abort 로
                // 앱을 그대로 죽인다 — 실측 로그 두 판:
                //   876MB 판: attempted to allocate 875.61 MB → abort
                //   592MB 판(Q8_0 으로 직접 줄인 것): 591.92 MB → 또 abort
                // 무료 개인 팀은 increased-memory-limit / extended-virtual-addressing
                // 을 서명할 수 없어(7/29 확인: "Personal development teams … do not
                // support") 기본 한도 안에서 버텨야 한다.
                // 그래서 죽는 대신 **미리 재고 비켜간다.** 비전만 꺼지고 텍스트는 산다.
                let mmPath = (dir as NSString).appendingPathComponent(mm)
                let mmBytes = ((try? FileManager.default
                    .attributesOfItem(atPath: mmPath)[.size]) as? NSNumber)?.intValue ?? 0
                let freeBytes = Int(os_proc_available_memory())
                let mb = { (b: Int) in String(format: "%.0fMB", Double(b) / 1_048_576) }

                // **보고된 숫자를 믿지 않고 직접 잡아 본다.**
                //
                // os_proc_available_memory() 는 시뮬레이터에서 0 을 돌려준다.
                // 그걸 "메모리 없음" 으로 읽는 바람에 비전이 통째로 꺼졌고,
                // AI 튜터의 사진 첨부가 "기능이 없는" 것처럼 보였다(2026-07-29).
                // 반대 방향으로도 틀린다 — 실기에서 5000MB 남았다고 해 놓고
                // ggml 의 vm_allocate 가 592MB 에서 튕긴 적이 있다.
                //
                // 그래서 판단 근거는 **실제로 그 크기를 잡아 봤는가** 하나로 둔다.
                // 잡히면 바로 놓아준다. 이게 우리가 진짜로 알고 싶은 것이다.
                var roomOK = true
                if mmBytes > 0 {
                    if let probe = malloc(mmBytes) {
                        memset(probe, 0, min(mmBytes, 1 << 20))   // 안 만지면 커밋이 안 돼 거짓 성공이 된다
                        free(probe)
                    } else {
                        roomOK = false
                    }
                }
                LlamaLogSink.note("비전 메모리 점검: 프로젝터 \(mb(mmBytes))"
                    + " · 확보 \(roomOK ? "성공" : "실패")"
                    + " · 보고된 남음 \(freeBytes > 0 ? mb(freeBytes) : "(측정 불가)")")

                if !roomOK {
                    // **던지지 않는다.** 비전만 접고 텍스트 채점은 그대로 간다 —
                    // 여기서 throw 하면 모델 로드 전체가 무너져 앱이 아무것도 못 한다.
                    LlamaLogSink.note("비전 건너뜀 — \(mb(mmBytes)) 를 잡지 못했다. 텍스트로 계속한다.")
                    UserDefaults.standard.set(
                        "메모리 부족(프로젝터 \(mb(mmBytes)) 확보 실패)",
                        forKey: "matths.visionSkipReason")
                } else {
                UserDefaults.standard.removeObject(forKey: "matths.visionSkipReason")
                LlamaLogSink.note("mtmd 로드 직전: \(mm)")
                var mp = mtmd_context_params_default()
                // 프로젝터는 CPU 로만. use_gpu=true 면 clip 로더가 Metal 버퍼 할당
                // 실패를 널 검사 없이 역참조해 즉사한다(기기 리포트 0558).
                mp.use_gpu = false
                mp.n_threads = Int32(max(4, ProcessInfo.processInfo.activeProcessorCount - 2))
                // Qwen2.5-VL은 1,024 토큰 미만에서 grounding 정확도가 급락한다고
                // mtmd 자체가 경고한다. 3B 판독기는 4K 컨텍스트와 실기 여유가
                // 확인됐으므로 최소/최대를 1,024로 고정한다. 9B 경량은 종전의
                // 768 상한을 유지해 메모리·컨텍스트 회귀를 만들지 않는다.
                mp.image_min_tokens = isQwen25VL ? 1_024 : 0
                mp.image_max_tokens = isQwen25VL ? 1_024 : 768
                // 죽을 수 있는 호출 — 표식을 먼저 디스크에 적는다
                // 죽을 수 있는 구간의 **시작**에 표식을 적는다. 지우는 것은 컨텍스트까지
                // 다 만든 뒤다 — mtmd 직후에 지웠더니, 그 다음 llama_init_from_model 이
                // 메모리 부족으로 죽으면서 래치가 안 걸려 **크래시 루프**가 났다
                // (기기 리포트 081616·081617·081634·081641·081645 다섯 건).
                ModelDownloader.markVisionAttempt(modelFile)
                mtmd = mtmd_init_from_file((dir as NSString).appendingPathComponent(mm), m, mp)
                visionOn = mtmd != nil
                LlamaLogSink.note("mtmd 로드 결과: \(visionOn ? "성공" : "실패(nil)")")
                }   // roomOK
            }

            LlamaLogSink.note("컨텍스트 생성 직전")
            var cparams = llama_context_default_params()
            // KV 메모리 상한. 8GB 기기에서 9B(경량)를 돌릴 때는 모델만 4GB라
            // KV 까지 얹으면 jetsam 선을 넘는다 — 컨텍스트를 최소로 줄인다.
            // 무료 계정은 메모리 확장 권한(increased-memory-limit) 서명이 불가라
            // 기본 한도 안에서 버텨야 한다 — 컨텍스트를 크게 줄여 KV 를 최소화.
            // 컨텍스트 예산 — 막는 것은 모델이 아니라 KV 캐시 메모리다.
            // 이 모델 실측: 32층 · KV헤드 4 · head_dim 256 → f16 기준 토큰당 128KB.
            //   f16  4K=0.54GB  8K=1.07GB  16K=2.15GB  (256K=34GB, 불가)
            // KV 를 8비트로 잡으면 절반이라 같은 메모리로 두 배를 쓴다. 품질 손실은
            // 사실상 체감되지 않는 것이 정설이라 저사양 티어에 특히 이득이 크다.
            cparams.type_k = GGML_TYPE_Q8_0
            cparams.type_v = GGML_TYPE_Q8_0
            // 8GB + 9B(tight): 모델(mmap) 2.97GB + KV 48MB(q8 768).
            // 768 은 취향이 아니라 **실기에서 유일하게 살아 돌아온 값**이다
            // (인수인계 E, 7/29 06:10 — IQ2_XXS + CPU/mmap + ctx768/batch128 + 비전 제외).
            // 8K 로 열면 이 티어에 KV 0.54GB 가 더 붙는데, 그 선이 정확히 죽던 자리라
            // 기기 재검증 없이 넓힐 수 없다 — 짧은 대화가 죽는 앱보다 낫다.
            // 12GB+ 기기: 16K 까지 열어도 KV 1.07GB 수준.
            // 비전이 켜지면 프로젝터(0.64~0.9GB)와 ViT 계산버퍼가 이미 자리를 먹었다.
            // 그만큼 KV 를 양보한다 — 안 그러면 컨텍스트 생성이 실패한다.
            //   8GB + 4B + 비전:  모델 2.55 + 프로젝터 0.64 + KV(8K,q8) ≈ 3.8GB
            // 비전이 켜지면 프로젝터(0.64GB)와 ViT 계산버퍼가 이미 자리를 먹었다.
            // 여기서 KV 만 줄이는 걸로는 부족했다 — 실기기에서 죽은 곳은 KV 가 아니라
            // **계산 그래프 예약**(graph_reserve → Metal 버퍼 할당)이었다.
            // 그래서 저메모리 기기 + 비전이면 9B-tight 와 같은 보수 구성으로 간다.
            let bigMem = ModelDownloader.hasLargeMemory
            let visionTight = visionOn && !bigMem
            // 컨텍스트 길이.
            //
            // 7/29 에 "비전이면 3072" 로 올렸다가 9B 경량이 로드 중에 죽어서 되돌렸고,
            // 그때는 원인을 KV 로 짐작했다. **틀렸다.** 자가진단으로 실제로 재 보니
            // 죽은 자리는 KV 가 아니라 컴퓨트 버퍼였고(127.71MB 할당 실패), 그건 이제
            // n_batch 를 절반씩 줄이며 다시 잡는다. KV 는 이 모델에서 거의 공짜다 —
            // 하이브리드(어텐션 8층 + 나머지 recurrent)라 768셀에 12.75MiB 였다.
            //
            // 그리고 768 로 두면 **비전이 반드시 실패한다**: 이미지 한 장이
            // image_max_tokens(768) 을 그대로 먹어 뒤따르는 텍스트가 들어갈 자리가
            // 없다. 실측 로그: "failed to find a memory slot for batch of size 23".
            // 그래서 비전을 켠 판만 이미지 + 발문 + 답이 함께 앉을 만큼 준다.
            // **9B 만 손댄다.** 4B 비전은 원래 이 식(visionTight → 4096)으로 잘 돌던
            // 경로다(인수인계 H 실증). 7/29 에 내가 비전 전체를 2560 으로 묶었다가
            // 4B 까지 같이 죽였다 — 되던 것을 건드린 쪽이 잘못이다.
            // 9B 는 tightMemory 라 768 이 되는데, 그러면 이미지 토큰 768 이 컨텍스트를
            // 통째로 먹어 뒤 텍스트가 앉을 자리가 없다("failed to find a memory slot").
            let ctxDefault = UInt32(
                tightTextMemory ? 4096 : (tightVisionMemory ? 768 : (visionTight ? 4096 : 16384)))
            cparams.n_ctx = (visionOn && tightVisionMemory) ? 2560 : ctxDefault
            // n_batch 는 계산 버퍼 크기를 직접 정한다 — 죽은 자리가 여기다
            cparams.n_batch = (tightMemory || visionTight) ? 128 : 512
            let threads = Int32(max(4, ProcessInfo.processInfo.activeProcessorCount - 2))
            cparams.n_threads = threads
            cparams.n_threads_batch = threads
            // ── 컴퓨트 버퍼는 **처음부터 들어가는 값으로** 잡는다 ──────────
            // 한때 "실패하면 n_batch 를 절반씩 줄여 재시도" 를 넣었다. **못 쓴다.**
            // llama_init_from_model 은 이 자리에서 실패하면 nil 을 돌려주는 게 아니라
            // 그냥 죽는다 — 실기 크래시 리포트(7/29 22:02·22:03):
            //   ggml_abort ← ggml_init ← ggml_backend_sched_split_graph
            //              ← llama_context::graph_reserve
            // 첫 시도에서 프로세스가 사라지니 재시도 코드는 실행조차 안 되고,
            // 사용자에게는 "앱이 그냥 꺼진다" 로만 보인다.
            //
            // 그래서 재시도가 아니라 **실측으로 확인된 값**을 쓴다:
            //   비전 켜짐 + n_ctx 2560 → n_batch 128 은 죽고, **64 는 산다**
            //   (7/29 자가진단에서 64 로 로드·사진 추론까지 완주. 153초)
            if visionOn && tightVisionMemory {
                // 9B 경량 + 비전에서만. 실측: n_batch 128 은 graph_reserve 에서
                // ggml_abort(앱이 그냥 꺼진다), 64 는 로드·추론까지 완주.
                // **4B 에는 손대지 않는다** — 128/기본 ubatch 로 잘 돌던 경로다.
                cparams.n_batch = 64
                cparams.n_ubatch = 64
                // ubatch 를 32 로 낮춰도 실패 크기가 **263.29MB 로 한 바이트도
                // 안 변했다**(7/29 15:51 실기). 즉 이 버퍼는 ubatch 가 아니라
                // 컨텍스트 길이에 딸린 것이다. 가설이 틀렸으므로 되돌린다.
            }
            // ── 자리가 모자라면 **컨텍스트를 줄여** 다시 잡는다 ──────────────
            //
            // 이 재시도는 안전하다. 실기에서 확인한 실패 방식이 그렇다:
            //   n_batch 128 → graph_reserve 안에서 ggml_abort (앱이 죽는다)
            //   n_batch  64 → llama_init_from_model 이 **nil 을 돌려준다** (죽지 않는다)
            // 그래서 64 로 고정해 둔 상태에서만 되풀이한다. 한때 "실패하면 배치를
            // 절반씩" 을 넣었다가 첫 시도에서 앱이 사라졌던 것과는 다른 자리다.
            //
            // 줄이는 것은 **컨텍스트**지 사진이 아니다. 사진을 깎으면 시험지에서
            // 읽을 게 없어진다 — 그건 이미 두 번 철회한 길이다.
            var c: OpaquePointer? = nil
            for ctxTry in [cparams.n_ctx, UInt32(1792), UInt32(1280)] {
                if visionOn && ctxTry < 1024 { break }      // 이미지 토큰이 못 앉는다
                cparams.n_ctx = ctxTry
                LlamaLogSink.note("컨텍스트 생성 시도: n_ctx=\(ctxTry) "
                                  + "n_batch=\(cparams.n_batch) n_ubatch=\(cparams.n_ubatch)")
                c = llama_init_from_model(m, cparams)
                if c != nil { LlamaLogSink.note("컨텍스트 확보: n_ctx=\(ctxTry)"); break }
                LlamaLogSink.note("컨텍스트 실패 — 더 줄여서 다시 간다")
                if !visionOn { break }                      // 텍스트 전용은 원래 여유가 있다
            }
            guard let c else {
                llama_model_free(m)
                llama_backend_free()
                throw EngineError.loadFailed("context")
            }
            // 여기까지 왔으면 비전 포함 전 구간을 살아서 통과했다 — 이제 표식을 지운다
            ModelDownloader.markVisionOK()
            UserDefaults.standard.set(visionOn ? modelFile : "", forKey: "matths.visionActive")
            model = m
            ctx = c
            vocab = llama_model_get_vocab(m)
            loadedFile = (modelPath as NSString).lastPathComponent

        }
    }

    func unload() {
        queue.sync {
            if let mt = mtmd { mtmd_free(mt) }
            if let c = ctx { llama_free(c) }
            if let m = model { llama_model_free(m) }
            mtmd = nil; ctx = nil; model = nil; vocab = nil; loadedFile = nil
            lastTokens = []
            llama_backend_free()
        }
    }

    // MARK: 비전 생성 — 이미지 1장 + 프롬프트 (Pro 사진분석·사진 질문)
    //
    // 이미지 임베딩은 토큰열로 표현되지 않아 프리픽스 캐시를 쓸 수 없다 —
    // 이 턴은 메모리를 비우고 전체 평가한다 (mtmd_helper_eval_chunks 가
    // 텍스트 청크는 llama_decode, 이미지 청크는 인코드→디코드로 자동 처리).
    /// 사진 1장 + 프롬프트 (프롬프트에 <__media__> 마커 필수).
    ///
    /// 실패하면 **여기서 사진을 줄이지 않는다.** 한 번 그렇게 고쳤다가 지적받았다:
    /// 시험지에서 해상도를 깎으면 OCR 이 그대로 죽는다. 전체 사진이 안 들어가면
    /// 해상도를 유지한 채 잘라서 여러 번 읽어야 한다 — 그 판단은 무엇을 읽는지
    /// 아는 쪽(SheetGrader)이 한다. 엔진은 실패를 정직하게 올린다.
    func generateVision(prompt: String, imagePath: String, params: LLMGenParams,
                        onToken: @escaping (String) -> Bool) throws -> String {
        try queue.sync {
            guard let ctx, let vocab else { throw EngineError.notLoaded }
            guard let mtmd else { throw EngineError.loadFailed("mmproj 없음") }

            let wrap = mtmd_helper_bitmap_init_from_file(mtmd, imagePath, false)
            guard let bmp = wrap.bitmap else { throw EngineError.decodeFailed(-10) }
            defer { mtmd_bitmap_free(bmp) }

            guard let chunks = mtmd_input_chunks_init() else { throw EngineError.decodeFailed(-11) }
            defer { mtmd_input_chunks_free(chunks) }

            llama_memory_clear(llama_get_memory(ctx), true)
            lastTokens = []

            var rc: Int32 = -1
            var newPast: llama_pos = 0
            prompt.withCString { cstr in
                var text = mtmd_input_text(text: cstr, text_len: strlen(cstr),
                                           add_special: false, parse_special: true)
                var bitmaps: [OpaquePointer?] = [bmp]
                bitmaps.withUnsafeMutableBufferPointer { bp in
                    rc = mtmd_tokenize(mtmd, chunks, &text, bp.baseAddress, 1)
                }
            }
            // 실패 코드를 **뭉개지 않는다.** -12/-13 으로 접어 버리면 로그를 봐도
            // 무엇이 잘못됐는지 알 수 없다(7/29 에 그래서 한 판을 통째로 날렸다).
            LlamaLogSink.note("mtmd_tokenize rc=\(rc) · 청크 \(mtmd_input_chunks_size(chunks))"
                + " · n_ctx=\(llama_n_ctx(ctx)) · n_batch=\(llama_n_batch(ctx))")
            guard rc == 0 else { throw EngineError.decodeFailed(rc == 1 ? -12 : -13) }
            // 배치도 컨텍스트 설정을 따른다 (상수는 저사양 티어에서 abort 를 부른다)
            let nBatchV = Int32(max(1, Int(llama_n_batch(ctx))))
            // 한 번만 부른다. **memory_clear 로 지우고 되풀이하지 않는다.**
            //
            // 7/29 에 "실패하면 메모리 비우고 다시" 를 넣었다가, 성공한 판에서도
            //   find_slot: non-consecutive token position 1 after 1 …
            // 경고가 쏟아지며 **응답이 0 토큰으로 비어 나왔다**(실기 89.6초/0토큰).
            // 그 루프가 없던 판에서는 같은 사진으로 43 토큰이 정상적으로 나왔다.
            // 위치 장부를 건드린 쪽이 원인이므로 손대기 전으로 되돌린다.
            var newPastOut: Int32 = 0
            let evalRC = mtmd_helper_eval_chunks(mtmd, ctx, chunks, 0, 0,
                                                 nBatchV, true, &newPastOut)
            newPast = newPastOut
            if evalRC != 0 { LlamaLogSink.note("이미지 인코딩 실패 rc=\(evalRC)") }
            guard evalRC == 0 else { throw EngineError.decodeFailed(-14) }

            // 이후는 텍스트 경로와 동일한 샘플링 루프 (반복 패널티 1.0 = 공식 카드값)
            let chain = llama_sampler_chain_init(llama_sampler_chain_default_params())
            llama_sampler_chain_add(
                chain,
                llama_sampler_init_penalties(
                    llama_vocab_n_tokens(vocab), 64, 1.0, 0.0, params.presencePenalty))
            llama_sampler_chain_add(chain, llama_sampler_init_top_k(params.topK))
            llama_sampler_chain_add(chain, llama_sampler_init_top_p(params.topP, 1))
            llama_sampler_chain_add(chain, llama_sampler_init_temp(params.temperature))
            llama_sampler_chain_add(chain, llama_sampler_init_dist(UInt32(truncatingIfNeeded: imagePath.hashValue)))
            defer { llama_sampler_free(chain) }

            var out = ""
            var pending: [CChar] = []
            let nCtx = Int(llama_n_ctx(ctx))
            var produced = 0
            // 비전 경로도 남은 방 안에서만 뽑는다 — 이미지 토큰이 컨텍스트를 크게
            // 먹으므로 maxTokens 를 그대로 믿으면 생성 도중 KV 가 넘친다.
            let visionBudget = min(Int(params.maxTokens),
                                   max(0, nCtx - Int(llama_memory_seq_pos_max(llama_get_memory(ctx), 0)) - 8))
            for _ in 0..<visionBudget {
                let id = llama_sampler_sample(chain, ctx, -1)
                if llama_vocab_is_eog(vocab, id) { break }
                produced += 1
                if let piece = pieceOf(id, vocab: vocab, pending: &pending) {
                    out += piece
                    if !onToken(piece) { break }
                }
                var one = id
                let batch = llama_batch_get_one(&one, 1)
                guard llama_decode(ctx, batch) == 0 else { throw EngineError.decodeFailed(-15) }
                if Int(newPast) + produced >= nCtx - 8 { break }
            }
            if !pending.isEmpty, let tail = String(bytes: pending.map { UInt8(bitPattern: $0) }, encoding: .utf8) {
                out += tail
                _ = onToken(tail)
            }
            return out
        }
    }

    // MARK: 생성

    func generate(prompt: String, params: LLMGenParams,
                  onToken: @escaping (String) -> Bool) throws -> String {
        try queue.sync {
            guard let ctx, let vocab else { throw EngineError.notLoaded }

            // ── 토크나이즈 (ChatML 특수 토큰 파싱, BOS 없음 — Qwen 규약)
            let tokens = try tokenize(prompt, vocab: vocab)

            // 한도 검사를 KV 를 건드리기 **전에** 한다. 잘라 놓고 throw 하면
            // 실제 KV 와 lastTokens 가 어긋난 채 남아 다음 턴이 오염된다.
            let nCtx = Int(llama_n_ctx(ctx))
            // 남은 방을 실제로 계산한다.
            //
            // 예전엔 `tokens.count + maxTokens/4 < nCtx` 만 봤다. 출력분을 4분의 1만
            // 예약한 셈이라, 프롬프트가 길면 검사는 통과해 놓고 **생성 도중** KV 가
            // 넘쳐 llama_decode 가 실패했다. 그 예외가 채점 화면에서
            // "이 문항 분석이 실패했습니다 · 분석 보류" 로 나왔다 — 시험지 뒤쪽
            // 긴 문항들만 줄줄이 보류로 떨어진 게 이것이다(2026-07-29 사용자 리포트).
            //
            // 이제 방이 모자라면 **실패시키는 대신 짧게 답하게** 한다. 잘린 JSON 이라도
            // 손에 쥐면 상위의 복구 파서가 살려 낼 수 있지만, 예외는 아무것도 못 남긴다.
            let room = nCtx - tokens.count - 8      // 8 = 여유(마지막 토큰·특수토큰)
            guard room >= 64 else { throw EngineError.ctxFull }
            let budget = min(Int(params.maxTokens), room)

            // ── KV 프리픽스 재사용: 공통 구간은 남기고 그 뒤만 디코드
            var common = 0
            while common < min(tokens.count, lastTokens.count),
                  tokens[common] == lastTokens[common] { common += 1 }
            // 전부 일치해도 마지막 1토큰은 다시 디코드해야 로짓이 나온다
            if common == tokens.count { common = max(0, common - 1) }
            let mem = llama_get_memory(ctx)
            llama_memory_seq_rm(mem, 0, llama_pos(common), -1)

            // ── 새 구간 프롬프트 디코드 (컨텍스트의 실제 n_batch 단위)
            // 상수 512 로 밀어 넣으면 저사양 티어(n_batch 128)에서 한도를 넘겨
            // llama_decode 내부 ggml_abort 로 앱이 즉사한다 — 기기 리포트 0608.
            let nBatch = max(1, Int(llama_n_batch(ctx)))
            var pos = common
            while pos < tokens.count {
                let end = min(pos + nBatch, tokens.count)
                var chunk = Array(tokens[pos..<end])
                let batch = llama_batch_get_one(&chunk, Int32(chunk.count))
                guard llama_decode(ctx, batch) == 0 else { throw EngineError.decodeFailed(-1) }
                pos = end
            }

            // ── 샘플러 체인 (Qwen 공식 권장 순서: penalties → top_k → top_p → min_p → temp → dist)
            // 두 번째 인자는 penalty_repeat(llama.h: 1.0 = 비활성)이고, Qwen3.5 공식
            // 모델 카드값이 repetition 1.0 이다. 근거 없는 1.12 가 들어가 있어서
            // 규약(AITutor.Params 주석)과 실제 샘플링이 어긋나 있었다 — 카드값으로 되돌린다.
            let chain = llama_sampler_chain_init(llama_sampler_chain_default_params())
            llama_sampler_chain_add(
                chain,
                llama_sampler_init_penalties(
                    llama_vocab_n_tokens(vocab), 64, 1.0, 0.0, params.presencePenalty))
            llama_sampler_chain_add(chain, llama_sampler_init_top_k(params.topK))
            llama_sampler_chain_add(chain, llama_sampler_init_top_p(params.topP, 1))
            if params.minP > 0 {
                llama_sampler_chain_add(chain, llama_sampler_init_min_p(params.minP, 1))
            }
            llama_sampler_chain_add(chain, llama_sampler_init_temp(params.temperature))
            llama_sampler_chain_add(chain, llama_sampler_init_dist(UInt32(truncatingIfNeeded: prompt.hashValue)))
            defer { llama_sampler_free(chain) }

            // ── 토큰 루프
            var produced: [llama_token] = []
            var out = ""
            var pending: [CChar] = []          // UTF-8 이 토큰 경계에서 쪼개질 때 보관
            var history = tokens

            for _ in 0..<budget {
                let id = llama_sampler_sample(chain, ctx, -1)
                if llama_vocab_is_eog(vocab, id) { break }
                produced.append(id)

                // 디토크나이즈 조각 (불완전 UTF-8 은 다음 토큰까지 미룸)
                if let piece = pieceOf(id, vocab: vocab, pending: &pending) {
                    out += piece
                    if !onToken(piece) { break }   // 중단 — 이 토큰은 아직 KV 에 없다
                }

                var one = id
                let batch = llama_batch_get_one(&one, 1)
                guard llama_decode(ctx, batch) == 0 else { throw EngineError.decodeFailed(-2) }
                // history 는 "KV 에 실제로 들어간 것" 과 같아야 한다. 디코드 전에 넣으면
                // 중단 시 1토큰 길어져 다음 턴 프리픽스 계산이 밀린다(맥락 상실).
                history.append(id)
                if history.count >= nCtx - 8 { break }
            }
            if !pending.isEmpty, let tail = String(bytes: pending.map { UInt8(bitPattern: $0) }, encoding: .utf8) {
                out += tail
                _ = onToken(tail)
            }
            lastTokens = history
            return out
        }
    }

    // MARK: 저수준 헬퍼

    private func tokenize(_ text: String, vocab: OpaquePointer) throws -> [llama_token] {
        let utf8 = Array(text.utf8)
        var buf = [llama_token](repeating: 0, count: utf8.count + 16)
        var n = llama_tokenize(vocab, text, Int32(utf8.count), &buf, Int32(buf.count),
                               /*add_special*/ false, /*parse_special*/ true)
        if n < 0 {                        // 버퍼 부족 — 필요한 만큼 재할당 후 재호출
            buf = [llama_token](repeating: 0, count: Int(-n))
            n = llama_tokenize(vocab, text, Int32(utf8.count), &buf, Int32(buf.count), false, true)
        }
        guard n >= 0 else { throw EngineError.decodeFailed(n) }
        return Array(buf.prefix(Int(n)))
    }

    private func pieceOf(_ id: llama_token, vocab: OpaquePointer, pending: inout [CChar]) -> String? {
        var buf = [CChar](repeating: 0, count: 64)
        var n = llama_token_to_piece(vocab, id, &buf, Int32(buf.count), 0, /*special*/ false)
        if n < 0 {
            buf = [CChar](repeating: 0, count: Int(-n))
            n = llama_token_to_piece(vocab, id, &buf, Int32(buf.count), 0, false)
        }
        guard n > 0 else { return nil }
        pending.append(contentsOf: buf.prefix(Int(n)))
        let bytes = pending.map { UInt8(bitPattern: $0) }
        if let s = String(bytes: bytes, encoding: .utf8) {
            pending.removeAll()
            return s
        }
        return nil                        // 아직 불완전한 멀티바이트 — 다음 토큰과 합침
    }
}

// MARK: - 실기기용 모델 다운로더
//
// 앱스토어 규약: 5GB 모델은 번들 불가(바이너리 한도) — 첫 실행 다운로드가 유일 경로.
// 시뮬레이터 개발은 사이드로드(문서 참조)라 이 경로를 안 탄다.

@MainActor
final class ModelDownloader: NSObject, ObservableObject {
    static let shared = ModelDownloader()

    enum State: Equatable {
        case idle, downloading(Double), done, failed(String)
    }
    @Published var state: State = .idle

    /// 2티어 정책 (26-07-29 팀 결정): 12/16GB 기기 = 9B, 8GB 기기 = 4B 강등.
    /// 4B 선정 근거는 남은작업.md 22차 — 8GB 티어 후보 비교 조사
    /// 8GB 기기는 사진 판독 VLM과 수학 추론 7B를 순차 실행한다.
    /// 갈림 기준은 칩이 아니라 RAM 트림: 프로 11 4세대(M2)도 128~512GB 는 8GB.
    struct ModelSpec: Sendable {
        let file: String
        let url: URL
        let sizeLabel: String
        let shortName: String
        /// 비전 프로젝터 — 사진 질문(mtmd)용. 본체 다음에 이어서 받는다.
        let mmprojFile: String
        /// 텍스트 전용 모델은 nil이다. 빈 파일명과 무관한 저장소 URL을 함께 두면
        /// 호출부 하나가 게이트를 빠뜨렸을 때 HTML을 GGUF로 받을 수 있다.
        let mmprojURL: URL?
    }

    nonisolated static let spec9B = ModelSpec(
        file: "Qwen3.5-9B-Q4_K_M.gguf",
        // 파일명은 그대로여도 원격 main의 가중치가 교체될 수 있으므로 최초 업로드
        // revision과 공개 SHA-256을 LocalAIModelPack에서 함께 고정한다.
        url: URL(string: "https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/99a1b21/Qwen3.5-9B-Q4_K_M.gguf")!,
        sizeLabel: "5.7GB", shortName: "Qwen3.5-9B",
        mmprojFile: "mmproj-9B-F16.gguf",
        mmprojURL: URL(string: "https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/f0a5ec3/mmproj-F16.gguf")!)
    #if DEBUG
    /// 과거 8GB 비교 실험용 4B. 제품 자동 선택·다운로드에는 쓰지 않으며 원격 파일도
    /// mutable main revision이라 Release 바이너리에 URL 자체를 싣지 않는다.
    nonisolated static let spec4B = ModelSpec(
        file: "Qwen3.5-4B-Q4_K_M.gguf",
        url: URL(string: "https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/resolve/main/Qwen3.5-4B-Q4_K_M.gguf")!,
        sizeLabel: "3.4GB", shortName: "Qwen3.5-4B",
        mmprojFile: "mmproj-4B-F16.gguf",
        mmprojURL: URL(string: "https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/resolve/main/mmproj-F16.gguf")!)
    #endif

    /// 8GB 기기용 9B — unsloth 동적 3비트(UD-IQ3_XXS, 4.0GB).
    /// 같은 크기의 표준 Q3 보다 품질이 낫고, 4B Q4(2.7GB)보다 무겁지만 체급이 위다.
    /// 앱 메모리 한도에 아슬아슬하게 걸치므로 **사용자가 직접 켜는 실험 옵션**이다.
    /// 실측 조정(7/29): IQ3_XXS(3.74GiB)+프로젝터 조합은 8GB 기기에서 로드 중
    /// jetsam 에 죽었다. 실제로 도는 4B(2.55GiB)에 최대한 붙인 2비트판으로 낮춘다.
    nonisolated static let spec9BLite = ModelSpec(
        file: "Qwen3.5-9B-UD-IQ2_XXS.gguf",
        url: URL(string: "https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/f584643/Qwen3.5-9B-UD-IQ2_XXS.gguf")!,
        sizeLabel: "3.2GB", shortName: "Qwen3.5-9B (경량)",
        mmprojFile: "mmproj-9B-F16.gguf",
        mmprojURL: URL(string: "https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/f0a5ec3/mmproj-F16.gguf")!)

    /// 8GB 기기의 opt-in 9B **텍스트 추론** 사양. 875MB 비전 프로젝터를
    /// 전혀 열지 않고, 사진 판독 3B VLM이 내려간 뒤 이 모델만 순차 로드한다.
    /// iPad14,3 실측: 6.0초 로드, 68.9초 추론, 최대 상주 3.57GB, 한국어 JSON 통과.
    nonisolated static let spec9BLiteText = ModelSpec(
        file: "Qwen3.5-9B-UD-IQ3_XXS.gguf",
        url: URL(string: "https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/f584643/Qwen3.5-9B-UD-IQ3_XXS.gguf")!,
        sizeLabel: "4.0GB", shortName: "Qwen3.5-9B 3비트 텍스트",
        mmprojFile: "",
        mmprojURL: nil)

    /// 8GB 실기에서 이미 사이드로드된 3비트 9B 본체의 텍스트 전용 진단 사양.
    /// 제품 다운로드/자동 선택에는 연결하지 않는다. 과거 크래시는 3비트 본체에
    /// 비전 프로젝터까지 동시에 올린 조합이었으므로, 프로젝터 0MB 조건에서
    /// 메모리 안정성과 수학 추론 품질을 별도로 측정하기 위한 DEBUG 후보이다.
    nonisolated static let spec9BIQ3Text = spec9BLiteText

    /// 8GB 기기의 수학 추론 전용 모델. 사진 인코더를 함께 올리지 않아야
    /// Q3 체급을 안정적으로 유지할 수 있다. 사진 판독은 아래 전용 VLM이 맡고,
    /// 두 모델은 절대 동시에 메모리에 올라가지 않는다.
    nonisolated static let specDeepSeek7B = ModelSpec(
        file: "DeepSeek-R1-Distill-Qwen-7B-Q3_K_M.gguf",
        // 가중치 파일이 나중에 같은 이름으로 바뀌지 않도록 최초 업로드 revision에 고정한다.
        // 공식 파일 포인터의 SHA-256도 LocalAIModelPack에서 함께 검증한다.
        url: URL(string: "https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-7B-GGUF/resolve/a5f384a/DeepSeek-R1-Distill-Qwen-7B-Q3_K_M.gguf")!,
        sizeLabel: "3.8GB", shortName: "DeepSeek-R1 7B",
        mmprojFile: "",
        mmprojURL: nil)

    #if DEBUG
    /// llama.cpp PR #26608 bailingmoe3 런타임에서만 열리는 Ling 3.0 Q3.
    /// 사진 판독은 아래 Qwen VL 3B가 계속 담당하고, Ling은 텍스트 추론만 한다.
    nonisolated static let specLing3Q3 = ModelSpec(
        file: "Ling-3.0-tiny-Q3_K_M.gguf",
        url: URL(string: "https://huggingface.co/bloomer010/Ling-3.0-tiny-GGUF/resolve/f2948e0af86d3f2c52a549dadd327b838a909482/Ling-3.0-tiny-Q3_K_M.gguf")!,
        sizeLabel: "3.8GB", shortName: "Ling 3.0 tiny Q3 · DEBUG",
        mmprojFile: "",
        mmprojURL: nil)
    #endif

    /// 8GB 기기 사진 판독 전용. 이 모델은 정답 추론·채점 판정을 하지 않고
    /// 인쇄문과 손글씨를 원문 그대로 전사하는 역할만 맡는다. 전사가 끝나면 즉시
    /// 내려가고 DeepSeek 7B가 텍스트만 받아 추론한다.
    nonisolated static let specVision3B = ModelSpec(
        file: "Qwen2.5-VL-3B-Instruct-Q4_K_M.gguf",
        url: URL(string: "https://huggingface.co/ggml-org/Qwen2.5-VL-3B-Instruct-GGUF/resolve/5037fcf/Qwen2.5-VL-3B-Instruct-Q4_K_M.gguf")!,
        sizeLabel: "2.8GB", shortName: "Qwen2.5-VL 3B 판독기",
        mmprojFile: "mmproj-Qwen2.5-VL-3B-Instruct-Q8_0.gguf",
        mmprojURL: URL(string: "https://huggingface.co/ggml-org/Qwen2.5-VL-3B-Instruct-GGUF/resolve/5037fcf/mmproj-Qwen2.5-VL-3B-Instruct-Q8_0.gguf")!)

    /// 저사양 기기에서 9B 를 무리해서 쓰겠다는 사용자 선택 (프로필 설정)
    nonisolated static var force9BOnSmallDevice: Bool {
        get { UserDefaults.standard.bool(forKey: "matths.force9B") }
        set { UserDefaults.standard.set(newValue, forKey: "matths.force9B") }
    }

    // MARK: 무리한 로드 감시 (jetsam 은 프로세스를 즉사시켜 catch 할 수 없다)
    //
    // 9B 로드 직전에 표식을 남기고, 성공하면 지운다. 다음 실행에서 표식이 남아
    // 있으면 = 지난번 로드 도중 죽었다는 뜻 → 자동으로 4B 로 되돌린다.
    // 안 그러면 켤 때마다 죽는 무한 크래시 루프에 갇힌다.

    nonisolated static var loadCrashed: Bool {
        UserDefaults.standard.bool(forKey: "matths.modelLoadInFlight")
    }
    nonisolated static func markLoadStart() {
        UserDefaults.standard.set(true, forKey: "matths.modelLoadInFlight")
    }
    nonisolated static func markLoadDone() {
        UserDefaults.standard.set(false, forKey: "matths.modelLoadInFlight")
    }
    // MARK: 비전 크래시 래치
    //
    // mtmd_init_from_file 은 실패할 때 nil 을 주지 않고 ggml_abort 로 **프로세스를
    // 죽인다**. Swift 로는 잡을 수 없다. 그래서 "시도했다" 를 디스크에 먼저 적고,
    // 살아 돌아오면 지운다. 다음 실행에서 표식이 남아 있으면 = 지난번에 죽었다는
    // 뜻이므로 그 모델의 비전을 영구히 끈다. 부팅 루프 없이 한 번만 아프고 끝난다.
    // nonisolated — 이 두 개는 그냥 문자열 상수인데 타입이 @MainActor 라
    // 배경 스레드(모델 로드)에서 읽으면 Swift 6 에서 **에러**가 된다.
    private nonisolated static let visionTryKey = "matths.visionAttempt"
    private nonisolated static let visionOffKey = "matths.visionDisabled"

    /// **이 모델 파일에 짝이 맞는** 프로젝터 이름.
    ///
    /// 예전엔 `recommended.mmprojFile` 을 썼는데, 그건 "이 기기에 권장되는 티어"의
    /// 프로젝터라 **지금 여는 모델과 다를 수 있다.** 실제로 권장이 4B 인데 엔진이
    /// 9B 를 쥐고 있으면 9B 본체에 4B 프로젝터를 물리게 된다 — mtmd 초기화가
    /// 실패하거나(운이 좋으면) 엉뚱한 임베딩이 나온다. 파일명에서 체급을 읽어 짝을 맞춘다.
    nonisolated static func mmprojFile(for modelFile: String) -> String {
        #if DEBUG
        // 같은 9B 본체로 텍스트-only 메모리/추론을 재는 명시적 진단 티어.
        // 파일명 자동 추론보다 사용자가 고른 역할을 우선하지 않으면 592MB
        // 프로젝터가 다시 붙어 텍스트 후보 검증 자체가 거짓이 된다.
        if debugForcedTier == "9B-lite-text" || debugForcedTier == "9B-iq3-text" { return "" }
        #endif
        let base: String
        if modelFile == specVision3B.file { base = specVision3B.mmprojFile }
        else if modelFile.contains("9B") { base = spec9B.mmprojFile }   // 9B·9B-lite 공용
        // Release에서도 사용자가 이미 사이드로드한 4B 본체와 로컬 프로젝터의 짝은
        // 찾되, DEBUG 다운로드 사양의 mutable 원격 URL까지 링크하지 않는다.
        else if modelFile.contains("4B") { base = "mmproj-4B-F16.gguf" }
        else { base = "" } // 텍스트 전용·알 수 없는 본체에 프로젝터를 잘못 연결하지 않는다.

        // **경량 프로젝터가 있으면 그것을 먼저 쓴다.**
        //
        // 9B 프로젝터(F16)는 875.61 MB 를 **통짜 malloc** 으로 요구한다. 본체는 mmap
        // 이라 괜찮은데 이건 아니라서, 8GB 기기에서 그 연속 블록을 못 얻고 죽었다:
        //   ggml_aligned_malloc: insufficient memory (attempted to allocate 875.61 MB)
        // HuggingFace 에 9B 용 양자화 프로젝터가 없어(bf16/f16/f32 뿐) 직접 만들었다
        // (도구: /private/tmp/matths-models/quantize_mmproj.py — 블록 선형 가중치만 Q8_0,
        //  패치/위치 임베딩은 F32 를 요구하는 연산에 들어가므로 그대로 둔다).
        // 876MB → 592MB. 맥에서 같은 사진 판독까지 확인했다.
        // **9B 에만 적용한다.** 4B 는 F16 프로젝터(641MB)로 기기에서 실증된 경로다
        // (인수인계 H). 내가 만든 Q8_0 은 맥에서만 확인했지 기기에서 검증한 적이 없다 —
        // 검증 안 된 파일로 되던 것을 갈아치우면 안 된다. 7/29 에 그렇게 해서
        // 4B 까지 같이 터뜨렸다.
        guard !base.isEmpty, modelFile.contains("9B") else { return base }
        let light = base.replacingOccurrences(of: "-F16.gguf", with: "-Q8_0.gguf")
        if light != base, LocalAIModelPack.fileReady(light) {
            return light
        }
        return base
    }

    /// 이 기기·체급에서 시험지 사진을 몇 화소까지 넣을 것인가.
    ///
    /// 이미지 토큰 수는 화소에 비례하고, 그 토큰이 전부 KV 를 차지한다.
    /// 9B + 8GB 조합은 본체(2.97GB)+프로젝터(0.88GB)만으로 이미 빠듯해서
    /// 화소까지 크면 컨텍스트와 계산 버퍼가 자리를 못 잡는다 — 그대로 죽는다.
    /// 판독은 조금 나빠지지만, **죽는 것보다 낫다.**
    nonisolated static var photoPixelBudget: Int { 860_000 }

    /// **이 모델을 지금 열면 비전이 실제로 켜지는가.**
    /// 파일 존재만 보던 라벨이 "· 비전" 이라 적어 놓고 정작 로드는
    /// `mmproj 없음` 으로 실패했다 — 화면이 거짓말을 하면 디버깅이 불가능하다.
    nonisolated static func visionWillLoad(file: String) -> Bool {
        let path = AITutor.modelsDir.appendingPathComponent(file).path
        guard visionFileReady(near: path), !visionDisabled(for: file) else { return false }
        let tight = !hasLargeMemory && file.contains("9B")
        #if DEBUG
        if debugForcedTier != nil { return true }
        #endif
        return !tight
    }

    /// 이 모델 옆에 짝이 맞는 프로젝터 파일이 있는가 (오프로드 결정에 미리 필요)
    nonisolated static func visionFileReady(near modelPath: String) -> Bool {
        let dir = (modelPath as NSString).deletingLastPathComponent
        let want = mmprojFile(for: (modelPath as NSString).lastPathComponent)
        guard !want.isEmpty else { return false }
        let expected = URL(fileURLWithPath: dir).appendingPathComponent(want)
        if expected.deletingLastPathComponent().path == AITutor.modelsDir.path {
            return LocalAIModelPack.fileReady(want)
        }
        return LocalAIModelPack.hasGGUFHeader(at: expected)
    }

    nonisolated static func markVisionAttempt(_ file: String) {
        UserDefaults.standard.set(file, forKey: visionTryKey)
        // 즉시 디스크로 — 다음 줄에서 죽어도 표식이 남아야 한다
        UserDefaults.standard.synchronize()
    }
    nonisolated static func markVisionOK() {
        UserDefaults.standard.removeObject(forKey: visionTryKey)
    }
    /// 앱 빌드 식별자 — 래치를 이 빌드에 묶는다
    private nonisolated static var buildTag: String {
        let d = Bundle.main.infoDictionary
        return "\((d?["CFBundleShortVersionString"] as? String) ?? "?")"
            + "-\((d?["CFBundleVersion"] as? String) ?? "?")"
            + "-\(__DATE__TAG)"
    }
    /// 컴파일 시각을 섞어 **빌드가 바뀌면 래치가 자동으로 풀리게** 한다.
    /// 이유: 래치는 "이 코드로는 죽는다" 는 사실을 적어 둔 것이다. 코드를 고쳐
    /// 새로 설치했는데도 옛 래치가 남아 비전이 영영 꺼져 있으면, 고친 사람도
    /// 사용자도 그걸 모른다 — 실제로 Metal 크래시를 고친 뒤 그 일이 났다.
    private nonisolated static let __DATE__TAG = "\(#file.hashValue &+ 20260729)"

    /// 이 모델의 비전이 **이 빌드에서** 프로세스를 죽였는가.
    /// 다른 빌드에서 죽은 기록은 무시한다(그 사이 고쳤을 수 있다).
    nonisolated static func visionDisabled(for file: String) -> Bool {
        let list = UserDefaults.standard.array(forKey: visionOffKey) as? [String] ?? []
        return list.contains("\(buildTag)|\(file)")
    }

    /// 사용자가 직접 다시 시도하게 하는 통로 (프로필 설정)
    nonisolated static func clearVisionDisabled() {
        UserDefaults.standard.removeObject(forKey: visionOffKey)
        UserDefaults.standard.removeObject(forKey: visionTryKey)
    }
    /// 이 기기에 지금 티어의 프로젝터 파일이 실제로 있는가 (화면 안내용)
    nonisolated static var mmprojFilePresent: Bool {
        let file = analysisVisionSpec.mmprojFile
        guard !file.isEmpty else { return false }
        return LocalAIModelPack.fileReady(file)
    }

    /// 지금 티어의 비전이 꺼져 있는가 (화면 안내용)
    nonisolated static var visionOffForCurrentModel: Bool {
        visionDisabled(for: analysisVisionSpec.file)
    }

    /// 지금 티어가 프로젝터를 **열 수 있는가** — LlamaEngine.load 의 개방 조건과
    /// 같아야 한다. 8GB + 9B(경량)는 tightMemory 라 프로젝터를 아예 건너뛰는데,
    /// 다운로더에는 그 게이트가 없어 영영 쓰지 않을 0.9GB 를 받고 그 완료를
    /// 기다리고 있었다. 열지 않을 파일은 받지도 않는다.
    nonisolated static var mmprojUsable: Bool {
        mmprojUsable(for: recommended)
    }

    /// 다운로드를 시작한 뒤 사용자 티어가 바뀌어도, 시작 당시 모델 기준으로
    /// 프로젝터 필요 여부를 유지한다.
    nonisolated static func mmprojUsable(for spec: ModelSpec) -> Bool {
        guard !spec.mmprojFile.isEmpty, spec.mmprojURL != nil else { return false }
        if !hasLargeMemory && spec.file.contains("9B") { return false }
        return !visionDisabled(for: spec.file)
    }
    /// 앱 시작 시 1회 — 지난 실행이 비전 로드 중 죽었으면 그 모델의 비전을 끈다.
    /// 돌려주는 값은 "이번에 껐다"(사용자에게 안내할 거리)
    nonisolated static func recoverFromVisionCrashIfNeeded() -> String? {
        guard let file = UserDefaults.standard.string(forKey: visionTryKey) else { return nil }
        UserDefaults.standard.removeObject(forKey: visionTryKey)
        var off = UserDefaults.standard.array(forKey: visionOffKey) as? [String] ?? []
        let stamped = "\(buildTag)|\(file)"
        guard !off.contains(stamped) else { return nil }
        off.append(stamped)
        UserDefaults.standard.set(off, forKey: visionOffKey)
        return file
    }

    /// 지난 실행이 로드 중 죽었으면 강제 9B를 끄고 true 를 돌려준다 (앱 시작 시 1회)
    @discardableResult
    nonisolated static func recoverFromLoadCrashIfNeeded() -> Bool {
        guard loadCrashed else { return false }
        markLoadDone()
        guard force9BOnSmallDevice else { return false }
        force9BOnSmallDevice = false
        return true
    }

    nonisolated static var hasLargeMemory: Bool {
        ProcessInfo.processInfo.physicalMemory >= 10 * 1024 * 1024 * 1024
    }

    #if DEBUG
    /// 디버그 전용 모델 강제 — 채점 Pro 화면에서 고른다.
    ///
    /// 왜 필요한가: 같은 사진을 4B 로도 9B 로도 돌려 보고 결과를 비교해야
    /// "이 오답이 모델 체급 탓인지, 프롬프트 탓인지" 를 가릴 수 있다.
    /// 프로필의 `force9B` 토글은 "이 기기에서 9B 를 무리해서 쓸까" 라는
    /// **사용자 설정**이라 의미가 다르다 — 그걸 실험용으로 켰다 껐다 하면
    /// 사용자 설정이 오염된다. 그래서 별도 키를 쓴다.
    /// 값: nil(자동) | "ling3-q3" | "4B" | "9B-lite" | "9B-lite-text" | "9B-iq3-text" | "9B"
    nonisolated static var debugForcedTier: String? {
        get { UserDefaults.standard.string(forKey: "matths.debugTier") }
        set {
            if let newValue { UserDefaults.standard.set(newValue, forKey: "matths.debugTier") }
            else { UserDefaults.standard.removeObject(forKey: "matths.debugTier") }
        }
    }
    nonisolated static func spec(forTier tier: String) -> ModelSpec {
        switch tier {
        case "4B":      return spec4B
        case "vision3B": return specVision3B
        case "deepseek7B": return specDeepSeek7B
        case "ling3-q3": return specLing3Q3
        case "9B-lite": return spec9BLite
        case "9B-lite-text": return spec9BLiteText
        case "9B-iq3-text": return spec9BIQ3Text
        case "9B":      return spec9B
        default:        return specDeepSeek7B
        }
    }
    #endif

    nonisolated static var recommended: ModelSpec {
        #if DEBUG
        // 강제 선택이 있으면 그것이 먼저다. 기기 메모리 판정도 건너뛴다 —
        // "8GB 에서 9B 풀사이즈가 정말 죽나" 를 확인하려면 막지 말아야 한다.
        if let tier = debugForcedTier { return spec(forTier: tier) }
        #endif
        if hasLargeMemory { return spec9B }
        return force9BOnSmallDevice ? spec9BLiteText : specDeepSeek7B
    }

    /// 시험지 분석은 8GB 기기에서 사진 판독과 수학 추론을 서로 다른 모델로
    /// 순차 실행한다. 12GB 이상은 기존 9B VLM 한 개로 두 역할을 처리한다.
    nonisolated static var analysisVisionSpec: ModelSpec {
        hasLargeMemory ? spec9B : specVision3B
    }

    nonisolated static var analysisReasoningSpec: ModelSpec {
        #if DEBUG
        // 디버그 선택은 사진 판독기가 내려간 뒤 여는 텍스트 추론 모델에도 그대로 반영한다.
        if let tier = debugForcedTier { return spec(forTier: tier) }
        #endif
        if hasLargeMemory { return spec9B }
        // 프로필에서 사용자가 명시적으로 9B 실험 모드를 켠 경우에만,
        // 사진 판독 3B를 완전히 내린 뒤 프로젝터 없는 2비트 9B를 올린다.
        // iPad14,3 실측: load 5.0s, reasoning 82.2s, peak resident 3.29GB.
        return force9BOnSmallDevice ? spec9BLiteText : specDeepSeek7B
    }

    /// 이 기기가 온디바이스 AI 를 감당하는가.
    /// 전용 VLM 또는 7B Q3 + KV + 앱 풋프린트가 들어가야 하므로 6GB 미만은 거른다.
    /// (한때 `true` 상수라 미지원 안내가 영영 안 뜨던 자리 — 2티어 정책과도 모순이었다)
    nonisolated static var deviceSupported: Bool {
        ProcessInfo.processInfo.physicalMemory >= 6 * 1024 * 1024 * 1024
    }

    private var preparationTask: Task<Void, Never>?

    /// Foundation의 다운로드 오류에는 호스트명·임시 파일 경로·내부 도메인이 섞일 수
    /// 있다. 학생 화면에는 원문을 내보내지 않고, 실제로 취할 수 있는 복구 행동만
    /// 구분해 보여 준다. 원문은 DEBUG 로그에만 남긴다.
    nonisolated static func userFacingDownloadFailure(_ error: Error) -> String {
        if let packError = error as? LocalAIModelPack.PackError {
            switch packError {
            case .insufficientStorage(let requiredGB):
                return "AI 모델을 받으려면 약 \(requiredGB)GB의 여유 공간이 필요합니다."
            case .badResponse:
                return "AI 모델 다운로드 서버가 응답하지 않았습니다. 잠시 후 다시 시도해 주세요."
            case .invalidFile:
                return "받은 AI 모델 파일을 확인하지 못했습니다. 다시 시도해 주세요."
            }
        }
        if error is ResumableModelDownload.DownloadError {
            return "중단된 AI 모델 다운로드를 복구하지 못했습니다. 다시 시도해 주세요."
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
                 .internationalRoamingOff:
                return "인터넷 연결을 확인한 뒤 AI 모델을 다시 받아 주세요."
            case .timedOut:
                return "AI 모델 다운로드 시간이 초과됐습니다. 연결 상태를 확인하고 다시 시도해 주세요."
            default:
                break
            }
        }
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileWriteOutOfSpaceError {
            return "저장 공간이 부족해 AI 모델을 받지 못했습니다. 공간을 확보한 뒤 다시 시도해 주세요."
        }
        return "AI 모델을 받지 못했습니다. 인터넷 연결과 저장 공간을 확인한 뒤 다시 시도해 주세요."
    }

    func start() {
        guard state == .idle || {
            if case .failed = state { return true } else { return false }
        }() else { return }
        state = .downloading(0)
        let spec = Self.recommended
        let wantsProjector = Self.mmprojUsable(for: spec)
        preparationTask?.cancel()
        preparationTask = Task { [weak self] in
            guard let self else { return }
            do {
                if !(await LocalAIModelPack.verifyExistingArtifact(spec.file)) {
                    try await self.downloadAndInstall(
                        url: spec.url,
                        file: spec.file,
                        progressBase: 0,
                        progressWeight: wantsProjector ? 0.8 : 1)
                }
                guard !Task.isCancelled else { return }
                // 본체가 먼저 준비되면 사진 모듈을 기다리는 동안에도 텍스트 튜터를 연다.
                AITutor.shared.loadRecommended()
                if wantsProjector,
                   !(await LocalAIModelPack.verifyExistingArtifact(spec.mmprojFile)) {
                    guard let mmprojURL = spec.mmprojURL else {
                        throw LocalAIModelPack.PackError.invalidFile(
                            "\(spec.shortName) 사진 모듈 주소")
                    }
                    try await self.downloadAndInstall(
                        url: mmprojURL,
                        file: spec.mmprojFile,
                        progressBase: 0.8,
                        progressWeight: 0.2)
                }
                guard !Task.isCancelled else { return }
                if Self.recommended.file != spec.file {
                    self.state = .idle
                    self.start()
                    return
                }
                self.state = .done
                AITutor.shared.discoverAndLoad()
            } catch {
                guard !Task.isCancelled else { return }
                #if DEBUG
                print("AI 모델 다운로드 실패:", error)
                #endif
                self.state = .failed(Self.userFacingDownloadFailure(error))
            }
        }
    }

    /// 티어를 바꾼 직후(프로필 9B 토글) — 새 티어의 본체가 없으면 받기 시작한다.
    /// 돌려주는 값은 "다운로드를 시작했다".
    ///
    /// 왜 따로 필요한가: start() 는 .done/.downloading 에서 즉시 반환하므로,
    /// 4B 를 이미 받아 둔 기기에서 티어만 바꾸면 아무 일도 일어나지 않는다.
    /// 그 사이 discoverAndLoad 는 옆에 있는 옛 gguf 를 열어 .ready 로 만들어
    /// 다운로드 카드(.missing 에서만 보임)마저 영영 뜨지 않았다 — 토글이 무의미했다.
    @discardableResult
    func startForTierSwitch() -> Bool {
        guard !LocalAIModelPack.fileReady(Self.recommended.file) else { return false }
        if case .downloading = state { return true }   // 이미 받는 중이면 건드리지 않는다
        state = .idle                                   // 지난 티어의 .done 을 풀어 준다
        start()
        return true
    }

    private func downloadAndInstall(
        url: URL,
        file: String,
        progressBase: Double,
        progressWeight: Double
    ) async throws {
        let expectedBytes = LocalAIModelPack.expectedBytes(for: file)
        try LocalAIModelPack.requireStorage(for: expectedBytes)
        let key = "\(url.absoluteString)|\(file)|\(expectedBytes)"
        let temporary = try await ResumableModelDownload.shared.download(
            from: url,
            key: key) { [weak self] fraction in
                Task { @MainActor in
                    self?.state = .downloading(progressBase + fraction * progressWeight)
                }
            }
        defer { ResumableModelDownload.shared.discardArtifact(for: key) }
        let directory = AITutor.modelsDir
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let staged = directory.appendingPathComponent("staged-\(UUID().uuidString).part")
        try FileManager.default.moveItem(at: temporary, to: staged)
        try await Task.detached(priority: .utility) {
            try LocalAIModelPack.installValidatedGGUF(
                staged: staged,
                destination: directory.appendingPathComponent(file),
                minimumBytes: Int64(Double(expectedBytes) * 0.97),
                expectedSHA256: LocalAIModelPack.expectedSHA256(for: file))
        }.value
    }
}
