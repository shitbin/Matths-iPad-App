import SwiftUI

/// Selecting practice material must not enter a timed session without an exam.
struct KiceLibrarySheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                if KiceBank.exams.isEmpty {
                    Text("현재 기기에서 열 수 있는 기출 자료가 없습니다.")
                } else {
                    Section {
                        Text("시험지를 고른 뒤 응시 화면으로 이동합니다. 수능 형식의 기출은 30문항·100분으로 구성됩니다.")
                            .font(.mCaption).foregroundStyle(Tokens.text2)
                        ForEach(KiceBank.exams) { exam in
                            Button {
                                store.startKice(exam)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(exam.title).font(.mBodyB)
                                    Text("\(exam.heldOn) · \(exam.form)").font(.mCaption)
                                }
                            }
                            .disabled(KiceBank.pdfURL(for: exam) == nil)
                        }
                    }
                    if KiceBank.exams.allSatisfy({ KiceBank.pdfURL(for: $0) == nil }) {
                        Text("등록된 시험지 파일을 아직 사용할 수 없습니다.")
                            .font(.mCaption)
                    }
                }
            }
            .navigationTitle("기출 연습")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
}
