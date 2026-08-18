//
//  WebSessionManager.swift
//  AIUsageBar
//

import Foundation
import WebKit

final class WebSessionManager {

    static let shared = WebSessionManager()

    private init() {}

    /// 清除所有 WebView Cookie 與網站資料
    func clearCookies(completion: (() -> Void)? = nil) {

        let dataStore = WKWebsiteDataStore.default()

        // 先刪除所有 Cookie
        dataStore.httpCookieStore.getAllCookies { cookies in

            let group = DispatchGroup()

            for cookie in cookies {

                group.enter()

                dataStore.httpCookieStore.delete(cookie) {
                    group.leave()
                }
            }

            group.notify(queue: .main) {

                // 再清除網站資料
                let dataTypes: Set<String> = [
                    WKWebsiteDataTypeCookies,
                    WKWebsiteDataTypeLocalStorage,
                    WKWebsiteDataTypeSessionStorage,
                    WKWebsiteDataTypeIndexedDBDatabases,
                    WKWebsiteDataTypeWebSQLDatabases,
                    WKWebsiteDataTypeDiskCache,
                    WKWebsiteDataTypeMemoryCache
                ]

                dataStore.removeData(
                    ofTypes: dataTypes,
                    modifiedSince: Date(timeIntervalSince1970: 0)
                ) {

                    print("✅ Web session cleared")

                    completion?()
                }
            }
        }
    }
}
