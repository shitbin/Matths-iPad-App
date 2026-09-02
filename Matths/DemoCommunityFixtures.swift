import Foundation

/// 네트워크 계정 없이도 게시판의 읽기·작성·댓글·추천·신고·차단 흐름을
/// 실제 네이티브 화면에서 끝까지 검수할 수 있는 데모 응답이다.
enum DemoCommunityFixtures {
    private static let first = "demo-community-post-01"

    static let page = #"""
    {
      "schemaVersion":"COMMUNITY_NATIVE_V1",
      "board":{"id":"high-school","label":"통합 게시판","schoolAccessRestricted":false,"selectedSchool":null,"selectedUniversity":null},
      "query":{"search":"","sort":"latest","category":""},
      "operationsCategories":[{"value":"notice","label":"일반 공지"},{"value":"rules","label":"규칙"},{"value":"policies","label":"방침"},{"value":"manuals","label":"설명서"},{"value":"inquiry-rules","label":"문의 규칙"}],
      "posts":[
        {"id":"demo-community-notice-01","kind":"NOTICE","boardType":"high-school","boardCategory":"","boardCategoryLabel":"","title":"처음 이용하는 분을 위한 게시판 안내","contentPreview":"질문에는 풀이 과정과 막힌 지점을 함께 적어주세요.","authorName":"Matths 운영팀","anonymous":false,"pinned":true,"popular":false,"viewCount":142,"upvoteCount":18,"downvoteCount":0,"attachmentCount":0,"createdAt":"@T-2h@"},
        {"id":"demo-community-post-01","kind":"POST","boardType":"high-school","boardCategory":"","boardCategoryLabel":"","title":"미적분 공부 순서를 어떻게 잡아야 할까요?","contentPreview":"수열의 극한까지 끝냈는데 미분과 적분 중 어디부터 복습할지 고민입니다.","authorName":"익명","anonymous":true,"pinned":false,"popular":true,"viewCount":86,"upvoteCount":12,"downvoteCount":1,"attachmentCount":1,"createdAt":"@T-32m@"},
        {"id":"demo-community-post-02","kind":"POST","boardType":"high-school","boardCategory":"","boardCategoryLabel":"","title":"오늘 모의고사 21번 풀이 공유합니다","contentPreview":"치환 뒤 증가·감소 표를 만들면 계산을 많이 줄일 수 있었습니다.","authorName":"수학좋아","anonymous":false,"pinned":false,"popular":false,"viewCount":44,"upvoteCount":7,"downvoteCount":0,"attachmentCount":0,"createdAt":"@T-12m@"}
      ],
      "popularPosts":[{"id":"demo-community-post-01","kind":"POST","boardType":"high-school","boardCategory":"","boardCategoryLabel":"","title":"미적분 공부 순서를 어떻게 잡아야 할까요?","contentPreview":"수열의 극한까지 끝냈는데 복습 순서가 고민입니다.","authorName":"익명","anonymous":true,"pinned":false,"popular":true,"viewCount":86,"upvoteCount":112,"downvoteCount":1,"attachmentCount":1,"createdAt":"@T-32m@"}],
      "pagination":{"page":1,"totalPages":1,"total":3,"hasPrevious":false,"hasNext":false},
      "signedIn":true
    }
    """#

    static let postingAccess = #"{"schemaVersion":"COMMUNITY_NATIVE_V1","access":{"warningCount":0,"canUploadFiles":true,"dailyLimit":5,"postsCreatedToday":1,"remainingPosts":4}}"#
    static let blocks = #"{"schemaVersion":"COMMUNITY_NATIVE_V1","blocks":[{"id":"demo-blocked-user-01","displayName":"익명 사용자","anonymous":true,"sourceType":"comment","createdAt":"@T-1d@"}]}"#
    static let createdPost = #"{"schemaVersion":"COMMUNITY_NATIVE_V1","post":{"id":"demo-community-created","kind":"POST","boardType":"high-school","boardCategory":"","boardCategoryLabel":"","title":"새로 등록한 게시글","contentPreview":"데모에서 등록한 게시글입니다.","authorName":"데모 학생","anonymous":false,"pinned":false,"popular":false,"viewCount":0,"upvoteCount":0,"downvoteCount":0,"attachmentCount":0,"createdAt":"@T+0s@","content":"데모에서 등록한 게시글입니다.","attachments":[],"canDelete":true,"canBlock":false}}"#
    static let comment = #"{"schemaVersion":"COMMUNITY_NATIVE_V1","comment":{"id":"demo-comment-created","authorName":"데모 학생","anonymous":false,"content":"도움이 됐어요. 감사합니다!","createdAt":"@T+0s@","canBlock":false}}"#
    static let vote = #"{"schemaVersion":"COMMUNITY_NATIVE_V1","vote":{"upvoteCount":13,"downvoteCount":1,"voteScore":12,"viewerVote":1}}"#
    static let reported = #"{"schemaVersion":"COMMUNITY_NATIVE_V1","reported":true}"#
    static let blocked = #"{"schemaVersion":"COMMUNITY_NATIVE_V1","blocked":true}"#
    static let deleted = #"{"schemaVersion":"COMMUNITY_NATIVE_V1","deleted":true}"#
    static let unblocked = #"{"schemaVersion":"COMMUNITY_NATIVE_V1","unblocked":true}"#

    static func detail(id: String, kind: String = "POST") -> String {
        let postID = id.isEmpty ? first : id
        let isPost = kind == "POST"
        let title = kind == "NOTICE" ? "처음 이용하는 분을 위한 게시판 안내" :
            (kind == "ANNOUNCEMENT" ? "서비스 운영 공지" : "미적분 공부 순서를 어떻게 잡아야 할까요?")
        let body = isPost
            ? "수열의 극한까지 끝냈는데 미분과 적분 중 어디부터 복습할지 고민입니다. 개념과 기출을 병행하는 순서도 궁금합니다."
            : "안전하고 도움이 되는 게시판을 위해 개인정보를 적지 말고 서로 존중하는 표현을 사용해주세요."
        let attachments: [[String: Any]] = isPost ? [[
            "id": "demo-community-file-01",
            "originalName": "미적분-학습순서.pdf",
            "mimeType": "application/pdf",
            "sizeBytes": 48_210,
            "isImage": false,
            "downloadPath": "/api/v1/community/posts/\(postID)/attachments/demo-community-file-01",
        ]] : []
        let comments: [[String: Any]] = isPost ? [[
            "id": "demo-community-comment-01",
            "authorName": "개념먼저",
            "anonymous": false,
            "content": "미분 개념을 먼저 잡고 미분 활용까지 간 뒤 적분으로 넘어가면 연결이 자연스러웠어요.",
            "createdAt": "@T-18m@",
            "canBlock": true,
        ]] : []
        let value: [String: Any] = [
            "schemaVersion": "COMMUNITY_NATIVE_V1",
            "post": [
                "id": postID, "kind": kind, "boardType": "high-school",
                "boardCategory": "", "boardCategoryLabel": "", "title": title,
                "contentPreview": body, "authorName": isPost ? "익명" : "Matths 운영팀",
                "anonymous": isPost, "pinned": !isPost, "popular": isPost,
                "viewCount": 87, "upvoteCount": 12, "downvoteCount": 1,
                "attachmentCount": isPost ? 1 : 0, "createdAt": "@T-32m@",
                "content": body, "attachments": attachments,
                "canDelete": false, "canBlock": isPost,
            ],
            "comments": comments, "viewerVote": 0, "viewerReported": false,
            "signedIn": true,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: value),
              let result = String(data: data, encoding: .utf8) else {
            return #"{"schemaVersion":"COMMUNITY_NATIVE_V1","post":{},"comments":[],"viewerVote":0,"viewerReported":false,"signedIn":true}"#
        }
        return result
    }
}
