#if DEBUG
import Foundation

enum DemoStudyHallFixtures {
    static func list(
        tab requestedTab: String = "NJE",
        empty: Bool = false,
        status: String = "IN_PROGRESS"
    ) -> String {
        let tab = ["NJE", "DAILY_HALF", "PRACTICE_MOCK", "FINAL", "CONCEPT", "ERROR_REPORT"]
            .contains(requestedTab) ? requestedTab : "NJE"
        let hasDemoItems = tab == "NJE" && !empty
        let continuingJSON = hasDemoItems && status != "SUBMITTED"
            ? contentObject(status: status) : "null"
        let itemsJSON = hasDemoItems
            ? "[\(contentObject(status: status)),\(secondContentObject)]"
            : "[]"
        return #"""
    {
      "schemaVersion":"STUDY_HALL_NATIVE_V1",
      "hall":{
        "tabs":[
          {"code":"NJE","label":"자체제작 N제","summary":"시리즈별 문제집을 플랫폼에서 바로 풉니다."},
          {"code":"DAILY_HALF","label":"데일리 하프","summary":"공개된 15문항 회차를 원하는 시간에 응시합니다."},
          {"code":"PRACTICE_MOCK","label":"실전 모의고사","summary":"시기와 시리즈에 맞춘 실전 훈련입니다."},
          {"code":"FINAL","label":"수능 파이널","summary":"수능 직전 목적별 압축 콘텐츠입니다."},
          {"code":"CONCEPT","label":"개념 학습","summary":"고3 수능 개념을 짧고 정확하게 정리합니다."},
          {"code":"ERROR_REPORT","label":"오답 유형 리포트","summary":"대표 오답 원인과 교정법입니다."}
        ],
        "activeTab":"\#(tab)",
        "items":\#(itemsJSON),
        "continuing":\#(continuingJSON)
      }
    }
    """#
    }

    static func detail(status: String = "IN_PROGRESS") -> String {
        #"{"schemaVersion":"STUDY_HALL_NATIVE_V1","content":\#(contentObject(status: status))}"#
    }

    private static func contentObject(status: String) -> String {
        let submitted = status == "SUBMITTED"
        return #"""
        {
          "id":"demo-study-01","contentType":"NJE","tabLabel":"자체제작 N제",
          "series":"킬러 정복 01","title":"미적분 실전 3문항","description":"도함수와 정적분의 핵심 조건을 짧게 점검합니다.",
          "grade":"고3","subject":"미적분","itemCount":3,"difficulty":"중상","timeLimitMinutes":18,
          "recommendedStudyDays":1,"estimatedMinutes":25,"year":2026,"month":9,"week":1,"session":1,
          "phase":"","finalCategory":"","errorCategory":"","commonMistake":"","wrongApproach":"","correctApproach":"","relatedProblem":"",
          "questions":[
            {"id":"demo-q-01","number":1,"stem":"함수 f(x)=x³-3x²+4의 극댓값을 고르세요.","choices":["0","2","4","6","8"],"answerType":"multiple-choice","points":3\#(resultFields(submitted: submitted, answer: "3", explanation: "도함수의 부호 변화를 확인하면 x=0에서 극댓값 4를 갖습니다.", correct: true))},
            {"id":"demo-q-02","number":2,"stem":"정적분 ∫₀¹(3x²+2x)dx의 값을 입력하세요.","choices":[],"answerType":"short-answer","points":4\#(resultFields(submitted: submitted, answer: "2", explanation: "원시함수 x³+x²에 0과 1을 대입합니다.", correct: false))},
            {"id":"demo-q-03","number":3,"stem":"lim(x→0) sin(5x)/(3x)의 값을 고르세요.","choices":["0","3/5","1","5/3","5"],"answerType":"multiple-choice","points":3\#(resultFields(submitted: submitted, answer: "4", explanation: "sin(5x)/(5x)→1이므로 5/3입니다.", correct: true))}
          ],
          "assets":[
            {"id":"demo-question-pdf","kind":"QUESTION_PDF","originalName":"미적분-실전-문제지.pdf","mimeType":"application/pdf","sizeBytes":284120,"downloadCount":12},
            {"id":"demo-solution-pdf","kind":"SOLUTION_PDF","originalName":"미적분-실전-해설.pdf","mimeType":"application/pdf","sizeBytes":391220,"downloadCount":8}
          ],
          "thumbnail":null,
          "questionPdf":{"id":"demo-question-pdf","kind":"QUESTION_PDF","originalName":"미적분-실전-문제지.pdf","mimeType":"application/pdf","sizeBytes":284120,"downloadCount":12},
          "solutionPdf":{"id":"demo-solution-pdf","kind":"SOLUTION_PDF","originalName":"미적분-실전-해설.pdf","mimeType":"application/pdf","sizeBytes":391220,"downloadCount":8},
          "contentFiles":[],"status":"PUBLISHED","sortOrder":1,"publishAt":"@T-7d@","createdAt":"@T-14d@","updatedAt":"@T-1d@",
          "progress":{"status":"\#(status)","lastQuestionNumber":2,"answeredCount":2,"correctCount":\#(submitted ? 2 : 0),"scorePoints":\#(submitted ? 6 : 0),"totalPoints":10,"scorePercent":\#(submitted ? 60 : 0),"percent":\#(submitted ? 100 : 67),"answers":[{"number":1,"answer":"3"},{"number":2,"answer":"1"}],"submittedAt":\#(submitted ? "\"@T+0s@\"" : "null")}
        }
        """#
    }

    private static func resultFields(
        submitted: Bool, answer: String, explanation: String, correct: Bool
    ) -> String {
        guard submitted else { return "" }
        return ",\"correctAnswer\":\"\(answer)\",\"explanation\":\"\(explanation)\",\"isCorrect\":\(correct)"
    }

    private static let secondContentObject = #"""
    {
      "id":"demo-study-02","contentType":"NJE","tabLabel":"자체제작 N제","series":"기본기 점검",
      "title":"수열 빈출 유형","description":"등차·등비수열의 기본 조건을 점검합니다.","grade":"고2","subject":"수학Ⅰ",
      "itemCount":10,"difficulty":"중","timeLimitMinutes":25,"recommendedStudyDays":2,"estimatedMinutes":35,
      "year":2026,"month":9,"week":1,"session":2,"phase":"","finalCategory":"","errorCategory":"",
      "commonMistake":"","wrongApproach":"","correctApproach":"","relatedProblem":"","questions":[],"assets":[],
      "thumbnail":null,"questionPdf":null,"solutionPdf":null,"contentFiles":[],"status":"PUBLISHED","sortOrder":2,
      "publishAt":"@T-5d@","createdAt":"@T-10d@","updatedAt":"@T-2d@",
      "progress":{"status":"NOT_STARTED","lastQuestionNumber":0,"answeredCount":0,"correctCount":0,"scorePoints":0,"totalPoints":0,"scorePercent":0,"percent":0,"answers":[],"submittedAt":null}
    }
    """#
}
#endif
