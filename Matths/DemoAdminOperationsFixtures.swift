import Foundation

enum DemoAdminOperationsFixtures {
    static let dashboard = #"""
    {
      "schemaVersion":"ADMIN_OPERATIONS_NATIVE_V1",
      "operations":{
        "stats":{"activeUsers":182,"activeParents":74,"pendingInquiries":2,"publishedAnnouncements":6,"archiveItems":39,"archiveFolders":8,"pendingAcademies":1},
        "pendingTodoCount":3,
        "priorityTodos":[
          {"id":"demo-todo-1","category":"inquiry","title":"결제 문의 확인","description":"29일권 결제 내역을 확인하고 답변해주세요.","href":"/admin/inquiries/demo-inquiry-1","status":"pending","createdAt":"2026-09-02T06:20:00.000Z","completedAt":null,"actor":{"id":"demo-user-1","name":"김민준","email":"student@example.com"},"target":null,"completedBy":null}
        ],
        "recentInquiries":[
          {"id":"demo-inquiry-1","subject":"29일권 결제 확인 부탁드립니다","content":"결제는 완료됐는데 이용권이 보이지 않습니다.","status":"pending","inquiryType":"payment","contactEmail":"student@example.com","createdAt":"2026-09-02T06:20:00.000Z","adminReply":null}
        ]
      }
    }
    """#

    static func todos(status: String, category: String) -> String {
        let completed = status == "completed"
        let visibleCategory = category.isEmpty ? "inquiry" : category
        return #"""
        {
          "schemaVersion":"ADMIN_OPERATIONS_NATIVE_V1",
          "todos":{
            "items":[{
              "id":"demo-todo-1","category":"\#(visibleCategory)","title":"결제 문의 확인",
              "description":"29일권 결제 내역을 확인하고 답변해주세요.","href":"/admin/inquiries/demo-inquiry-1",
              "status":"\#(completed ? "completed" : "pending")","createdAt":"2026-09-02T06:20:00.000Z",
              "completedAt":\#(completed ? "\"2026-09-02T07:30:00.000Z\"" : "null"),
              "actor":{"id":"demo-user-1","name":"김민준","email":"student@example.com"},"target":null,"completedBy":null
            }],
            "filter":{"category":"\#(category)","status":"\#(status)","dateFrom":"","dateTo":"","nickname":""},
            "pagination":{"page":1,"total":1,"totalPages":1,"hasPrevious":false,"hasNext":false}
          }
        }
        """#
    }

    static func inquiries(status: String) -> String {
        let effectiveStatus = status == "all" ? "pending" : status
        return #"""
        {
          "schemaVersion":"ADMIN_OPERATIONS_NATIVE_V1",
          "inquiries":{
            "items":[{
              "id":"demo-inquiry-1","subject":"29일권 결제 확인 부탁드립니다",
              "content":"결제는 완료됐는데 이용권이 보이지 않습니다.","status":"\#(effectiveStatus)",
              "inquiryType":"payment","contactEmail":"student@example.com",
              "createdAt":"2026-09-02T06:20:00.000Z","adminReply":null
            }],
            "filter":{"status":"\#(status)"},
            "pagination":{"page":1,"total":1,"totalPages":1,"hasPrevious":false,"hasNext":false}
          }
        }
        """#
    }

    static let mutation = #"{"schemaVersion":"ADMIN_OPERATIONS_NATIVE_V1","ok":true}"#
    static let delivered = #"{"schemaVersion":"ADMIN_OPERATIONS_NATIVE_V1","ok":true,"delivered":true}"#
    static let announcements = #"""
    {
      "schemaVersion":"ADMIN_OPERATIONS_NATIVE_V1",
      "announcements":{"status":"all","items":[{
        "id":"demo-announcement-1","title":"[2026.09.02] - 서비스 운영 안내",
        "content":"오늘 등록된 공지입니다. 사용자 알림함 배달 상태까지 확인할 수 있습니다.",
        "boardCategory":"notice","href":"/community/operations/demo-announcement-1",
        "isPublished":true,"createdAt":"2026-09-02T04:00:00.000Z",
        "publishedAt":"2026-09-02T04:00:00.000Z","dashboardEndsAt":null,
        "deliveredAt":"2026-09-02T04:01:00.000Z"
      }]}
    }
    """#
    static let createdAnnouncement = #"""
    {
      "schemaVersion":"ADMIN_OPERATIONS_NATIVE_V1",
      "announcement":{"id":"demo-announcement-new","title":"새 공지","content":"새 공지 내용입니다.",
      "boardCategory":"notice","href":"/community/operations/demo-announcement-new","isPublished":false,
      "createdAt":"2026-09-02T08:00:00.000Z","publishedAt":null,"dashboardEndsAt":null,"deliveredAt":null}
    }
    """#
}
