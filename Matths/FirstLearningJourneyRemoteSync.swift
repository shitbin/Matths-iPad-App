import Foundation

@MainActor
extension FirstLearningJourneyStore {
    static let syncFileName = "mobile-first-learning-sync-v1.json"

    func resetRemoteSession() {
        remoteGeneration = UUID(); remoteTask?.cancel(); remoteTask = nil
        remoteCache = nil; remoteCacheBlocked = false; remoteConflict = nil
        syncMessage = nil; isSyncing = false; suppressRemoteScheduling = false
        remoteSyncNeedsRetry = false
    }

    func scheduleRemoteSync() {
        guard !suppressRemoteScheduling, remoteConflict == nil, remoteTask == nil,
              journey.pendingTutorialAction == nil, !journey.isTerminal,
              DataScope.slot != "guest", ServerAPI.captureAuthorization() != nil else { return }
        Task { await synchronize() }
    }

    /// GET first on every foreground/session initialization. Updates are
    /// coalesced behind one in-flight task; each PATCH uses a durable CAS base.
    func synchronize() async {
        if let task = remoteTask { await task.value; return }
        guard journey.pendingTutorialAction == nil, !remoteCacheBlocked, remoteConflict == nil, let authorization = ServerAPI.captureAuthorization(),
              DataScope.slot != "guest" else { return }
        let owner = MobileRequestOwner(authorization: authorization)
        let generation = remoteGeneration
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performRemoteSync(owner: owner, generation: generation)
        }
        remoteTask = task
        await task.value
        guard generation == remoteGeneration else { return }
        remoteTask = nil
    }

    private func performRemoteSync(owner: MobileRequestOwner, generation: UUID) async {
        isSyncing = true
        remoteSyncNeedsRetry = false
        defer { if generation == remoteGeneration { isSyncing = false } }
        func validate() throws {
            try owner.validate()
            guard generation == remoteGeneration, journey.slot == owner.slot else { throw CancellationError() }
        }
        do {
            try validate()
            let support = try await MobileFeatureSupport.shared.capabilities(for: owner)
            try validate()
            guard support.firstLearningState else {
                syncMessage = "이 서버에서는 첫 학습을 이 기기에 보관합니다. 학습 진도는 기존 방식으로 저장됩니다."
                return
            }
            try loadRemoteCache(owner: owner)
            var remote = try await ServerAPI.getFirstLearningState(owner: owner)
            try validate()
            for _ in 0..<6 {
                let local = FirstLearningRemoteState(journey)
                let pristine = journey.stage == .goal && journey.diagnosticAnswers.isEmpty
                    && journey.conceptID == nil && journey.pendingTutorialAction == nil
                let decision = FirstLearningMergeDecision.decide(local: local, cache: remoteCache, remote: remote, pristine: pristine)
                switch decision {
                case .adoptRemote:
                    try adoptRemote(remote, owner: owner)
                    syncMessage = remote.state == nil ? nil : "다른 기기에서 진행한 첫 학습을 불러왔습니다."
                    return
                case .acknowledged:
                    try acknowledge(remote, local: local, owner: owner)
                    syncMessage = nil
                    return
                case .conflict:
                    remoteConflict = remote
                    syncMessage = "다른 기기에서 첫 학습이 변경되었습니다. 이 기기의 기록은 그대로 보관했습니다. 이어갈 기록을 선택해 주세요."
                    return
                case .uploadLocal:
                    // Existing dashboard actions clear the server resume state.
                    // Never send a terminal/pending blob after that clear.
                    guard !journey.isTerminal, journey.pendingTutorialAction == nil else { return }
                    let revision = remote.revision
                    // Persist the GET base before PATCH. A lost response must
                    // recover through 409/current, not start at revision zero.
                    try saveRemoteCache(.init(slot: owner.slot, origin: owner.origin, revision: revision,
                                              baseState: remote.state, localBaseline: remoteCache?.localBaseline), owner: owner)
                    switch try await ServerAPI.patchFirstLearningState(local, revision: revision, owner: owner) {
                    case .saved(let result):
                        try validate()
                        try acknowledge(result, local: local, owner: owner)
                        remote = result
                        if local == FirstLearningRemoteState(journey) { syncMessage = nil; return }
                    case .conflict(let current):
                        try validate()
                        // Lost successful response: exact payload equality is an
                        // acknowledgement, never a blind overwrite of current.
                        if current.state == local {
                            try acknowledge(current, local: local, owner: owner); remote = current
                            if local == FirstLearningRemoteState(journey) { syncMessage = nil; return }
                        } else {
                            remoteConflict = current
                            syncMessage = "다른 기기의 진행과 충돌했습니다. 두 기록 중 이어갈 기록을 선택해 주세요."
                            return
                        }
                    }
                }
            }
            syncMessage = "최근 변경은 이 기기에 보관했습니다. 연결 상태가 안정되면 다시 동기화해 주세요."
            remoteSyncNeedsRetry = true
        } catch is CancellationError {
            // Account switch/cancel is not a user-facing service failure.
        } catch {
            guard owner.isCurrent, generation == remoteGeneration else { return }
            syncMessage = "첫 학습 이어하기를 계정에 확인하지 못했습니다. 이 기기의 기록은 보관되어 있습니다. 다시 확인해 주세요."
            remoteSyncNeedsRetry = true
        }
    }

    func useRemoteJourney() {
        guard let remote = remoteConflict, let auth = ServerAPI.captureAuthorization() else { return }
        let owner = MobileRequestOwner(authorization: auth)
        do {
            try backupLocalJourney()
            try adoptRemote(remote, owner: owner)
            remoteConflict = nil; syncMessage = nil
            remoteSyncNeedsRetry = false
        } catch { self.error = "기존 기록을 보관하거나 선택한 기록을 저장하지 못했습니다. 저장 공간을 확인해 주세요." }
    }

    /// Only this explicit user choice rebases a dirty local draft onto a newer
    /// server revision. Normal retries must never call this automatically.
    func keepLocalJourney() async {
        guard let remote = remoteConflict, let auth = ServerAPI.captureAuthorization() else { return }
        let owner = MobileRequestOwner(authorization: auth)
        do {
            try backupLocalJourney()
            try saveRemoteCache(.init(slot: owner.slot, origin: owner.origin, revision: remote.revision,
                                      baseState: remote.state, localBaseline: nil), owner: owner)
            remoteConflict = nil; syncMessage = nil
            remoteSyncNeedsRetry = false
            await synchronize()
        } catch { self.error = "이 기기의 기록을 안전하게 보관하지 못했습니다. 저장 공간을 확인해 주세요." }
    }

    func recoverRemoteCache() async {
        guard remoteCacheBlocked, let auth = ServerAPI.captureAuthorization() else { return }
        let owner = MobileRequestOwner(authorization: auth)
        do {
            try owner.validate()
            let source = DataScope.url(Self.syncFileName, for: owner.slot)
            if FileManager.default.fileExists(atPath: source.path) {
                let backup = source.deletingPathExtension().appendingPathExtension("unreadable-\(UUID().uuidString).json")
                try FileManager.default.moveItem(at: source, to: backup)
            }
            remoteCache = nil; remoteCacheBlocked = false; syncMessage = nil
            remoteSyncNeedsRetry = false
            await synchronize()
        } catch { self.error = "이어하기 기록의 원본을 안전하게 보관하지 못했습니다. 저장 공간을 확인해 주세요." }
    }

    /// Cancel the local publication path before sending COMPLETE/SKIP/RESTART.
    /// Server-side CAS ensures even an already-sent PATCH cannot revive a clear.
    func willSendTutorialAction() {
        remoteGeneration = UUID(); remoteTask?.cancel(); remoteTask = nil; isSyncing = false
    }

    func didSaveTutorialAction(_ action: String) {
        guard let auth = ServerAPI.captureAuthorization() else { return }
        let owner = MobileRequestOwner(authorization: auth)
        // The legacy tutorial envelope has no resume revision. Fetch its new
        // revision before future writes instead of guessing revision + 1.
        suppressRemoteScheduling = true
        let saved = update { $0.pendingTutorialAction = nil }
        suppressRemoteScheduling = false
        guard saved else { return }
        remoteCache = nil
        let generation = remoteGeneration
        remoteTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { if generation == self.remoteGeneration { self.remoteTask = nil } }
            do {
                let support = try await MobileFeatureSupport.shared.capabilities(for: owner)
                guard support.firstLearningState else { return }
                let remote = try await ServerAPI.getFirstLearningState(owner: owner)
                try owner.validate()
                guard generation == self.remoteGeneration else { return }
                guard remote.state == nil else {
                    self.remoteConflict = remote
                    self.syncMessage = "다른 기기에서 새 첫 학습을 시작했습니다. 이어갈 기록을 선택해 주세요."
                    return
                }
                try self.saveRemoteCache(.init(slot: owner.slot, origin: owner.origin, revision: remote.revision,
                                               baseState: nil, localBaseline: FirstLearningRemoteState(self.journey),
                                               terminalAcknowledged: action != "RESTART"), owner: owner)
            } catch {
                guard owner.isCurrent, generation == self.remoteGeneration else { return }
                self.syncMessage = "안내 종료는 저장했습니다. 다른 기기의 최신 이어하기 상태는 연결 후 확인합니다."
                self.remoteSyncNeedsRetry = true
            }
        }
    }

    private func adoptRemote(_ remote: FirstLearningRemoteEnvelope, owner: MobileRequestOwner) throws {
        try owner.validate()
        let local: FirstLearningJourney
        if let value = remote.state {
            local = try value.localJourney(slot: owner.slot, deadLetters: SyncEngine.shared.deadLettered,
                                           quarantined: SyncEngine.shared.quarantinedLines)
        } else { local = .init(slot: owner.slot, goal: goal) }
        try FirstLearningJourneyPersistence.save(local, to: DataScope.url(Self.fileName, for: owner.slot))
        journey = local; goal = local.goal
        UserDefaults.standard.set(goal.rawValue, forKey: goalKey(owner.slot))
        try saveRemoteCache(.init(slot: owner.slot, origin: owner.origin, revision: remote.revision,
                                  baseState: remote.state, localBaseline: FirstLearningRemoteState(local)), owner: owner)
    }
    private func acknowledge(_ remote: FirstLearningRemoteEnvelope, local: FirstLearningRemoteState, owner: MobileRequestOwner) throws {
        try saveRemoteCache(.init(slot: owner.slot, origin: owner.origin, revision: remote.revision,
                                  baseState: remote.state, localBaseline: local,
                                  terminalAcknowledged: remoteCache?.terminalAcknowledged == true && remote.state == nil), owner: owner)
    }
    private func loadRemoteCache(owner: MobileRequestOwner) throws {
        guard remoteCache == nil else { return }
        let path = DataScope.url(Self.syncFileName, for: owner.slot)
        guard FileManager.default.fileExists(atPath: path.path) else { return }
        do {
            let meta = try path.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard meta.isRegularFile == true, (meta.fileSize ?? Int.max) <= 131_072 else { throw CocoaError(.fileReadCorruptFile) }
            let value = try JSONDecoder().decode(FirstLearningSyncCache.self, from: Data(contentsOf: path))
            guard value.isValid, value.slot == owner.slot else { throw CocoaError(.fileReadCorruptFile) }
            if value.origin == owner.origin { remoteCache = value }
        } catch {
            remoteCacheBlocked = true
            throw error
        }
    }
    private func saveRemoteCache(_ value: FirstLearningSyncCache, owner: MobileRequestOwner) throws {
        try owner.validate()
        guard value.isValid, value.slot == owner.slot, value.origin == owner.origin else { throw CocoaError(.coderInvalidValue) }
        let data = try JSONEncoder().encode(value)
        #if os(iOS)
        try data.write(to: DataScope.url(Self.syncFileName, for: owner.slot), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: DataScope.url(Self.syncFileName, for: owner.slot), options: [.atomic])
        #endif
        remoteCache = value
    }
    private func backupLocalJourney() throws {
        let source = DataScope.url(Self.fileName, for: journey.slot)
        if FileManager.default.fileExists(atPath: source.path) {
            try FileManager.default.copyItem(at: source, to: source.deletingPathExtension().appendingPathExtension("conflict-\(UUID().uuidString).json"))
        }
    }
}
