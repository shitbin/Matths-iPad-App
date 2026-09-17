import SwiftUI

/// The provider has already authenticated. This screen collects only the profile
/// and explicit consents required to finish the same native authentication attempt.
struct NativeSocialRegistrationScreen: View {
    let context: NativeSocialRegistrationContext
    let onComplete: (AuthResponse) -> Void
    let onCancel: () -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var draft: NativeSocialRegistrationDraft
    @State private var presentedPicker: NativeRegistrationPicker?
    @State private var isSubmitting = false
    @State private var hasExpired = false
    @State private var reauthenticationReason: String?
    @State private var showsValidation = false
    @State private var serverError: String?
    @State private var submissionID: UUID?
    @State private var submissionTask: Task<Void, Never>?
    @FocusState private var focusedField: NativeSocialRegistrationIssue.Field?

    private let expiryTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(context: NativeSocialRegistrationContext,
         onComplete: @escaping (AuthResponse) -> Void,
         onCancel: @escaping () -> Void) {
        self.context = context
        self.onComplete = onComplete
        self.onCancel = onCancel
        var initial = NativeSocialRegistrationDraft()
        initial.realName = context.registration.suggestedRealName ?? ""
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-nativeRegistrationCapture"),
           context.registration.token == "capture-only-not-a-server-ticket",
           let index = arguments.firstIndex(of: "-nativeRegistrationFixture"),
           arguments.indices.contains(index + 1) {
            // Synthetic values exist only for local screen captures. The context
            // refuses every registration request in capture mode. Consents stay off.
            initial.realName = "테스트 사용자"
            initial.name = "화면검수"
            initial.birthDate = NativeSocialRegistrationDraft.calendar.date(
                from: DateComponents(year: 2008, month: 2, day: 29))
            switch arguments[index + 1] {
            case "HighSchool": initial.schoolGrade = 10
            case "University": initial.schoolGrade = 14
            case "Retaker": initial.schoolGrade = 13
            case "Worker": initial.schoolGrade = 15
            case "OverseasSchool":
                initial.schoolGrade = 11
                initial.schoolRegion = "해외"
                initial.schoolCode = "OVERSEAS_HIGH_SCHOOL"
                initial.schoolName = "Example High School"
            case "OverseasUniversity":
                initial.schoolGrade = 14
                initial.universityCode = "OVERSEAS_UNIVERSITY"
                initial.universityName = "Example University"
            default: break
            }
        }
        #endif
        _draft = State(initialValue: initial)
        _hasExpired = State(initialValue: context.isExpired)
    }

    private var compactHeight: Bool { verticalSizeClass == .compact }
    private var providerName: String { context.registration.provider == "apple" ? "Apple" : "카카오" }
    private var issue: NativeSocialRegistrationIssue? { draft.firstIssue() }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                registrationForm(in: geometry.size)
            }
            .background(Tokens.paper)
            .navigationTitle("회원정보 확인")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", action: cancel)
                        .disabled(isSubmitting)
                        .accessibilityLabel("회원정보 입력 취소")
                        .accessibilityIdentifier("nativeRegistration.cancel")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("입력 완료") { focusedField = nil }
                }
            }
            .fullScreenCover(item: $presentedPicker) { picker in
                switch picker {
                case .birthday:
                    NativeRegistrationBirthdayScreen(selection: draft.birthDate) { draft.birthDate = $0 }
                case .school, .university:
                    NativeRegistrationCatalogScreen(
                        kind: picker,
                        selectedSchoolCode: draft.schoolCode,
                        selectedUniversityCode: draft.universityCode,
                        onSchool: { region, code, name in
                            draft.schoolRegion = region
                            draft.schoolCode = code
                            draft.schoolName = code == "OVERSEAS_HIGH_SCHOOL" ? "" : name
                        },
                        onUniversity: { code, name in
                            draft.universityCode = code
                            draft.universityName = code == "OVERSEAS_UNIVERSITY" ? "" : name
                        })
                }
            }
        }
        .tint(Tokens.primary)
        .interactiveDismissDisabled()
        .accessibilityIdentifier("nativeRegistration.screen")
        .onAppear { hasExpired = hasExpired || context.isExpired }
        .onReceive(expiryTimer) { _ in
            if context.isExpired { hasExpired = true }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && context.isExpired { hasExpired = true }
        }
        .onDisappear {
            // Picking a school/birthday is a temporary presentation, not a cancel.
            // Only an in-flight submission needs teardown; root also guards the
            // authentication attempt before it can publish a returned session.
            if isSubmitting {
                submissionTask?.cancel()
                submissionTask = nil
                submissionID = nil
                isSubmitting = false
                serverError = "처리 결과를 확인하지 못했습니다. 다시 시도하면 같은 가입 요청의 결과를 확인합니다."
            }
        }
    }

    private func registrationForm(in viewport: CGSize) -> some View {
        // iPad reports a regular vertical size class in both orientations.
        // Use the actual available window dimensions so portrait and narrow
        // multitasking windows keep a single column, including on a 13-inch iPad.
        let wideLandscape = viewport.width >= 900 && viewport.width > viewport.height
        let usesTwoColumns = !dynamicTypeSize.isAccessibilitySize && (compactHeight || wideLandscape)
        let fieldsLayout = usesTwoColumns
            ? AnyLayout(HStackLayout(alignment: .top, spacing: Tokens.Space.s7))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: Tokens.Space.s6))

        return ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s6) {
                    authenticationSummary
                    if hasExpired { submissionStatus }
                    // AnyLayout preserves the existing input views and focus
                    // when rotation or window resizing changes the column count.
                    fieldsLayout {
                        identityFields.frame(maxWidth: .infinity, alignment: .topLeading)
                        VStack(alignment: .leading, spacing: Tokens.Space.s6) {
                            educationFields
                            consentFields
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .disabled(isSubmitting || hasExpired)
                    if !hasExpired { submissionStatus }
                    if !usesTwoColumns {
                        submitButton(scroll: scroll)
                    }
                }
                .frame(maxWidth: usesTwoColumns ? 960 : 600, alignment: .leading)
                .padding(.horizontal, Tokens.Space.s6)
                .padding(.vertical, compactHeight ? Tokens.Space.s3 : Tokens.Space.s6)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // Keep the action visible in both wide layouts. While typing,
                // give the available height back to the unchanged scroll view.
                if usesTwoColumns && focusedField == nil {
                    HStack(spacing: Tokens.Space.s4) {
                        Text(hasExpired
                             ? (reauthenticationReason ?? "인증 시간이 지났습니다. 다시 로그인해 주세요.")
                             : (isSubmitting ? "입력한 정보를 저장하고 있습니다." : "필수 정보를 확인한 뒤 가입을 완료해 주세요."))
                            .font(.mCaption)
                            .foregroundStyle(Tokens.text3)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: Tokens.Space.s2)
                        submitButton(scroll: scroll).frame(maxWidth: 300)
                    }
                    .frame(maxWidth: 960)
                    .padding(.horizontal, Tokens.Space.s6)
                    .padding(.vertical, Tokens.Space.s2)
                    .frame(maxWidth: .infinity)
                    .background(Tokens.surface)
                    .overlay(alignment: .top) { Divider().overlay(Tokens.line) }
                    .accessibilityElement(children: .contain)
                    .accessibilitySortPriority(-10)
                }
            }
        }
    }

    @ViewBuilder private var authenticationSummary: some View {
        if compactHeight {
            // A landscape phone needs the height for editable fields. Keep the
            // verified identity visible; move the explanatory labels to VoiceOver.
            HStack(alignment: .top, spacing: Tokens.Space.s3) {
                Label("\(providerName) 계정 확인 완료", systemImage: "checkmark.seal.fill")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.successInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHint("필수 회원정보를 확인하면 Matths를 시작할 수 있습니다.")
                    .accessibilityIdentifier("nativeRegistration.providerVerified")
                Spacer(minLength: Tokens.Space.s2)
                if let email = context.registration.email, !email.isEmpty {
                    Text(email)
                        .font(.mCaption)
                        .foregroundStyle(Tokens.text1)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("확인된 이메일, \(email)")
                        .accessibilityIdentifier("nativeRegistration.verifiedEmail")
                }
            }
            .accessibilityElement(children: .contain)
        } else {
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                Label("\(providerName) 계정 확인 완료", systemImage: "checkmark.seal.fill")
                    .font(.mBodyB)
                    .foregroundStyle(Tokens.successInk)
                    .accessibilityIdentifier("nativeRegistration.providerVerified")
                Text("필수 회원정보를 확인하면 Matths를 시작할 수 있습니다.")
                    .font(.mCallout)
                    .foregroundStyle(Tokens.text2)
                if let email = context.registration.email, !email.isEmpty {
                    VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                        Text("확인된 이메일").font(.mCaption).foregroundStyle(Tokens.text3)
                        Text(email)
                            .font(.mCallout)
                            .foregroundStyle(Tokens.text1)
                            .textSelection(.enabled)
                            .accessibilityIdentifier("nativeRegistration.verifiedEmail")
                    }
                    .padding(.top, Tokens.Space.s2)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var identityFields: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            SectionRule(title: "기본 정보 · 모두 필수")
            textField("실명", placeholder: "본인의 이름", text: $draft.realName,
                      field: .realName, contentType: .name)
                .submitLabel(.next)
                .onSubmit { focusedField = .name }
            textField("닉네임", placeholder: "2~30자", text: $draft.name,
                      field: .name, contentType: .nickname)
                .submitLabel(.done)
                .onSubmit { focusedField = nil }
            Text("닉네임은 GOAT Arena와 게시판에 표시됩니다.")
                .font(.mCaption).foregroundStyle(Tokens.text3)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                fieldLabel("생년월일")
                selectionButton(
                    title: birthdayLabel,
                    placeholder: draft.birthDate == nil,
                    identifier: "nativeRegistration.birthDate"
                ) { open(.birthday) }
                fieldIssue(.birthDate)
            }
            .id(NativeSocialRegistrationIssue.Field.birthDate)
        }
    }

    private var birthdayLabel: String {
        guard let birthday = draft.birthDate else { return "생년월일 선택" }
        let formatter = DateFormatter()
        formatter.calendar = NativeSocialRegistrationDraft.calendar
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일"
        return formatter.string(from: birthday)
    }

    private var educationFields: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            SectionRule(title: "학년 및 소속")
            VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                fieldLabel("학년 또는 현재 상태 (필수)")
                Picker("학년 또는 현재 상태", selection: $draft.schoolGrade) {
                    Text("선택해 주세요").tag(Int?.none)
                    Text("고1").tag(Int?.some(10))
                    Text("고2").tag(Int?.some(11))
                    Text("고3").tag(Int?.some(12))
                    Text("N수생").tag(Int?.some(13))
                    Text("대학생").tag(Int?.some(14))
                    Text("직장인").tag(Int?.some(15))
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, Tokens.Space.s2)
                .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.sm).strokeBorder(Tokens.lineStrong))
                .accessibilityIdentifier("nativeRegistration.schoolGrade")
                fieldIssue(.schoolGrade)
            }
            .id(NativeSocialRegistrationIssue.Field.schoolGrade)
            if draft.needsSchool {
                VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                    fieldLabel("고등학교 (필수)")
                    selectionButton(
                        title: draft.isOverseasSchool ? "해외 고등학교" : (draft.schoolName.isEmpty ? "고등학교 선택" : draft.schoolName),
                        placeholder: draft.schoolCode.isEmpty,
                        identifier: "nativeRegistration.school"
                    ) { open(.school) }
                    fieldIssue(.school)
                }
                .id(NativeSocialRegistrationIssue.Field.school)
                if draft.isOverseasSchool {
                    textField("해외 고등학교 이름 (필수)", placeholder: "재학 중인 학교의 정식 이름",
                              text: $draft.schoolName, field: .schoolName)
                }
            }
            if draft.needsUniversity {
                VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                    fieldLabel("대학교 (필수)")
                    selectionButton(
                        title: draft.isOverseasUniversity ? "해외 대학교" : (draft.universityName.isEmpty ? "대학교 선택" : draft.universityName),
                        placeholder: draft.universityCode.isEmpty,
                        identifier: "nativeRegistration.university"
                    ) { open(.university) }
                    fieldIssue(.university)
                }
                .id(NativeSocialRegistrationIssue.Field.university)
                if draft.isOverseasUniversity {
                    textField("해외 대학교 이름 (필수)", placeholder: "재학 중인 대학교의 정식 이름",
                              text: $draft.universityName, field: .universityName)
                }
            }
        }
    }

    private var consentFields: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            SectionRule(title: "필수 동의")
            consent("이용약관", path: "terms", isOn: $draft.termsAccepted, field: .terms)
            consent("개인정보 처리방침", path: "privacy", isOn: $draft.privacyAccepted, field: .privacy)
        }
    }

    private func consent(_ title: String, path: String, isOn: Binding<Bool>,
                         field: NativeSocialRegistrationIssue.Field) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Toggle(isOn: isOn) {
                Text("[필수] \(title) 동의")
                    .font(.mCallout).foregroundStyle(Tokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minHeight: 44)
            .accessibilityIdentifier("nativeRegistration.\(field.rawValue)")
            Link(destination: ServerAPI.baseURL.appendingPathComponent(path)) {
                Label("\(title) 전문 보기", systemImage: "arrow.up.right.square")
                    .font(.mCaption)
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .accessibilityHint("브라우저에서 문서를 엽니다. 입력한 정보는 유지됩니다.")
            .accessibilityIdentifier("nativeRegistration.\(field.rawValue).document")
            fieldIssue(field)
        }
        .id(field)
    }

    @ViewBuilder private var submissionStatus: some View {
        if hasExpired && !isSubmitting {
            Label(reauthenticationReason ?? "인증 시간이 만료되었습니다. 로그인 화면에서 \(providerName)로 다시 인증해 주세요.",
                  systemImage: reauthenticationReason == nil ? "clock.badge.exclamationmark" : "arrow.clockwise.circle")
                .font(.mCallout).foregroundStyle(Tokens.dangerInk)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(reauthenticationReason == nil
                                         ? "nativeRegistration.expired"
                                         : "nativeRegistration.reauthenticationRequired")
        } else if let serverError {
            Label(serverError, systemImage: "exclamationmark.circle")
                .font(.mCallout).foregroundStyle(Tokens.dangerInk)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("nativeRegistration.error")
        } else if showsValidation, let issue {
            Text(issue.message)
                .font(.mCaption).foregroundStyle(Tokens.dangerInk)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("nativeRegistration.validation")
        }
    }

    private func submitButton(scroll: ScrollViewProxy) -> some View {
        Button {
            if hasExpired {
                cancel()
            } else if let issue {
                showsValidation = true
                serverError = nil
                scroll.scrollTo(issue.field, anchor: .center)
                switch issue.field {
                case .realName, .name, .schoolName, .universityName:
                    focusedField = issue.field
                default: focusedField = nil
                }
            } else {
                submit()
            }
        } label: {
            HStack(spacing: Tokens.Space.s2) {
                if isSubmitting { ProgressView().tint(Tokens.actionForeground) }
                Text(isSubmitting ? "가입 완료 중…" : (hasExpired ? "로그인 화면으로 돌아가기" : "동의하고 시작하기"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Tokens.Space.s3)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(isSubmitting)
        .accessibilityIdentifier("nativeRegistration.submit")
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title).font(.mCaption).foregroundStyle(Tokens.text3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func textField(_ title: String, placeholder: String, text: Binding<String>,
                           field: NativeSocialRegistrationIssue.Field,
                           contentType: UITextContentType? = nil) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s1) {
            fieldLabel(title)
            TextField(placeholder, text: text)
                .font(.mBody)
                .textContentType(contentType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .frame(minHeight: 44)
                .focused($focusedField, equals: field)
                .accessibilityLabel(title)
                .accessibilityIdentifier("nativeRegistration.\(field.rawValue)")
            fieldIssue(field)
        }
        .id(field)
    }

    @ViewBuilder private func fieldIssue(_ field: NativeSocialRegistrationIssue.Field) -> some View {
        if showsValidation, let issue, issue.field == field {
            Text(issue.message)
                .font(.mCaption).foregroundStyle(Tokens.dangerInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func selectionButton(title: String, placeholder: Bool, identifier: String,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.s2) {
                Text(title)
                    .font(.mCallout)
                    .foregroundStyle(placeholder ? Tokens.text3 : Tokens.text1)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Tokens.Space.s2)
                Image(systemName: "chevron.right").font(.mCaption).foregroundStyle(Tokens.text3)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .buttonStyle(SecondaryButtonStyle())
        .accessibilityIdentifier(identifier)
    }

    private func open(_ picker: NativeRegistrationPicker) {
        guard !isSubmitting, !hasExpired else { return }
        focusedField = nil
        presentedPicker = picker
    }

    private func cancel() {
        guard !isSubmitting else { return }
        focusedField = nil
        submissionTask?.cancel()
        submissionTask = nil
        submissionID = nil
        onCancel()
    }

    private func submit() {
        guard !isSubmitting, draft.firstIssue() == nil,
              let birthDate = draft.birthDateString, let schoolGrade = draft.schoolGrade else { return }
        guard !context.isExpired else { hasExpired = true; return }
        focusedField = nil
        showsValidation = false
        serverError = nil
        isSubmitting = true
        let id = UUID()
        submissionID = id
        let profile = NativeSocialRegistrationProfile(
            realName: NativeSocialRegistrationDraft.normalizedRealName(draft.realName),
            name: NativeSocialRegistrationDraft.normalizedNickname(draft.name),
            birthDate: birthDate,
            schoolGrade: schoolGrade,
            schoolRegion: draft.needsSchool ? draft.schoolRegion : nil,
            schoolCode: draft.needsSchool ? draft.schoolCode : nil,
            schoolName: draft.needsSchool ? NativeSocialRegistrationDraft.normalizedInstitutionName(draft.schoolName) : nil,
            universityCode: draft.needsUniversity ? draft.universityCode : nil,
            universityName: draft.needsUniversity ? NativeSocialRegistrationDraft.normalizedInstitutionName(draft.universityName) : nil,
            termsAccepted: draft.termsAccepted,
            privacyAccepted: draft.privacyAccepted)
        submissionTask = Task { @MainActor in
            do {
                let auth = try await context.submit(profile: profile)
                guard !Task.isCancelled, submissionID == id else { return }
                submissionTask = nil
                onComplete(auth)
            } catch {
                guard !Task.isCancelled, submissionID == id else { return }
                submissionTask = nil
                submissionID = nil
                isSubmitting = false
                let apiError = error as? ServerAPIError
                switch apiError?.code {
                case "NATIVE_SOCIAL_POLICY_VERSION_MISMATCH":
                    reauthenticationReason = "약관이 변경되었습니다. 다시 로그인한 뒤 최신 내용을 확인해 주세요."
                    hasExpired = true
                case "NATIVE_SOCIAL_REGISTRATION_CONFLICT":
                    reauthenticationReason = "가입 처리가 완료된 인증입니다. 다시 로그인해 주세요."
                    hasExpired = true
                default:
                    if context.isExpired || [
                    "NATIVE_SOCIAL_REGISTRATION_EXPIRED",
                    "NATIVE_SOCIAL_REGISTRATION_INVALID",
                    "NATIVE_SOCIAL_REGISTRATION_CONSUMED",
                    "SOCIAL_AUTH_GRANT_EXPIRED", "SOCIAL_AUTH_GRANT_INVALID",
                    "SOCIAL_AUTH_CODE_INVALID"
                    ].contains(apiError?.code ?? "") {
                        hasExpired = true
                    } else {
                        serverError = apiError?.errorDescription
                            ?? "회원정보를 저장하지 못했습니다. 인터넷 연결을 확인하고 다시 시도해 주세요."
                    }
                }
            }
        }
    }
}

private enum NativeRegistrationPicker: String, Identifiable {
    case birthday, school, university
    var id: String { rawValue }
}

private struct NativeRegistrationBirthdayScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date
    let onPick: (Date) -> Void

    init(selection: Date?, onPick: @escaping (Date) -> Void) {
        _selectedDate = State(initialValue: selection ?? Date())
        self.onPick = onPick
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s5) {
                    Text("본인의 생년월일을 선택해 주세요.")
                        .font(.mBody).foregroundStyle(Tokens.text1)
                    DatePicker("생년월일", selection: $selectedDate,
                               in: NativeSocialRegistrationDraft.earliestBirthDate...Date(),
                               displayedComponents: .date)
                        .datePickerStyle(.wheel)
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                        .environment(\.calendar, NativeSocialRegistrationDraft.calendar)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("nativeRegistration.birthday.picker")
                    Button("선택한 날짜 사용") {
                        onPick(selectedDate)
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("nativeRegistration.birthday.confirm")
                }
                .frame(maxWidth: 560)
                .padding(Tokens.Space.s6)
                .frame(maxWidth: .infinity)
            }
            .background(Tokens.paper)
            .navigationTitle("생년월일")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
            }
        }
        .tint(Tokens.primary)
    }
}

private struct NativeRegistrationCatalogScreen: View {
    let kind: NativeRegistrationPicker
    let selectedSchoolCode: String
    let selectedUniversityCode: String
    let onSchool: (String, String, String) -> Void
    let onUniversity: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var regions: [String: [ServerAPI.APISchool]] = [:]
    @State private var universities: [ServerAPI.APIUniversity] = []
    @State private var selectedRegion = ""
    @State private var query = ""
    @State private var loading = true
    @State private var loadError: String?
    @State private var reloadID = UUID()

    private struct SchoolRow: Identifiable {
        let region: String
        let school: ServerAPI.APISchool
        var id: String { "\(region):\(school.code)" }
    }

    private var schoolRows: [SchoolRow] {
        regions.keys.sorted().filter { selectedRegion.isEmpty || $0 == selectedRegion }.flatMap { region in
            (regions[region] ?? [])
                .filter { $0.code != "OVERSEAS_HIGH_SCHOOL" && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)) }
                .map { SchoolRow(region: region, school: $0) }
        }
    }

    private var universityRows: [ServerAPI.APIUniversity] {
        universities.filter {
            $0.code != "OVERSEAS_UNIVERSITY" && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                overseasButton
                    .padding(.horizontal, Tokens.Space.s5)
                    .padding(.vertical, Tokens.Space.s2)
                if kind == .school && !regions.isEmpty {
                    Picker("지역", selection: $selectedRegion) {
                        Text("전국").tag("")
                        ForEach(regions.keys.sorted().filter { $0 != "해외" }, id: \.self) { region in
                            Text(region).tag(region)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.horizontal, Tokens.Space.s5)
                    .accessibilityIdentifier("nativeRegistration.catalog.region")
                }
                if loading {
                    ProgressView("학교 목록을 불러오는 중…")
                        .font(.mCallout).padding(Tokens.Space.s7)
                    Spacer()
                } else if let loadError {
                    ContentUnavailableView {
                        Label("목록을 불러오지 못했습니다", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(loadError)
                    } actions: {
                        Button("다시 불러오기") { reloadID = UUID() }
                            .buttonStyle(SecondaryButtonStyle())
                            .accessibilityIdentifier("nativeRegistration.catalog.retry")
                    }
                } else {
                    catalogList
                }
            }
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
            .background(Tokens.paper)
            .navigationTitle(kind == .school ? "고등학교 선택" : "대학교 선택")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: kind == .school ? "고등학교 이름 검색" : "대학교 이름 검색")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
            }
            .task(id: reloadID) { await load() }
        }
        .tint(Tokens.primary)
        .accessibilityIdentifier("nativeRegistration.catalog")
    }

    private var overseasButton: some View {
        Button {
            if kind == .school { onSchool("해외", "OVERSEAS_HIGH_SCHOOL", "") }
            else { onUniversity("OVERSEAS_UNIVERSITY", "") }
            dismiss()
        } label: {
            HStack {
                Label(kind == .school ? "해외 고등학교" : "해외 대학교", systemImage: "globe")
                Spacer()
                Text("이름 직접 입력").font(.mCaption).foregroundStyle(Tokens.text3)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(SecondaryButtonStyle())
        .accessibilityIdentifier("nativeRegistration.catalog.overseas")
    }

    @ViewBuilder private var catalogList: some View {
        if (kind == .school && schoolRows.isEmpty) || (kind == .university && universityRows.isEmpty) {
            ContentUnavailableView.search(text: query)
        } else {
            List {
                if kind == .school {
                    ForEach(schoolRows) { row in
                        Button {
                            onSchool(row.region, row.school.code, row.school.name)
                            dismiss()
                        } label: {
                            catalogRow(title: row.school.name,
                                       subtitle: [row.region, row.school.highSchoolType ?? ""].filter { !$0.isEmpty }.joined(separator: " · "),
                                       selected: selectedSchoolCode == row.school.code)
                        }
                        .accessibilityIdentifier("nativeRegistration.catalog.school.\(row.school.code)")
                    }
                } else {
                    ForEach(universityRows) { university in
                        Button {
                            onUniversity(university.code, university.name)
                            dismiss()
                        } label: {
                            catalogRow(title: university.name,
                                       subtitle: [university.region ?? "", university.campus ?? ""].filter { !$0.isEmpty }.joined(separator: " · "),
                                       selected: selectedUniversityCode == university.code)
                        }
                        .accessibilityIdentifier("nativeRegistration.catalog.university.\(university.code)")
                    }
                }
            }
            .listStyle(.plain)
            .scrollDismissesKeyboard(.immediately)
        }
    }

    private func catalogRow(title: String, subtitle: String, selected: Bool) -> some View {
        HStack(spacing: Tokens.Space.s3) {
            VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                Text(title).font(.mBody).foregroundStyle(Tokens.text1)
                    .fixedSize(horizontal: false, vertical: true)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.mCaption).foregroundStyle(Tokens.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Tokens.Space.s2)
            if selected { Image(systemName: "checkmark").foregroundStyle(Tokens.primary) }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @MainActor private func load() async {
        loading = true
        loadError = nil
        do {
            if kind == .school {
                let result = try await ServerAPI.schools()
                guard !Task.isCancelled else { return }
                regions = result
            } else {
                let result = try await ServerAPI.universities()
                guard !Task.isCancelled else { return }
                universities = result
            }
            loading = false
        } catch {
            guard !Task.isCancelled else { return }
            loadError = (error as? ServerAPIError)?.errorDescription
                ?? "인터넷 연결을 확인한 뒤 다시 불러와 주세요."
            loading = false
        }
    }
}
