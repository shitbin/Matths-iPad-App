import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

@main
enum NativeServiceRecoveryCases {
    static var count = 0
    static func check(_ value: @autoclosure () -> Bool, _ message: String) {
        precondition(value(), message); count += 1
    }
    static func main() throws {
        var draft = NativeServiceDraft(slot: "acct-a", resource: "support", fields: ["subject": "제목", "content": "본문입니다"])
        let first = draft.ticket(for: draft.fields)
        check(!first.isEmpty, "request identity created")
        check(draft.ticket(for: ["content": "본문입니다", "subject": "제목"]) == first, "same canonical payload reuses identity independent of dictionary order")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("native-service-cases-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("draft.json")
        try NativeServiceDraftDisk.save(draft, to: file)
        var restored = try NativeServiceDraftDisk.load(from: file, slot: "acct-a", resource: "support")
        check(restored == draft, "account draft survives actual disk roundtrip")
        check(restored.ticket(for: draft.fields) == first, "response loss and process restart retain request ID")
        check(restored.ticket(for: ["subject": "제목", "content": "내용을 수정했습니다"]) != first, "editing submitted content starts a different logical request")
        for (slot, resource) in [("acct-b", "support"), ("acct-a", "study:123")] {
            do {
                _ = try NativeServiceDraftDisk.load(from: file, slot: slot, resource: resource)
                preconditionFailure("foreign draft accepted")
            } catch { count += 1 }
        }
        var bad = draft
        bad.attachments = ["../progress-v2.json"]
        check(!bad.isValid, "path traversal in attachment manifest rejected")
        let original = try Data(contentsOf: file)
        do { try NativeServiceDraftDisk.save(bad, to: file); preconditionFailure("invalid write accepted") }
        catch { count += 1 }
        let after = try Data(contentsOf: file)
        check(after == original, "failed validation does not overwrite valid draft")
        bad = draft; bad.version = 99
        check(!bad.isValid, "future schema not misread")
        bad = draft; bad.attachments = Array(repeating: "file.jpg", count: 6)
        check(!bad.isValid, "more than five attachments rejected")
        let missing = folder.appendingPathComponent("new.json")
        let newDraft = try NativeServiceDraftDisk.load(from: missing, slot: "acct-b", resource: "community-composer")
        check(newDraft.slot == "acct-b" && newDraft.fields.isEmpty, "new account starts empty without old account content")

        var gate = NativeServiceRequestRevision()
        let requests = (0..<20).map { _ in gate.begin() }
        for old in requests.dropLast().reversed() { check(!gate.accepts(old), "late prior response cannot replace newest search or folder") }
        check(gate.accepts(requests.last!), "latest request is accepted")
        _ = gate.begin()
        check(!gate.accepts(requests.last!), "account reset also invalidates pending response")

        let mib = 1024 * 1024
        for ext in NativeServiceInputPolicy.imageExtensions {
            check(NativeServiceInputPolicy.allowsAttachment(extension: ext, bytes: 10 * mib, totalBytes: 10 * mib), "image exact server limit accepted")
            check(!NativeServiceInputPolicy.allowsAttachment(extension: ext, bytes: 10 * mib + 1, totalBytes: 10 * mib + 1), "image over server limit rejected")
        }
        for ext in NativeServiceInputPolicy.attachmentExtensions.subtracting(NativeServiceInputPolicy.imageExtensions) {
            check(NativeServiceInputPolicy.allowsAttachment(extension: ext, bytes: 25 * mib, totalBytes: 50 * mib), "25MB non-image files match real web limit")
            check(!NativeServiceInputPolicy.allowsAttachment(extension: ext, bytes: 25 * mib + 1, totalBytes: 25 * mib + 1), "oversize document rejected")
        }
        check(!NativeServiceInputPolicy.allowsAttachment(extension: "exe", bytes: 1, totalBytes: 1), "unsupported executable cannot be selected")
        check(!NativeServiceInputPolicy.allowsAttachment(extension: "pdf", bytes: 1, totalBytes: 50 * mib + 1), "50MB aggregate server boundary enforced")
        check(NativeServiceInputPolicy.allowsAttachment(extension: "PDF", bytes: 1, totalBytes: 1), "extension comparison is case-insensitive")
        check(!NativeServiceInputPolicy.allowsAttachment(extension: "pdf", bytes: -1, totalBytes: 1), "negative metadata rejected")
        check(NativeServiceInputPolicy.isCommunityAttachmentPath("/api/v1/community/posts/post-1/attachments/attachment_1", attachmentID: "attachment_1"), "real endpoint accepted")
        for path in ["https://evil.test/attachments/a", "//evil.test/a", "/api/v1/community/posts/p/attachments/a?token=x", "/api/v1/community/posts/../attachments/a", "/api/v1/community/posts/p/attachments/%2e%2e", "/api/v1/community/posts/p/attachments/other", "/api/v1/admin/users/a"] {
            check(!NativeServiceInputPolicy.isCommunityAttachmentPath(path, attachmentID: "a"), "foreign or malformed attachment URL rejected")
        }
        check(NativeServicePhotoPreparation.prepareJPEG(Data()) == nil, "empty photograph rejected")
        check(NativeServicePhotoPreparation.prepareJPEG(Data("not-image".utf8)) == nil, "wrong format rejected")
        let context = CGContext(data: nil, width: 800, height: 400, bitsPerComponent: 8,
                                bytesPerRow: 800 * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0.4, green: 0.6, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 800, height: 400))
        let sourceImage = context.makeImage()!
        let originalPhoto = NSMutableData()
        let sourceDestination = CGImageDestinationCreateWithData(originalPhoto, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(sourceDestination, sourceImage, [kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 37.5, kCGImagePropertyGPSLongitude: 127.0]] as CFDictionary)
        check(CGImageDestinationFinalize(sourceDestination), "GPS source fixture generated")
        let sourceData = originalPhoto as Data
        let sourceProperties = CGImageSourceCopyPropertiesAtIndex(CGImageSourceCreateWithData(sourceData as CFData, nil)!, 0, nil)! as NSDictionary
        check(sourceProperties[kCGImagePropertyGPSDictionary] != nil, "fixture truly contains GPS metadata")
        let prepared = NativeServicePhotoPreparation.prepareJPEG(sourceData, maximumPixelSize: 200)!
        let imageSource = CGImageSourceCreateWithData(prepared as CFData, nil)!
        let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)! as NSDictionary
        check((properties[kCGImagePropertyPixelWidth] as? Int) == 200, "decode uses bounded destination width")
        check((properties[kCGImagePropertyPixelHeight] as? Int) == 100, "aspect ratio preserved")
        check(properties[kCGImagePropertyGPSDictionary] == nil, "actual JPEG no longer carries GPS")
        check(NativeServicePhotoPreparation.prepareJPEG(sourceData, maximumPixelSize: 0) == nil, "invalid downsample bounds rejected")
        print("Native service recovery: \(count) behavior checks passed")
    }
}
