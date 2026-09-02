//  PhotoIntake.swift
//  Matths
//
//  사진 한 장을 "무슨 일이 있어도" 읽어 오는 경로.
//
//  왜 새로 짰나 — SwiftUI `PhotosPicker` + `loadTransferable` 은 실기기에서
//  `CoreTransferable.TransferableSupportError` 로 실패했다. CoreTransferable 은
//  항목이 요청한 타입의 표현을 못 주면 그냥 던지는데, iCloud 원본 HEIC·편집본·
//  스크린샷 등에서 이게 흔하다. 그래서 한 겹 아래인 PHPicker + NSItemProvider 로
//  내려가고, 표현을 **차례로 네 가지** 시도한다. 하나라도 되면 성공이다.
//
//    1) 파일 표현 (loadFileRepresentation)     — HEIC·RAW·편집본 대응, 디스크 스트리밍
//    2) 데이터 표현 (loadDataRepresentation)   — 파일 표현이 없는 항목
//    3) 객체 표현 (loadObject: UIImage)        — 위 둘이 없는 특수 항목
//    4) PHImageManager (에셋 직접 요청)        — iCloud 원본 미다운로드 케이스.
//       isNetworkAccessAllowed=true 라 필요하면 받아온다. 사진 접근 권한이 필요해
//       이 단계에서만 권한을 묻는다(앞 세 단계는 권한 없이 동작).
//
//  디코드는 전부 ImageIO 축소 디코드다. 원본이 몇 화소든 목표 크기로 **직접**
//  디코드하므로 1200만 화소 비트맵이 메모리에 펼쳐지는 일이 없다 —
//  모델이 3.5GB 를 쥔 상태에서 그 스파이크는 곧 앱 종료다.
//
//  실패하면 사용자에게 문구를 띄우는 동시에 진단을 파일로 남긴다
//  (Documents/photo-intake.log). 다음에 또 막히면 이 파일만 뽑으면 원인이 나온다 —
//  사용자에게 "무슨 오류 떴어요?" 를 다시 묻지 않기 위한 장치다.

import SwiftUI
import UIKit
import ImageIO
import PhotosUI
import UniformTypeIdentifiers

// MARK: - 진단 로그

enum PhotoIntakeLog {
    private static var url: URL { DataScope.url("photo-intake.log") }

    static func write(_ line: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        let text = "[\(stamp)] \(line)\n"
        if let h = try? FileHandle(forWritingTo: url) {
            defer { try? h.close() }
            _ = try? h.seekToEnd()
            try? h.write(contentsOf: Data(text.utf8))
        } else {
            try? Data(text.utf8).write(to: url)
        }
    }
}

// MARK: - 읽기

enum PhotoIntake {
    /// 스킬 0절 면적 예산(총 화소 ≤ 0.86MP)에 맞춘 긴 변 상한
    static let maxPixel = 1100

    struct Failure: Error { let message: String }

    /// 네 경로를 차례로 시도한다. 각 단계의 성패를 로그에 남긴다.
    static func load(provider: NSItemProvider, assetID: String?) async -> Result<UIImage, Failure> {
        let types = provider.registeredTypeIdentifiers.joined(separator: ",")
        PhotoIntakeLog.write("시작 · 표현=[\(types)] · asset=\(assetID ?? "없음")")
        // 왜 실패하는지 다음에 바로 알 수 있게 에셋 상태를 같이 남긴다
        if let id = assetID,
           let a = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject {
            // ⚠️ `locallyAvailable` 같은 비공개 KVC 키는 쓰지 않는다 —
            //    키가 없으면 NSUnknownKeyException 으로 앱이 그 자리에서 죽는다.
            //    공개 API 로 알 수 있는 것만 남긴다.
            let res = PHAssetResource.assetResources(for: a)
            let kinds = res.map { "\($0.type.rawValue)" }.joined(separator: "/")
            PhotoIntakeLog.write("  에셋: \(a.pixelWidth)x\(a.pixelHeight)"
                + " · 리소스 \(res.count)개[\(kinds)]"
                + " · 소스 \(a.sourceType.rawValue)")
        }

        // 1) 파일 표현
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            if let img = await fileRepresentation(provider) {
                PhotoIntakeLog.write("성공 · 1)파일표현 \(Int(img.size.width))x\(Int(img.size.height))")
                return .success(img)
            }
        }
        // 2) 데이터 표현
        if let img = await dataRepresentation(provider) {
            PhotoIntakeLog.write("성공 · 2)데이터표현 \(Int(img.size.width))x\(Int(img.size.height))")
            return .success(img)
        }
        // 3) 객체 표현
        if let img = await objectRepresentation(provider) {
            PhotoIntakeLog.write("성공 · 3)객체표현 \(Int(img.size.width))x\(Int(img.size.height))")
            return .success(img)
        }
        // 4) 에셋의 **원본 데이터** 요청 (iCloud 다운로드 포함)
        if let id = assetID, let img = await photoLibraryAsset(id) {
            PhotoIntakeLog.write("성공 · 4)PHImageManager \(Int(img.size.width))x\(Int(img.size.height))")
            return .success(img)
        }
        // 5) 렌디션 요청 — 원본이 없어도 된다.
        //    4)requestImageDataAndOrientation 은 **원본 파일**을 요구해서, 원본이
        //    기기에 없고 썸네일만 남은 사진(로그의 private.photos.thumbnail.* 표현)에서는
        //    CloudPhotoLibraryError 1005 로 실패한다. requestImage 는 목표 크기의
        //    렌디션을 달라는 것이라 로컬 캐시로도 응답이 온다 — 우리는 1100px 이면 충분하다.
        if let id = assetID, let img = await photoLibraryRendition(id) {
            let long = max(img.size.width, img.size.height)
            // 시스템이 저화질 썸네일만 주는 경우가 있다(실측 90x120). 그걸로 분석을
            // 돌리면 모델이 활자를 못 읽고 **지어낸다** — 안 하느니만 못하다.
            // 인쇄 활자를 읽을 최소선을 넘을 때만 성공으로 친다.
            if long >= 600 {
                PhotoIntakeLog.write("성공 · 5)렌디션 \(Int(img.size.width))x\(Int(img.size.height))")
                return .success(img)
            }
            PhotoIntakeLog.write("5)렌디션이 썸네일뿐(\(Int(img.size.width))x\(Int(img.size.height))) — 판독 불가라 버린다")
        }

        PhotoIntakeLog.write("실패 · 다섯 경로 모두 불가 · 표현=[\(types)]")
        // 여기까지 왔다면 시스템이 이 사진의 화소를 **어떤 방법으로도** 못 준다.
        // 대개 iCloud 최적화로 원본이 기기에서 비워졌는데 다시 못 받아오는 상태다
        // (CloudPhotoLibraryError). 앱이 뚫을 수 있는 문제가 아니므로,
        // 반드시 되는 길을 알려 주는 것이 맞다.
        return .failure(Failure(message:
            "이 사진은 원본이 기기에 없어 읽을 수 없습니다 (iCloud에서 받아오지 못했습니다).\n"
            + "· 방금 찍은 사진이나 스크린샷으로 해 보세요 — 그건 항상 기기에 있습니다.\n"
            + "· 또는 아래 \"촬영하기\"·\"파일에서 고르기\"를 쓰시면 됩니다."))
    }

    // MARK: 개별 경로

    private static func fileRepresentation(_ p: NSItemProvider) async -> UIImage? {
        await withCheckedContinuation { cont in
            // 콜백이 두 번 오거나 아예 안 오는 사고를 막는다 (continuation 은 1회만)
            let once = OnceBox(cont)
            p.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, err in
                if let err { PhotoIntakeLog.write("1)파일표현 실패: \(err.localizedDescription)") }
                guard let url else { once.resume(nil); return }
                // 콜백이 끝나면 시스템이 이 파일을 지운다 — 그 안에서 디코드까지 끝낸다
                once.resume(downsample(fileURL: url))
            }
        }
    }

    private static func dataRepresentation(_ p: NSItemProvider) async -> UIImage? {
        let type = p.registeredTypeIdentifiers.first(where: {
            UTType($0)?.conforms(to: .image) == true
        }) ?? UTType.image.identifier
        return await withCheckedContinuation { cont in
            let once = OnceBox(cont)
            p.loadDataRepresentation(forTypeIdentifier: type) { data, err in
                if let err { PhotoIntakeLog.write("2)데이터표현 실패: \(err.localizedDescription)") }
                guard let data else { once.resume(nil); return }
                once.resume(downsample(data: data))
            }
        }
    }

    private static func objectRepresentation(_ p: NSItemProvider) async -> UIImage? {
        guard p.canLoadObject(ofClass: UIImage.self) else { return nil }
        return await withCheckedContinuation { cont in
            let once = OnceBox(cont)
            p.loadObject(ofClass: UIImage.self) { obj, err in
                if let err { PhotoIntakeLog.write("3)객체표현 실패: \(err.localizedDescription)") }
                guard let img = obj as? UIImage else { once.resume(nil); return }
                // 이미 메모리에 펼쳐진 상태라 여기서라도 줄여서 넘긴다
                once.resume(img.normalizedUp().resizedToPixelBudget(ModelDownloader.photoPixelBudget))
            }
        }
    }

    /// iCloud 원본이 기기에 없을 때의 최후 경로. 여기서만 사진 접근 권한을 묻는다.
    private static func photoLibraryAsset(_ id: String) async -> UIImage? {
        let status = await withCheckedContinuation { (c: CheckedContinuation<PHAuthorizationStatus, Never>) in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { c.resume(returning: $0) }
        }
        guard status == .authorized || status == .limited else {
            PhotoIntakeLog.write("4)PHImageManager 불가: 권한 \(status.rawValue)")
            return nil
        }
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
        else { PhotoIntakeLog.write("4)에셋 조회 실패"); return nil }

        let opts = PHImageRequestOptions()
        opts.isNetworkAccessAllowed = true      // iCloud 에서 내려받아도 좋다
        opts.deliveryMode = .highQualityFormat
        opts.isSynchronous = false
        return await withCheckedContinuation { cont in
            let once = OnceBox(cont)
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: opts) {
                data, _, _, info in
                if let e = info?[PHImageErrorKey] as? NSError {
                    PhotoIntakeLog.write("4)PHImageManager 실패: \(e.localizedDescription)")
                }
                guard let data else { once.resume(nil); return }
                once.resume(downsample(data: data))
            }
        }
    }

    /// 목표 크기 렌디션 — 원본이 없어도 캐시/저해상도로 답이 온다.
    /// opportunistic 은 저화질을 먼저 주고 고화질이 준비되면 한 번 더 부르므로,
    /// **가장 나중에 받은 것**을 쓴다(중간에 끊기면 저화질이라도 건진다).
    private static func photoLibraryRendition(_ id: String) async -> UIImage? {
        let status = await withCheckedContinuation { (c: CheckedContinuation<PHAuthorizationStatus, Never>) in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { c.resume(returning: $0) }
        }
        guard status == .authorized || status == .limited else {
            PhotoIntakeLog.write("5)렌디션 불가: 권한 \(status.rawValue)")
            return nil
        }
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
        else { PhotoIntakeLog.write("5)에셋 조회 실패"); return nil }

        let opts = PHImageRequestOptions()
        opts.isNetworkAccessAllowed = true
        opts.deliveryMode = .opportunistic
        opts.resizeMode = .fast
        opts.isSynchronous = false
        let target = CGSize(width: maxPixel, height: maxPixel)

        // opportunistic 은 저화질 → 고화질 순으로 **두 번** 부를 수 있다. 콜백은 임의
        // 큐에서 오고 타임아웃은 메인에서 도니, 중간 결과는 락으로 감싼 상자에 담는다.
        let box = ImageBox()
        return await withCheckedContinuation { cont in
            let once = OnceBox(cont)
            PHImageManager.default().requestImage(
                for: asset, targetSize: target, contentMode: .aspectFit, options: opts
            ) { image, info in
                if let e = info?[PHImageErrorKey] as? NSError {
                    PhotoIntakeLog.write("5)렌디션 오류: \(e.localizedDescription)")
                }
                if let image { box.set(image) }
                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !degraded { once.resume(box.get()) }   // 고화질이 왔다
            }
            // 고화질이 끝내 안 올 수도 있다 — 4초 뒤에는 손에 있는 것으로 답한다.
            // 저화질이라도 시험지 판독에는 쓸 수 있고, 아무것도 못 주는 것보다 낫다.
            DispatchQueue.global().asyncAfter(deadline: .now() + 4) { once.resume(box.get()) }
        }
    }

    // MARK: 축소 디코드 (ImageIO)

    private static let opts: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,   // EXIF 회전을 화소에 굽는다
        kCGImageSourceShouldCacheImmediately: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixel,
    ]

    static func downsample(fileURL: URL) -> UIImage? {
        guard let src = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
        else { return nil }
        return UIImage(cgImage: cg)
    }

    static func downsample(data: Data) -> UIImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
        else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// continuation 을 정확히 한 번만 재개시키는 상자.
/// NSItemProvider 콜백은 조건에 따라 두 번 불리거나 안 불릴 수 있어서(실제 사고 사례가 많다)
/// 그대로 두면 크래시(두 번) 또는 영구 대기(안 옴)가 된다.
/// 콜백이 여러 번 오는 동안 마지막 이미지를 안전하게 들고 있는 상자
private final class ImageBox: @unchecked Sendable {
    private let lock = NSLock()
    private var image: UIImage?
    func set(_ v: UIImage) { lock.lock(); image = v; lock.unlock() }
    func get() -> UIImage? { lock.lock(); defer { lock.unlock() }; return image }
}

private final class OnceBox: @unchecked Sendable {
    private let lock = NSLock()
    private var cont: CheckedContinuation<UIImage?, Never>?
    init(_ c: CheckedContinuation<UIImage?, Never>) { cont = c }
    func resume(_ v: UIImage?) {
        lock.lock(); let c = cont; cont = nil; lock.unlock()
        c?.resume(returning: v)
    }
}

// MARK: - PHPicker (SwiftUI 래퍼)

/// PHPickerViewController 직결. SwiftUI PhotosPicker 가 씌우는 CoreTransferable
/// 계층을 걷어내고 NSItemProvider 를 직접 받는다 — 실패 지점이 그만큼 줄어든다.
struct SystemPhotoPicker: UIViewControllerRepresentable {
    /// (provider, assetLocalIdentifier) — 취소면 nil
    let onPick: (NSItemProvider?, String?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var cfg = PHPickerConfiguration(photoLibrary: .shared())   // 에셋 id 를 받으려면 필요
        cfg.filter = .images
        cfg.selectionLimit = 1
        // 원본이 HEIC 여도 시스템이 호환 포맷으로 변환해 준다 — 실패 경로를 줄이는 핵심 설정
        cfg.preferredAssetRepresentationMode = .compatible
        let vc = PHPickerViewController(configuration: cfg)
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (NSItemProvider?, String?) -> Void
        init(onPick: @escaping (NSItemProvider?, String?) -> Void) { self.onPick = onPick }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let r = results.first else { onPick(nil, nil); return }
            onPick(r.itemProvider, r.assetIdentifier)
        }
    }
}
