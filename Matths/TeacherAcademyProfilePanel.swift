import SwiftUI

/// 학원 대표 사진은 학생·교사 목록 전반에서 학원을 구분하는 공용 자산이므로
/// 웹과 동일하게 원장만 변경할 수 있다. 업로드 원본은 서버에서 다시 검증·변환한다.
struct TeacherAcademyProfilePanel: View {
    let dashboard: ServerAPI.TeacherAcademyDashboard
    @ObservedObject var model: TeacherAcademyScreenModel
    let onChoosePhoto: () -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var confirmsRemoval = false

    private var compactLandscape: Bool {
        verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        ScrollView {
            Group {
                if compactLandscape {
                    HStack(alignment: .top, spacing: Tokens.Space.s4) {
                        preview.frame(width: 220)
                        controls
                    }
                } else {
                    VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                        preview
                        controls
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(compactLandscape ? Tokens.Space.s3 : Tokens.Space.s4)
        }
        .confirmationDialog(
            "학원 대표 사진을 기본 이미지로 되돌릴까요?",
            isPresented: $confirmsRemoval,
            titleVisibility: .visible
        ) {
            Button("대표 사진 삭제", role: .destructive) {
                Task { await model.removeAcademyProfileImage() }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("학생과 선생님 화면에는 학원 이름의 첫 글자가 대신 표시됩니다.")
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            academyImage
            Text(dashboard.academy.name)
                .font(.mBodyB).foregroundStyle(Tokens.ink).lineLimit(2)
            Text("현재 대표 이미지")
                .font(.mMicro).foregroundStyle(Tokens.text3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.s3)
        .background(Tokens.primarySoft,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
    }

    @ViewBuilder
    private var academyImage: some View {
        if let rawURL = dashboard.academy.profileImageURL,
           let url = URL(string: rawURL) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else if phase.error != nil {
                    fallbackImage
                } else {
                    ZStack { Tokens.paper2; ProgressView().tint(Tokens.primary) }
                }
            }
            .frame(width: 112, height: 112)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
            .accessibilityLabel("현재 학원 대표 사진")
        } else {
            fallbackImage
        }
    }

    private var fallbackImage: some View {
        Text(dashboard.academy.name.first.map(String.init) ?? "학")
            .font(.system(size: 42, weight: .bold, design: .rounded))
            .foregroundStyle(Tokens.onBrand)
            .frame(width: 112, height: 112)
            .background(Tokens.actionPrimary,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
            .accessibilityLabel("기본 학원 이미지")
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            VStack(alignment: .leading, spacing: 4) {
                Text("학원 대표 사진").font(.mHeading).foregroundStyle(Tokens.ink)
                Text("학생과 선생님이 목록에서 학원을 빠르게 구분할 수 있도록 정사각형 사진을 등록해 주세요.")
                    .font(.mCaption).foregroundStyle(Tokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(action: onChoosePhoto) {
                Label("사진 선택 및 자르기", systemImage: "photo.badge.plus")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(model.actionID != nil)
            if dashboard.academy.profileImageURL != nil {
                Button("기본 이미지로 되돌리기", role: .destructive) {
                    confirmsRemoval = true
                }
                .buttonStyle(.bordered).tint(Tokens.dangerInk).frame(minHeight: 44)
                .disabled(model.actionID != nil)
            }
            Label("JPG · PNG · WEBP, 최대 5MB", systemImage: "checkmark.shield")
                .font(.mCaption).foregroundStyle(Tokens.text2)
            Text("앱에서 1:1로 자른 뒤 서버가 파일 내용과 크기를 다시 검사하고 512×512 WEBP로 변환합니다. 일반 선생님은 대표 사진을 변경할 수 없습니다.")
                .font(.mMicro).foregroundStyle(Tokens.text3)
                .fixedSize(horizontal: false, vertical: true)
            if let notice = model.noticeMessage {
                Label(notice, systemImage: "checkmark.circle.fill")
                    .font(.mCaption).foregroundStyle(Tokens.successInk)
            }
            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.mCaption).foregroundStyle(Tokens.dangerInk)
            }
        }
        .padding(Tokens.Space.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.paper,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .strokeBorder(Tokens.line, lineWidth: 1)
        }
    }
}
