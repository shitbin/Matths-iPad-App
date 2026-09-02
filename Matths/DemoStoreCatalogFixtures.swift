#if DEBUG
import Foundation

enum DemoStoreCatalogFixtures {
    static let catalog = #"""
    {
      "schemaVersion":"STORE_CATALOG_NATIVE_V1",
      "catalog":{
        "products":[\#(product)],
        "query":"","sort":"popular","category":"",
        "categories":[
          {"id":"demo-category-1","name":"N제","slug":"n-je","sortOrder":0,"isVisible":true},
          {"id":"demo-category-2","name":"모의고사","slug":"mock","sortOrder":1,"isVisible":true}
        ]
      }
    }
    """#

    static let detail = #"""
    {
      "schemaVersion":"STORE_CATALOG_NATIVE_V1",
      "product":\#(product),
      "categories":[
        {"id":"demo-category-1","name":"N제","slug":"n-je","sortOrder":0,"isVisible":true},
        {"id":"demo-category-2","name":"모의고사","slug":"mock","sortOrder":1,"isVisible":true}
      ]
    }
    """#

    private static let product = #"""
    {
      "id":"demo-product-01","name":"미적분 핵심 유형 미리보기","slug":"demo-calculus-preview",
      "category":"N제","badge":"무료 공개 자료","subtitle":"고3 미적분 빈출 유형 12선",
      "summary":"정답과 해설이 포함된 맛보기 PDF를 바로 내려받아 학습할 수 있습니다.",
      "price":0,"originalPrice":0,
      "bundleItems":[
        {"name":"문제 12문항","description":"수능 빈출 미적분 유형을 짧게 점검합니다."},
        {"name":"정답과 해설","description":"핵심 발상과 실수 지점을 함께 정리했습니다."}
      ],
      "thumbnail":{"id":"demo-store-thumb","kind":"THUMBNAIL","originalName":"미적분-미리보기.png","mimeType":"image/png","sizeBytes":182400,"altText":"미적분 핵심 유형 표지","downloadCount":0},
      "assets":[
        {"id":"demo-store-thumb","kind":"THUMBNAIL","originalName":"미적분-미리보기.png","mimeType":"image/png","sizeBytes":182400,"altText":"미적분 핵심 유형 표지","downloadCount":0},
        {"id":"demo-store-detail","kind":"DETAIL_IMAGE","originalName":"미적분-상세.png","mimeType":"image/png","sizeBytes":241300,"altText":"자료 구성 안내","downloadCount":0}
      ],
      "detailBlocks":[
        {"id":"demo-block-1","type":"TEXT","text":"처음부터 어려운 문제만 붙잡지 말고, 자주 나오는 조건을 먼저 읽는 연습을 하세요.","fontSize":"large","color":"#111827","bold":true,"underline":false,"align":"left","assetId":null,"caption":""},
        {"id":"demo-block-2","type":"IMAGE","text":"","fontSize":"normal","color":"#e9edf3","bold":false,"underline":false,"align":"center","assetId":"demo-store-detail","caption":"12문항 학습 구성"}
      ],
      "status":"PUBLISHED","viewCount":124,"salesCount":0,"freeDownloadCount":31,"popularityScore":92,
      "freeDownloadFiles":[
        {"id":"demo-store-pdf","kind":"PRODUCT_FILE","originalName":"미적분-핵심유형-미리보기.pdf","mimeType":"application/pdf","sizeBytes":831220,"altText":"","downloadCount":31}
      ],
      "createdAt":"@T-14d@","updatedAt":"@T-1d@","publishedAt":"@T-7d@"
    }
    """#
}
#endif
