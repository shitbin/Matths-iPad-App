import AVFoundation
import Foundation

private struct AuditScene: Decodable {
    let narration: String
}

private struct AuditStory: Decodable {
    let conceptId: String
    let scenes: [AuditScene]
}

private struct AuditShard: Decodable {
    let courseId: String
    let stories: [AuditStory]
}

private struct Measurement {
    let courseID: String
    let conceptID: String
    let seconds: Double
}

@main
struct CurriculumNarrationDurationAudit {
    static func preferredFemaleVoice(locale: String = "ko-KR") -> AVSpeechSynthesisVoice? {
        let prefix = locale.split(separator: "-").first.map(String.init) ?? "ko"
        let voices = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.lowercased().hasPrefix(prefix.lowercased())
        }
        return voices.first(where: { $0.gender == .female })
            ?? voices.first(where: { $0.language.caseInsensitiveCompare(locale) == .orderedSame })
            ?? voices.first
            ?? AVSpeechSynthesisVoice(language: locale)
    }

    static func synthesize(
        _ chunks: [String],
        voice: AVSpeechSynthesisVoice,
        rateFactor: Float
    ) -> Double? {
        let synthesizer = AVSpeechSynthesizer()
        let lock = NSLock()
        var duration = 0.0

        for chunk in chunks {
            let utterance = AVSpeechUtterance(string: chunk)
            utterance.voice = voice
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * rateFactor
            utterance.pitchMultiplier = 1
            utterance.preUtteranceDelay = 0.04
            var finished = false

            synthesizer.write(utterance) { buffer in
                guard let pcm = buffer as? AVAudioPCMBuffer else { return }
                if pcm.frameLength == 0 {
                    finished = true
                    return
                }
                lock.lock()
                duration += Double(pcm.frameLength) / pcm.format.sampleRate
                lock.unlock()
            }

            let deadline = Date().addingTimeInterval(60)
            while !finished && Date() < deadline {
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
            }
            if !finished { return nil }
        }
        return duration
    }

    static func main() throws {
        let paths = CommandLine.arguments.dropFirst()
        guard !paths.isEmpty else {
            fputs("usage: CurriculumNarrationDurationAudit <shard.json>...\n", stderr)
            exit(64)
        }
        guard let voice = preferredFemaleVoice(), voice.gender == .female else {
            fputs("Korean female system voice unavailable\n", stderr)
            exit(69)
        }

        let decoder = JSONDecoder()
        let conceptFilter = ProcessInfo.processInfo.environment["MATTHS_TTS_CONCEPT"]
        var measurements: [Measurement] = []
        var timeoutCount = 0

        for path in paths {
            let shard = try decoder.decode(
                AuditShard.self,
                from: Data(contentsOf: URL(fileURLWithPath: path))
            )
            for story in shard.stories {
                if let conceptFilter, story.conceptId != conceptFilter { continue }
                let chunks = story.scenes.flatMap {
                    CurriculumNarrationChunker.sentences(in: $0.narration)
                }
                if let seconds = synthesize(
                    chunks,
                    voice: voice,
                    rateFactor: CurriculumNarrationTimingPolicy.systemSpeechRateFactor
                ) {
                    measurements.append(Measurement(
                        courseID: shard.courseId,
                        conceptID: story.conceptId,
                        seconds: seconds
                    ))
                } else {
                    timeoutCount += 1
                    print("TIMEOUT \(shard.courseId) \(story.conceptId)")
                }
            }
        }

        guard let minimum = measurements.min(by: { $0.seconds < $1.seconds }),
              let maximum = measurements.max(by: { $0.seconds < $1.seconds }) else {
            exit(1)
        }
        let mean = measurements.reduce(0.0) { $0 + $1.seconds }
            / Double(measurements.count)
        let outside = measurements.filter {
            $0.seconds < CurriculumNarrationTimingPolicy.approximateMinimumSeconds
                || $0.seconds > CurriculumNarrationTimingPolicy.approximateMaximumSeconds
        }
        print("voice=\(voice.name) language=\(voice.language) gender=female")
        print(String(
            format: "measured=%d timeouts=%d min=%.3f minConcept=%@ max=%.3f maxConcept=%@ mean=%.3f outside=%d",
            measurements.count,
            timeoutCount,
            minimum.seconds,
            minimum.conceptID,
            maximum.seconds,
            maximum.conceptID,
            mean,
            outside.count
        ))
        for item in outside {
            print(String(
                format: "OUTSIDE course=%@ concept=%@ seconds=%.3f",
                item.courseID,
                item.conceptID,
                item.seconds
            ))
        }
        if timeoutCount != 0 || !outside.isEmpty { exit(1) }
    }
}
