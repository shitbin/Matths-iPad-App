//  StudentSolutionAnalysisFloatingCard.swift
//  Matths
//
//  오답 직후 온디바이스 이미지 검토가 진행되는 동안, 방금 학생이 쓴 풀이를
//  결과 화면 위에 잠시 보존해 보여 준다. 검토 판정·채점·오답 기록은 바꾸지 않는다.

import SwiftUI
import UIKit

struct StudentSolutionAnalysisFloatingCard: View {
    let record: CheatingReviewRecord

    @State private var solutionImage: UIImage?
    @State private var showExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            HStack(spacing: Tokens.Space.s2) {
                ZStack {
                    Circle().fill(Tokens.primarySoft)
                    ProgressView().controlSize(.small)
                }
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("내 풀이를 읽는 중")
                        .font(.mCaption)
                        .foregroundStyle(Tokens.ink)
                    Text("방금 쓴 식을 보면서 잠시 기다려 주세요.")
                        .font(.mMicro)
                        .foregroundStyle(Tokens.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let solutionImage {
                Button {
                    showExpanded = true
                } label: {
                    Image(uiImage: solutionImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 150)
                        .padding(8)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
                        .overlay(alignment: .bottomTrailing) {
                            Label("크게 보기", systemImage: "arrow.up.left.and.arrow.down.right")
                                .font(.mMicro)
                                .foregroundStyle(Tokens.text2)
                                .padding(.horizontal, 8)
                                .frame(minHeight: 30)
                                .background(.ultraThinMaterial, in: Capsule())
                                .padding(6)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("방금 작성한 풀이 크게 보기")
                .accessibilityHint("분석 중인 내 풀이 이미지를 크게 엽니다")
            } else {
                Text("풀이 이미지를 안전하게 불러오는 중입니다.")
                    .font(.mMicro)
                    .foregroundStyle(Tokens.text3)
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .center)
            }

            Text("이미지 분석은 이 기기 안에서 진행됩니다.")
                .font(.mMicro)
                .foregroundStyle(Tokens.text4)
        }
        .padding(Tokens.Space.s4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.lg)
                .strokeBorder(Tokens.lineStrong.opacity(0.65), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.14), radius: 18, y: 8)
        .task(id: record.id) {
            solutionImage = CheatingReviewDisk.imageURL(for: record)
                .flatMap { UIImage(contentsOfFile: $0.path) }
        }
        .compactHeightSheet(isPresented: $showExpanded) {
            NavigationStack {
                Group {
                    if let solutionImage {
                        ScrollView([.horizontal, .vertical]) {
                            Image(uiImage: solutionImage)
                                .resizable()
                                .scaledToFit()
                                .padding(Tokens.Space.s5)
                        }
                        .background(Tokens.paper)
                    } else {
                        ContentUnavailableView(
                            "풀이를 불러오지 못했습니다",
                            systemImage: "pencil.and.scribble",
                            description: Text("결과 화면으로 돌아가 다시 확인해 주세요."))
                    }
                }
                .navigationTitle("방금 작성한 풀이")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("닫기") { showExpanded = false }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("내 풀이 이미지 분석 중")
    }
}
