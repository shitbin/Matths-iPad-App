#if DEBUG
import Foundation

enum DemoFaqFixtures {
    static let dashboard = #"""
    {
      "schemaVersion":"FAQ_NATIVE_V1",
      "faq":{
        "query":"","category":"","code":"","totalCount":57,"resultCount":5,
        "categories":[
          {"value":"service","label":"서비스","count":5},
          {"value":"learning","label":"학습","count":6},
          {"value":"usage","label":"이용","count":6},
          {"value":"arena","label":"GOAT Arena","count":23},
          {"value":"error","label":"오류 코드","count":13}
        ],
        "items":[
          {"id":"faq-start","category":"service","categoryLabel":"서비스","ordinal":"01","question":"Matths를 처음 시작하면 무엇부터 해야 하나요?","answer":"홈의 오늘 할 일에서 진단 문제를 먼저 풀어보세요. 결과를 바탕으로 추천 학습과 복습 항목이 정리됩니다.\n\n학원에 소속되어 있다면 학원 화면에서 가입 코드를 입력한 뒤 수업 일정과 과제를 확인할 수 있습니다.","searchText":"처음 시작 진단 홈 학원 가입"},
          {"id":"faq-visual-learning","category":"learning","categoryLabel":"학습","ordinal":"08","question":"시각화 학습은 어떻게 사용하나요?","answer":"개념 지도를 열고 학습할 단원을 선택하세요. 개념 설명과 움직이는 수학판을 함께 보면서 핵심 관계를 확인할 수 있습니다.\n\n설명 뒤 바로 한 문항을 풀어 이해한 내용을 점검하세요.","searchText":"시각화 학습 개념 지도"},
          {"id":"faq-attendance","category":"usage","categoryLabel":"이용","ordinal":"15","question":"학원 출석 코드는 어디에 입력하나요?","answer":"학원 화면의 오늘 수업에서 출석 체크를 누른 뒤 선생님이 안내한 코드를 입력하세요. 출석 가능 시간 전이나 마감 뒤에는 선생님에게 수동 보정을 요청해야 합니다.","searchText":"학원 출석 코드 지각"},
          {"id":"faq-arena","category":"arena","categoryLabel":"GOAT Arena","ordinal":"27","question":"GOAT Arena 대전은 어떻게 시작하나요?","answer":"GOAT Arena에서 참가 가능한 매치를 고르고 안내되는 조건을 확인하세요. 제출 전에 답안과 제한 시간을 다시 확인하는 것이 좋습니다.","searchText":"아레나 대전 참가 매치"},
          {"id":"faq-error-409","category":"error","categoryLabel":"오류 코드","ordinal":"409","question":"409 오류는 무엇인가요?","answer":"요청 충돌 — 현재 서버 상태와 요청한 변경이 맞지 않을 때 표시됩니다.\n\n화면을 새로 불러온 뒤 다시 시도하세요. 계속되면 발생 시각, 화면 주소와 HTTP_409를 문의에 함께 적어주세요.","searchText":"오류 에러 코드 error 409 HTTP_409"}
        ]
      }
    }
    """#

    static let error409 = #"""
    {
      "schemaVersion":"FAQ_NATIVE_V1",
      "faq":{
        "query":"","category":"","code":"409","totalCount":57,"resultCount":1,
        "categories":[
          {"value":"service","label":"서비스","count":5},
          {"value":"learning","label":"학습","count":6},
          {"value":"usage","label":"이용","count":6},
          {"value":"arena","label":"GOAT Arena","count":23},
          {"value":"error","label":"오류 코드","count":13}
        ],
        "items":[
          {"id":"faq-error-409","category":"error","categoryLabel":"오류 코드","ordinal":"409","question":"409 오류는 무엇인가요?","answer":"요청 충돌 — 현재 서버 상태와 요청한 변경이 맞지 않을 때 표시됩니다.\n\n화면을 새로 불러온 뒤 다시 시도하세요. 계속되면 발생 시각, 화면 주소와 HTTP_409를 문의에 함께 적어주세요.","searchText":"오류 에러 코드 error 409 HTTP_409"}
        ]
      }
    }
    """#
}
#endif
