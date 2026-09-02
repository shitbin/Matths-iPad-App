#if DEBUG
import Foundation

enum DemoAdminStoreFixtures {
    static var dashboard: String { envelope(ok: false) }
    static var mutation: String { envelope(ok: true) }

    private static func envelope(ok: Bool) -> String {
        let hallRoot = try! JSONSerialization.jsonObject(with: Data(DemoStudyHallFixtures.list().utf8)) as! [String: Any]
        var hall = hallRoot["hall"] as! [String: Any]
        hall.removeValue(forKey: "continuing")
        hall["activeTab"] = ""
        hall["editing"] = NSNull()

        let storeRoot = try! JSONSerialization.jsonObject(with: Data(DemoStoreCatalogFixtures.catalog.utf8)) as! [String: Any]
        let catalog = storeRoot["catalog"] as! [String: Any]
        let products = catalog["products"] as? [[String: Any]] ?? []
        let categories = (catalog["categories"] as? [[String: Any]] ?? []).map { value -> [String: Any] in
            var category = value
            category["productCount"] = products.filter { ($0["category"] as? String) == (value["name"] as? String) }.count
            return category
        }
        let store: [String: Any] = ["products": products, "editing": NSNull(), "categories": categories]
        var root: [String: Any] = ["schemaVersion": "ADMIN_STORE_NATIVE_V1", "dashboard": ["studyHall": hall, "store": store]]
        if ok { root["ok"] = true }
        let data = try! JSONSerialization.data(withJSONObject: root, options: [])
        return String(decoding: data, as: UTF8.self)
    }
}
#endif
