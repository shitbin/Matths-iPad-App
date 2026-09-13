import SwiftUI

@MainActor
final class StudyHallScreenModel: ObservableObject {
    @Published var hall: ServerAPI.StudyHall?
    @Published var content: ServerAPI.StudyHallContent?
    @Published var answers: [Int: String] = [:] { didSet { saveLocalDraft() } }
    @Published var isLoading = false
    @Published var isLoadingContent = false
    @Published var action: String?
    @Published var downloadingID: String?
    @Published var errorMessage: String?
    @Published var noticeMessage: String?
    @Published var previewFile: AcademyPreviewFile?
    private weak var store: AppStore?
    private var owner: AppStore.AccountSessionBoundary?
    private var listRevision = NativeServiceRequestRevision()
    private var detailRevision = NativeServiceRequestRevision()
    private var mutationID = UUID()
    private var downloadID = UUID()
    private var restoring = false
    private var localDraft: NativeServiceDraft?

    func bind(_ value: AppStore) {
        store = value
        guard owner == nil || owner.map({ !value.ownsCurrentAccountSession($0) }) == true else { return }
        owner = value.captureAccountSessionBoundary()
        _ = listRevision.begin(); _ = detailRevision.begin(); mutationID = UUID(); downloadID = UUID()
        restoring = true
        hall = nil; content = nil; answers = [:]; localDraft = nil
        restoring = false
        isLoading = false; isLoadingContent = false; action = nil; downloadingID = nil; previewFile = nil
        errorMessage = nil; noticeMessage = nil
    }
    func load(tab: String = "NJE", reset: Bool = false) async {
        if let store { bind(store) }
        guard let store, let owner, let authorization = ServerAPI.captureAuthorization() else { return }
        let ticket = listRevision.begin()
        isLoading = true; errorMessage = nil
        defer { if listRevision.accepts(ticket) { isLoading = false } }
        do {
            let value = try await ServerAPI.studyHall(tab: tab, authorization: authorization)
            guard listRevision.accepts(ticket), !Task.isCancelled, store.ownsCurrentAccountSession(owner),
                  ServerAPI.isCurrentAuthorization(authorization) else { return }
            hall = value
        } catch {
            guard listRevision.accepts(ticket), store.ownsCurrentAccountSession(owner), !Task.isCancelled else { return }
            errorMessage = readable(error)
        }
    }
    func selectTab(_ tab: ServerAPI.StudyHallTab) async {
        guard hall?.activeTab != tab.code, action == nil else { return }
        closeContent()
        await load(tab: tab.code)
    }
    func open(_ item: ServerAPI.StudyHallContent) async { await open(contentID: item.id) }
    func open(contentID: String) async {
        guard !contentID.isEmpty, action == nil, let store, let owner, store.ownsCurrentAccountSession(owner),
              let authorization = ServerAPI.captureAuthorization() else { return }
        let ticket = detailRevision.begin()
        isLoadingContent = true; errorMessage = nil
        defer { if detailRevision.accepts(ticket) { isLoadingContent = false } }
        do {
            let value = try await ServerAPI.studyHallContent(contentID, authorization: authorization)
            guard detailRevision.accepts(ticket), !Task.isCancelled, store.ownsCurrentAccountSession(owner),
                  ServerAPI.isCurrentAuthorization(authorization) else { return }
            if hall?.activeTab != value.contentType { await load(tab: value.contentType) }
            guard detailRevision.accepts(ticket), !Task.isCancelled, store.ownsCurrentAccountSession(owner) else { return }
            install(value, restoringLocal: true)
        } catch {
            guard detailRevision.accepts(ticket), store.ownsCurrentAccountSession(owner), !Task.isCancelled else { return }
            errorMessage = readable(error)
        }
    }
    func closeContent() {
        guard action == nil else { return }
        _ = detailRevision.begin()
        isLoadingContent = false
        restoring = true; content = nil; answers = [:]; localDraft = nil; restoring = false
        noticeMessage = nil
    }
    func save() async { await persist(submit: false) }
    func submit() async { await persist(submit: true) }
    func download(_ asset: ServerAPI.StudyHallAsset) async {
        guard let content, downloadingID == nil, let store, let owner, store.ownsCurrentAccountSession(owner),
              let authorization = ServerAPI.captureAuthorization() else { return }
        let slot = DataScope.slot, identity = UUID()
        downloadID = identity; downloadingID = asset.id; errorMessage = nil
        defer { if downloadID == identity { downloadingID = nil } }
        do {
            let url = try await ServerAPI.downloadStudyHallAsset(contentID: content.id, asset: asset, accountSlot: slot, authorization: authorization)
            guard downloadID == identity, !Task.isCancelled, store.ownsCurrentAccountSession(owner), ServerAPI.isCurrentAuthorization(authorization) else { return }
            previewFile = AcademyPreviewFile(url: url)
        } catch {
            guard downloadID == identity, store.ownsCurrentAccountSession(owner), !Task.isCancelled else { return }
            errorMessage = readable(error)
        }
    }
    var answerRows: [ServerAPI.StudyHallAnswer] {
        answers.keys.sorted().map { ServerAPI.StudyHallAnswer(number: $0, answer: answers[$0] ?? "") }
    }
    private func saveLocalDraft() {
        guard !restoring, let content, content.progress.status != "SUBMITTED", var draft = localDraft,
              let store, let owner, store.ownsCurrentAccountSession(owner), draft.slot == DataScope.slot else { return }
        draft.fields = Dictionary(uniqueKeysWithValues: answers.map { (String($0.key), $0.value) })
        draft.fields["_contentVersion"] = contentVersion(content)
        do { try NativeServiceDraftDisk.save(draft); localDraft = draft }
        catch { errorMessage = "답안 초안을 이 기기에 저장하지 못했습니다. 저장 공간을 확인한 뒤 임시 저장해 주세요." }
    }
    private func persist(submit: Bool) async {
        guard let content, action == nil, content.progress.status != "SUBMITTED",
              let store, let owner, store.ownsCurrentAccountSession(owner),
              let authorization = ServerAPI.captureAuthorization() else { return }
        let sentAnswers = answers, rows = answerRows, identity = UUID()
        mutationID = identity; _ = detailRevision.begin(); _ = listRevision.begin()
        action = submit ? "submit" : "save"; errorMessage = nil
        defer { if mutationID == identity { action = nil } }
        do {
            let value = submit
                ? try await ServerAPI.submitStudyHallAnswers(contentID: content.id, answers: rows, authorization: authorization)
                : try await ServerAPI.saveStudyHallAnswers(contentID: content.id, answers: rows, authorization: authorization)
            guard mutationID == identity, !Task.isCancelled, store.ownsCurrentAccountSession(owner),
                  ServerAPI.isCurrentAuthorization(authorization), self.content?.id == content.id else { return }
            let newerAnswers = answers != sentAnswers ? answers : nil
            install(value, restoringLocal: false)
            if value.progress.status != "SUBMITTED", let newerAnswers {
                answers = newerAnswers
                noticeMessage = "보낸 답안을 저장했습니다. 그 뒤 수정한 답안은 기기에 보관 중입니다."
            } else {
                // Only clear the exact local revision that was sent. Another
                // screen instance may have edited this content during the call.
                if let disk = try? NativeServiceDraftDisk.load(slot: DataScope.slot, resource: "study:" + content.id),
                   disk.fields.filter({ !$0.key.hasPrefix("_") }) == Dictionary(uniqueKeysWithValues: sentAnswers.map { (String($0.key), $0.value) }) {
                    var cleared = disk; cleared.fields = [:]
                    try? NativeServiceDraftDisk.save(cleared)
                }
                noticeMessage = submit ? "최종 제출했습니다. 정답과 해설을 확인하세요." : "현재 답안을 저장했습니다."
            }
            replaceSummary(value)
        } catch {
            guard mutationID == identity, store.ownsCurrentAccountSession(owner), !Task.isCancelled else { return }
            errorMessage = readable(error)
        }
    }
    private func install(_ value: ServerAPI.StudyHallContent, restoringLocal: Bool) {
        restoring = true
        content = value
        answers = Dictionary(value.progress.answers.map { ($0.number, $0.answer) }, uniquingKeysWith: { _, last in last })
        if restoringLocal {
            do {
                let draft = try NativeServiceDraftDisk.load(slot: DataScope.slot, resource: "study:" + value.id)
                localDraft = draft
                if value.progress.status != "SUBMITTED", draft.fields["_contentVersion"] == contentVersion(value) {
                    let allowedNumbers = Set(1...max(value.itemCount, value.questions.count, 1))
                    for (key, answer) in draft.fields {
                        if let number = Int(key), allowedNumbers.contains(number) { answers[number] = answer }
                    }
                    if !draft.fields.isEmpty { noticeMessage = "이 기기에 보관한 미전송 답안을 복원했습니다. 임시 저장으로 계정에 반영하세요." }
                } else if !draft.fields.isEmpty && value.progress.status != "SUBMITTED" {
                    try NativeServiceDraftDisk.backup(slot: DataScope.slot, resource: "study:" + value.id)
                    localDraft = .init(slot: DataScope.slot, resource: "study:" + value.id)
                    noticeMessage = "콘텐츠가 바뀌어 이전 초안을 합치지 않았습니다. 현재 서버 답안을 보여드립니다."
                }
            } catch {
                do {
                    try NativeServiceDraftDisk.backup(slot: DataScope.slot, resource: "study:" + value.id)
                    localDraft = .init(slot: DataScope.slot, resource: "study:" + value.id)
                    errorMessage = "이전 초안을 읽지 못해 별도 보관했습니다. 현재 서버 답안에서 다시 작성할 수 있어요."
                } catch {
                    localDraft = nil
                    errorMessage = "이전 초안을 안전하게 보관하지 못했습니다. 새 답안은 임시 저장 버튼으로 계정에 저장해 주세요."
                }
            }
        } else {
            localDraft = NativeServiceDraft(slot: DataScope.slot, resource: "study:" + value.id)
        }
        restoring = false
    }
    private func contentVersion(_ value: ServerAPI.StudyHallContent) -> String {
        NativeServiceDraft.fingerprint(["id": value.id, "updated": value.updatedAt ?? "",
                                       "questions": value.questions.map { String($0.number) + "|" + $0.id + "|" + $0.stem }.joined(separator: "\n")])
    }
    private func replaceSummary(_ value: ServerAPI.StudyHallContent) {
        guard var hall else { return }
        if let index = hall.items.firstIndex(where: { $0.id == value.id }) { hall.items[index] = value }
        if hall.continuing?.id == value.id { hall.continuing = value.progress.status == "SUBMITTED" ? nil : value }
        else if value.progress.status == "IN_PROGRESS" { hall.continuing = value }
        self.hall = hall
    }
    private func readable(_ error: Error) -> String {
        (error as? ServerAPIError)?.errorDescription ?? "요청을 처리하지 못했습니다. 연결을 확인하고 다시 시도해 주세요."
    }
}

/// 웹 수험관의 목록·문제·답안·제출·자료 기능을 Bearer API로 직접 제공한다.
/// iPhone 가로에서는 왼쪽 콘텐츠와 오른쪽 답안지를 한 화면에 고정한다.
struct StudyHallScreen: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model = StudyHallScreenModel()
    @State private var confirmingSubmission = false

    var body: some View {
        GeometryReader { viewport in
            let split = !dynamicTypeSize.isAccessibilitySize &&
                (viewport.size.width >= 900 || viewport.size.height < 500)
            Group {
                if model.isLoading && model.hall == nil {
                    stateView("학습 콘텐츠를 불러오는 중입니다", progress: true)
                } else if let hall = model.hall {
                    if split {
                        HStack(spacing: Tokens.Space.s3) {
                            catalog(hall, compact: true)
                                .frame(width: min(390, viewport.size.width * 0.42))
                            detailOrPrompt
                        }
                        .padding(.leading, max(12, viewport.safeAreaInsets.leading + 12))
                        .padding(.trailing, max(12, viewport.safeAreaInsets.trailing + 12))
                        .padding(.vertical, Tokens.Space.s2)
                    } else if model.content != nil || model.isLoadingContent {
                        detailOrPrompt
                    } else {
                        catalog(hall, compact: false)
                    }
                } else {
                    stateView(model.errorMessage ?? "학습 콘텐츠를 불러오지 못했습니다.")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task {
                model.bind(store)
                if model.hall == nil { await model.load() }
                await consumeDeepLinkIfNeeded()
                if split, model.content == nil, let first = model.hall?.continuing ?? model.hall?.items.first {
                    await model.open(first)
                }
            }
        }
        .background(Tokens.paper)
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { _ in
            Task { await model.load(reset: true) }
        }
        .onChange(of: store.requestedStudyHallContentID) { _, contentID in
            guard let contentID, !contentID.isEmpty else { return }
            store.requestedStudyHallContentID = nil
            Task { await model.open(contentID: contentID) }
        }
        .compactHeightSheet(item: $model.previewFile) { preview in
            CommunityFilePreview(url: preview.url) { model.previewFile = nil }
                .ignoresSafeArea()
        }
        .alert("최종 제출할까요?", isPresented: $confirmingSubmission) {
            Button("취소", role: .cancel) {}
            Button("제출", role: .destructive) { NativeServiceActions.run(store: store) { await model.submit() } }
        } message: {
            Text("제출 후에는 답안을 바꿀 수 없고, 채점 결과와 해설이 공개됩니다.")
        }
    }

    private func consumeDeepLinkIfNeeded() async {
        guard let contentID = store.requestedStudyHallContentID else { return }
        store.requestedStudyHallContentID = nil
        await model.open(contentID: contentID)
    }

    private func catalog(_ hall: ServerAPI.StudyHall, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            HStack(spacing: Tokens.Space.s2) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("수험관").font(.mTitle).foregroundStyle(Tokens.ink)
                    Text("오늘 풀 콘텐츠를 고르고 진행을 남기세요.")
                        .font(.mCaption).foregroundStyle(Tokens.text2).lineLimit(1)
                }
                Spacer()
                Button { store.route = .storeCatalog } label: {
                    Label("무료 자료", systemImage: "arrow.down.doc.fill")
                        .font(.mCaption).frame(minHeight: 44)
                }
                .buttonStyle(.plain).foregroundStyle(Tokens.primary)
                Button { store.route = .services } label: {
                    Image(systemName: "xmark").frame(width: 44, height: 44)
                }
                .buttonStyle(.plain).foregroundStyle(Tokens.text2)
                .accessibilityLabel("수험관 닫기")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Tokens.Space.s2) {
                    ForEach(hall.tabs) { tab in
                        let selected = hall.activeTab == tab.code
                        Button { Task { await model.selectTab(tab) } } label: {
                            Text(tab.label).font(.mCaption).lineLimit(1)
                                .padding(.horizontal, 14).frame(minHeight: 44)
                                .foregroundStyle(selected ? Tokens.onPrimary : Tokens.text2)
                                .background(selected ? Tokens.actionPrimary : Tokens.surface,
                                            in: Capsule())
                                .overlay { Capsule().strokeBorder(Tokens.line, lineWidth: selected ? 0 : 1) }
                        }.buttonStyle(.plain)
                    }
                }
            }

            if let continuing = hall.continuing {
                Button { Task { await model.open(continuing) } } label: {
                    HStack(spacing: Tokens.Space.s3) {
                        Image(systemName: "play.fill").foregroundStyle(Tokens.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("이어서 하기").font(.mMicro).foregroundStyle(Tokens.primary)
                            Text(continuing.title).font(.mBodyB).foregroundStyle(Tokens.ink).lineLimit(1)
                        }
                        Spacer()
                        Text("\(continuing.progress.percent)%").font(.mCaption).foregroundStyle(Tokens.text2)
                    }
                    .padding(Tokens.Space.s3).studyHallSurface()
                }.buttonStyle(.plain)
            }

            if hall.items.isEmpty {
                stateView("이 영역에는 공개된 콘텐츠가 아직 없습니다.")
            } else {
                ScrollView {
                    LazyVStack(spacing: Tokens.Space.s2) {
                        ForEach(hall.items) { item in contentRow(item) }
                    }
                }
                .refreshable { await model.load(tab: hall.activeTab) }
            }
        }
        .padding(compact ? 0 : Tokens.Space.s5)
    }

    private func contentRow(_ item: ServerAPI.StudyHallContent) -> some View {
        Button { Task { await model.open(item) } } label: {
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.series.isEmpty ? item.tabLabel : item.series)
                        .font(.mMicro).foregroundStyle(Tokens.primary).lineLimit(1)
                    Spacer()
                    if item.progress.status == "SUBMITTED" {
                        Label("완료", systemImage: "checkmark.circle.fill")
                            .font(.mMicro).foregroundStyle(Tokens.successInk)
                    }
                }
                Text(item.title).font(.mHeading).foregroundStyle(Tokens.ink)
                    .multilineTextAlignment(.leading).lineLimit(2)
                Text(metadata(item)).font(.mCaption).foregroundStyle(Tokens.text2).lineLimit(1)
                ProgressView(value: Double(item.progress.percent), total: 100)
                    .tint(Tokens.primary)
                Text(progressLabel(item.progress)).font(.mMicro).foregroundStyle(Tokens.text3)
            }
            .padding(Tokens.Space.s3).studyHallSurface()
        }
        .buttonStyle(.plain)
        .accessibilityHint("문제와 답안지를 엽니다")
    }

    @ViewBuilder private var detailOrPrompt: some View {
        if model.isLoadingContent {
            stateView("문제와 답안지를 불러오는 중입니다", progress: true)
        } else if let content = model.content {
            detail(content)
        } else {
            stateView(model.errorMessage ?? "학습 콘텐츠를 선택하세요.", systemImage: model.errorMessage == nil ? "hand.tap" : "exclamationmark.triangle")
        }
    }

    private func detail(_ content: ServerAPI.StudyHallContent) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Tokens.Space.s2) {
                Button { model.closeContent() } label: {
                    Label("목록", systemImage: "chevron.left").frame(minHeight: 44)
                }.buttonStyle(.plain).foregroundStyle(Tokens.primary)
                Spacer()
                if content.progress.status == "SUBMITTED" {
                    Label("제출 완료", systemImage: "checkmark.seal.fill")
                        .font(.mCaption).foregroundStyle(Tokens.successInk)
                }
            }
            .padding(.horizontal, Tokens.Space.s4)

            ScrollViewReader { reader in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Tokens.Space.s4) {
                        detailHeader(content)
                        if !content.assets.isEmpty { files(content) }
                        if content.contentType == "ERROR_REPORT" { errorReport(content) }
                        if totalItems(content) > 0 {
                            answerHeader(content)
                            ForEach(1...totalItems(content), id: \.self) { number in
                                question(content, number: number).id(number)
                            }
                            actionBar(content)
                        }
                    }
                    .padding(Tokens.Space.s4)
                }
                .onAppear {
                    if content.progress.status != "NOT_STARTED", content.progress.lastQuestionNumber > 0 {
                        reader.scrollTo(content.progress.lastQuestionNumber, anchor: .top)
                    }
                }
            }
        }
        .background(Tokens.paper)
    }

    private func detailHeader(_ content: ServerAPI.StudyHallContent) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text(content.series.isEmpty ? content.tabLabel : content.series)
                .font(.mMicro).foregroundStyle(Tokens.primary)
            Text(content.title).font(.mTitle).foregroundStyle(Tokens.ink)
            if !content.description.isEmpty {
                Text(content.description).font(.mBody).foregroundStyle(Tokens.text2)
            }
            HStack(spacing: Tokens.Space.s3) {
                Label(content.grade, systemImage: "person.fill")
                if !content.subject.isEmpty { Label(content.subject, systemImage: "function") }
                if content.timeLimitMinutes > 0 {
                    Label("\(content.timeLimitMinutes)분", systemImage: "clock.fill")
                }
                Spacer()
                Text("\(content.progress.percent)%")
                    .font(.mHeading).foregroundStyle(Tokens.primary)
            }
            .font(.mCaption).foregroundStyle(Tokens.text2)
            ProgressView(value: Double(content.progress.percent), total: 100).tint(Tokens.primary)
            if content.progress.status == "SUBMITTED" {
                Text("\(points(content.progress.scorePoints))/\(points(content.progress.totalPoints))점 · 정답 \(content.progress.correctCount)개 · \(content.progress.scorePercent)%")
                    .font(.mCaption).foregroundStyle(Tokens.successInk)
            }
        }.studyHallSurface()
    }

    private func files(_ content: ServerAPI.StudyHallContent) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text("학습 자료").font(.mHeading).foregroundStyle(Tokens.ink)
            ForEach(content.assets.filter { $0.kind != "THUMBNAIL" }) { asset in
                let locked = asset.kind == "SOLUTION_PDF" && content.progress.status != "SUBMITTED"
                Button { if !locked { NativeServiceActions.run(store: store) { await model.download(asset) } } } label: {
                    HStack(spacing: Tokens.Space.s3) {
                        Image(systemName: locked ? "lock.fill" : fileIcon(asset))
                            .frame(width: 28).foregroundStyle(locked ? Tokens.text3 : Tokens.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(asset.originalName).font(.mBodyB).foregroundStyle(Tokens.ink).lineLimit(1)
                            Text(locked ? "최종 제출 후 공개" : byteLabel(asset.sizeBytes))
                                .font(.mMicro).foregroundStyle(Tokens.text3)
                        }
                        Spacer()
                        if model.downloadingID == asset.id { ProgressView() }
                        else if !locked { Image(systemName: "arrow.down.circle") }
                    }.frame(minHeight: 48)
                }
                .buttonStyle(.plain).disabled(locked || model.downloadingID != nil)
            }
        }.studyHallSurface()
    }

    private func errorReport(_ content: ServerAPI.StudyHallContent) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            reportRow("자주 틀리는 이유", content.commonMistake)
            reportRow("잘못된 접근", content.wrongApproach)
            reportRow("올바른 풀이 방법", content.correctApproach)
            if !content.relatedProblem.isEmpty { reportRow("관련 대표 문제", content.relatedProblem) }
        }.studyHallSurface()
    }

    private func reportRow(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.mMicro).foregroundStyle(Tokens.primary)
            Text(body.isEmpty ? "등록된 내용이 없습니다." : body)
                .font(.mBody).foregroundStyle(Tokens.text1)
        }
    }

    private func answerHeader(_ content: ServerAPI.StudyHallContent) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text("답안지").font(.mTitle).foregroundStyle(Tokens.ink)
                Text(content.progress.status == "SUBMITTED"
                     ? "채점 결과와 해설을 확인하세요."
                     : "중간에 나가기 전 임시 저장할 수 있습니다.")
                    .font(.mCaption).foregroundStyle(Tokens.text2)
            }
            Spacer()
            Text("\(answeredCount(content)) / \(totalItems(content))")
                .font(.mHeading).foregroundStyle(Tokens.primary)
                .accessibilityLabel("\(totalItems(content))문항 중 \(answeredCount(content))문항 입력")
        }
    }

    private func question(_ content: ServerAPI.StudyHallContent, number: Int) -> some View {
        let item = content.questions.first(where: { $0.number == number })
        let submitted = content.progress.status == "SUBMITTED"
        return VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            HStack(alignment: .top, spacing: Tokens.Space.s3) {
                Text("\(number)").font(.mHeading).foregroundStyle(Tokens.onPrimary)
                    .frame(width: 40, height: 40).background(Tokens.actionPrimary, in: Circle())
                Text(item?.stem.nonEmptyStudyHallText ?? "\(number)번 답안을 입력하세요.")
                    .font(.mBodyB).foregroundStyle(Tokens.ink).frame(maxWidth: .infinity, alignment: .leading)
                if submitted, let correct = item?.isCorrect {
                    Text(correct ? "정답" : "오답").font(.mMicro)
                        .foregroundStyle(correct ? Tokens.success : Tokens.danger)
                }
            }
            if let choices = item?.choices, !choices.isEmpty {
                ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                    Text("\(index + 1). \(choice)").font(.mCaption).foregroundStyle(Tokens.text2)
                }
            }
            if item?.answerType == "short-answer" {
                TextField("답을 입력하세요", text: answerBinding(number))
                    .textFieldStyle(.roundedBorder).disabled(submitted || model.action == "submit")
                    .accessibilityLabel("\(number)번 답")
            } else {
                HStack(spacing: Tokens.Space.s2) {
                    ForEach(1...5, id: \.self) { choice in
                        Button { model.answers[number] = String(choice) } label: {
                            Text("\(choice)").font(.mBodyB)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .foregroundStyle(model.answers[number] == String(choice) ? Tokens.onPrimary : Tokens.text1)
                                .background(model.answers[number] == String(choice) ? Tokens.actionPrimary : Tokens.surface,
                                            in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                                .overlay { RoundedRectangle(cornerRadius: Tokens.Radius.md).strokeBorder(Tokens.line, lineWidth: 1) }
                        }
                        .buttonStyle(.plain).disabled(submitted || model.action == "submit")
                        .accessibilityLabel("\(number)번 답 \(choice)")
                        .accessibilityAddTraits(model.answers[number] == String(choice) ? .isSelected : [])
                    }
                }
            }
            if submitted, let item {
                VStack(alignment: .leading, spacing: 4) {
                    Text("정답 \(item.correctAnswer ?? "-") · \(points(item.points))점")
                        .font(.mCaption).foregroundStyle(Tokens.ink)
                    Text(item.explanation?.nonEmptyStudyHallText ?? "해설 자료를 확인하세요.")
                        .font(.mCaption).foregroundStyle(Tokens.text2)
                }
                .padding(Tokens.Space.s3).frame(maxWidth: .infinity, alignment: .leading)
                .background(Tokens.paper, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
            }
        }.studyHallSurface()
    }

    private func actionBar(_ content: ServerAPI.StudyHallContent) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            if let notice = model.noticeMessage {
                Label(notice, systemImage: "checkmark.circle.fill")
                    .font(.mCaption).foregroundStyle(Tokens.successInk)
            }
            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.mCaption).foregroundStyle(Tokens.dangerInk)
            }
            if content.progress.status != "SUBMITTED" {
                HStack(spacing: Tokens.Space.s3) {
                    Button { NativeServiceActions.run(store: store) { await model.save() } } label: {
                        if model.action == "save" { ProgressView() } else { Text("임시 저장") }
                    }
                    .buttonStyle(SecondaryButtonStyle()).disabled(model.action != nil)
                    Button { confirmingSubmission = true } label: {
                        if model.action == "submit" { ProgressView().tint(Tokens.onPrimary) }
                        else { Text("최종 제출") }
                    }
                    .buttonStyle(PrimaryButtonStyle()).disabled(model.action != nil)
                }
            }
        }.padding(.bottom, Tokens.Space.s5)
    }

    private func answerBinding(_ number: Int) -> Binding<String> {
        Binding(get: { model.answers[number] ?? "" }, set: {
            model.answers[number] = String($0.prefix(100))
        })
    }

    private func totalItems(_ content: ServerAPI.StudyHallContent) -> Int {
        max(content.itemCount, content.questions.count)
    }

    private func answeredCount(_ content: ServerAPI.StudyHallContent) -> Int {
        model.answers.values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    private func metadata(_ item: ServerAPI.StudyHallContent) -> String {
        [item.grade, item.subject, item.difficulty,
         item.itemCount > 0 ? "\(item.itemCount)문항" : "",
         item.timeLimitMinutes > 0 ? "\(item.timeLimitMinutes)분" : ""]
            .filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func progressLabel(_ progress: ServerAPI.StudyHallProgress) -> String {
        if progress.status == "SUBMITTED" { return "제출 완료 · 정답 \(progress.correctCount)개" }
        if progress.answeredCount > 0 { return "\(progress.answeredCount)문항 입력" }
        return "시작 전"
    }

    private func points(_ value: Double) -> String {
        value.isFinite ? String(format: value.rounded() == value ? "%.0f" : "%.1f", value) : "—"
    }

    private func fileIcon(_ asset: ServerAPI.StudyHallAsset) -> String {
        if asset.mimeType.lowercased().contains("pdf") { return "doc.richtext.fill" }
        if asset.mimeType.lowercased().hasPrefix("image/") { return "photo.fill" }
        return "doc.fill"
    }

    private func byteLabel(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func stateView(
        _ message: String,
        progress: Bool = false,
        systemImage: String = "books.vertical"
    ) -> some View {
        VStack(spacing: Tokens.Space.s3) {
            if progress { ProgressView().tint(Tokens.primary) }
            else { Image(systemName: systemImage).font(.system(size: 30)).foregroundStyle(Tokens.text3) }
            Text(message).font(.mBody).foregroundStyle(Tokens.text2).multilineTextAlignment(.center)
            if !progress, model.hall == nil {
                Button("다시 시도") { Task { await model.load(reset: true) } }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(Tokens.Space.s5).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct StudyHallSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Tokens.Space.s4)
            .background(Tokens.surface,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .strokeBorder(Tokens.line, lineWidth: 1)
            }
    }
}

private extension View {
    func studyHallSurface() -> some View { modifier(StudyHallSurface()) }
}

private extension String {
    var nonEmptyStudyHallText: String? { isEmpty ? nil : self }
}
