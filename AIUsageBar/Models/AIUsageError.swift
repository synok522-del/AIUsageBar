import Foundation

enum AIUsageError: LocalizedError {

    case authenticationExpired(service: String)
    case rateLimited(service: String)
    case networkError(service: String)
    case unknown(service: String)

    var errorDescription: String? {

        switch self {

        case .authenticationExpired(let service):
            return "\(service) 登入已失效"

        case .rateLimited(let service):
            return "\(service) 使用頻率過高，請稍後再試"

        case .networkError(let service):
            return "\(service) 網路連線失敗"

        case .unknown(let service):
            return "\(service) 發生錯誤"
        }
    }
}
