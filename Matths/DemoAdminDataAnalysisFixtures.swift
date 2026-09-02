#if DEBUG
  import Foundation

  enum DemoAdminDataAnalysisFixtures {
    static let dashboard =
      #"{"schemaVersion":"ADMIN_DATA_ANALYSIS_NATIVE_V1","analysis":{"period":{"periodKey":"2026-09","label":"2026년 9월"},"periodOptions":[{"key":"2026-09","label":"2026년 9월"},{"key":"2026-08","label":"2026년 8월"}],"generatedAt":"2026-09-02T10:00:00.000Z","periodClosed":false,"summary":{"catalogMetricCount":24,"observedMetricCount":18,"waitingMetricCount":6,"reliableMetricCount":7,"observationRowCount":31},"categories":[{"key":"payments","label":"결제·전환","metrics":[{"label":"학습 패키지 결제 승인율","unit":"percent","status":"reliable","statusLabel":"판단 가능","minimumSampleSize":100,"observations":[{"valueLabel":"83.2%","numerator":104,"denominator":125,"sampleSize":125,"dimensionsLabel":"전체","note":"승인 완료 결제만 분자에 포함"}]},{"label":"29일 후 재구매율","unit":"percent","status":"collecting","statusLabel":"표본 수집 중","minimumSampleSize":100,"observations":[{"valueLabel":"41.7%","numerator":25,"denominator":60,"sampleSize":60,"dimensionsLabel":"Unranked","note":"관측 기간이 끝난 이용자만 분모에 포함"}]}]},{"key":"match","label":"Arena 경기","metrics":[{"label":"경기 완료율","unit":"percent","status":"reliable","statusLabel":"판단 가능","minimumSampleSize":100,"observations":[{"valueLabel":"91.4%","numerator":224,"denominator":245,"sampleSize":245,"dimensionsLabel":"Ranked","note":""}]}]}],"assumptions":[{"label":"도전자 승률","assumptionLabel":"50%","actualLabel":"52.3%","sampleSize":188,"ready":true,"minimumSampleSize":100},{"label":"페이백 수령률","assumptionLabel":"35%","actualLabel":"아직 측정 불가","sampleSize":42,"ready":false,"minimumSampleSize":100}]}}"#
    static let mutation = #"{"schemaVersion":"ADMIN_DATA_ANALYSIS_NATIVE_V1","ok":true}"#
  }
#endif
