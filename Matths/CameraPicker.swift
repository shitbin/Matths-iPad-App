//  CameraPicker.swift
//  Matths
//
//  시험지 촬영 — UIImagePickerController 카메라 래퍼.
//  (사진 라이브러리 쪽은 SwiftUI PhotosPicker 를 그대로 쓴다)
//
//  Info.plist 에 NSCameraUsageDescription 이 있어야 열린다. 없으면 iOS 가
//  앱을 그 자리에서 죽인다 — isAvailable 로 버튼 자체를 감춘다.

import SwiftUI
import UIKit
import ImageIO
import UniformTypeIdentifiers

struct CameraPicker: UIViewControllerRepresentable {
    /// 취소면 nil
    let onFinish: (UIImage?) -> Void

    static var isAvailable: Bool {
        #if targetEnvironment(simulator)
        return false      // 시뮬레이터엔 카메라가 없다
        #else
        return UIImagePickerController.isSourceTypeAvailable(.camera)
        #endif
    }

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let c = UIImagePickerController()
        c.sourceType = .camera
        c.cameraCaptureMode = .photo
        c.allowsEditing = false
        c.delegate = context.coordinator
        return c
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate,
                             UINavigationControllerDelegate {
        let onFinish: (UIImage?) -> Void
        init(onFinish: @escaping (UIImage?) -> Void) { self.onFinish = onFinish }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info:
                                   [UIImagePickerController.InfoKey: Any]) {
            onFinish(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}

// MARK: - 모델에 보내기 전 정규화

extension UIImage {
    /// EXIF 회전을 화소에 굽는다. 이걸 안 하면 90°·180° 회전 사진이 기하 게이트를
    /// 그대로 통과해 **전 문항 오배정**이 난다 (스킬 0절 입력 게이트).
    func normalizedUp() -> UIImage {
        guard imageOrientation != .up else { return self }
        let f = UIGraphicsImageRendererFormat.default()
        f.scale = 1
        return UIGraphicsImageRenderer(size: size, format: f).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// 면적 예산 리사이즈 — 긴 변 고정이 아니라 **총 화소** 를 맞춘다.
    /// 비전 인코더의 토큰 예산이 면적에 비례하므로, 우리가 줄여 보내야
    /// 어떤 리샘플러가 돌지 우리가 정한다 (스킬 0절 1항).
    func resizedToPixelBudget(_ budget: Int) -> UIImage {
        let w = size.width * scale, h = size.height * scale
        let pixels = w * h
        guard pixels > CGFloat(budget), w > 0, h > 0 else { return self }
        let k = (CGFloat(budget) / pixels).squareRoot()
        let target = CGSize(width: (w * k).rounded(.down), height: (h * k).rounded(.down))
        let f = UIGraphicsImageRendererFormat.default()
        f.scale = 1
        return UIGraphicsImageRenderer(size: target, format: f).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

// MARK: - 큰 사진을 메모리 폭발 없이 줄여 읽기

enum PhotoDownsampler {
    /// ImageIO 로 **디코드 단계에서 바로** 축소한다.
    ///
    /// UIImage(data:) 는 원본 해상도(1200만 화소 = 48MB 비트맵)를 통째로 펼친 뒤
    /// 줄인다. 모델이 3.5GB 를 점유한 기기에서는 그 한 번의 스파이크로 앱이 사라진다.
    /// (사진을 고른 뒤 아무 반응이 없던 원인 — 디코드에서 죽거나 실패했다.)
    /// CGImageSourceCreateThumbnailAtIndex 는 목표 크기로 **직접** 디코드하므로
    /// 원본이 몇 화소든 최대 메모리가 목표 크기로 묶인다. EXIF 회전도 같이 적용된다.
    static func image(from data: Data, maxPixel: Int) -> UIImage? {
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // EXIF 회전 반영
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
        else { return nil }
        return UIImage(cgImage: cg)
    }
}

// MARK: - 앨범 항목을 "파일"로 받아오기

/// PhotosPicker 항목을 **파일 복사**로 받는다.
///
/// `loadTransferable(type: Data.self)` 는 iCloud 원본 HEIC·편집본·RAW 에서
/// `CoreTransferable.TransferableSupportError` 로 실패한다(실기기 확인).
/// 파일 표현(FileRepresentation)은 시스템이 임시 파일로 내려 주므로 그 경로만
/// 복사해 두면 형식과 무관하게 읽을 수 있고, ImageIO 가 **디스크에서 스트리밍**
/// 디코드하므로 원본을 메모리에 통째로 올리지도 않는다.
struct PickedPhotoFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            let ext = received.file.pathExtension.isEmpty ? "img" : received.file.pathExtension
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("picked-\(UUID().uuidString).\(ext)")
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.copyItem(at: received.file, to: dest)
            return Self(url: dest)
        }
    }
}

extension PhotoDownsampler {
    /// 파일 경로에서 바로 축소 디코드 — Data 를 메모리에 올리지 않는다
    static func image(fileURL: URL, maxPixel: Int) -> UIImage? {
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let src = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
        else { return nil }
        return UIImage(cgImage: cg)
    }
}
