import Foundation

/// User-facing copy for fetch failures (popover status row).
public enum FetchErrorCopy {
    public static let rateLimited = "Rate limited — next check in a few minutes."
    public static let providerUnavailable = "Provider temporarily unavailable. Try again shortly."
    public static let offline = "Offline — check your connection."
    public static let timedOut = "Request timed out."
    public static let invalidResponse = "Couldn’t read usage data."
    public static let invalidURL = "Invalid usage URL."

    public static func message(forHTTPStatus code: Int) -> String {
        switch code {
        case 429:
            rateLimited
        case 500 ... 599:
            providerUnavailable
        case 401, 403:
            // Callers usually map these to `.needsAuth`; keep a fallback string.
            "Session expired — connect again."
        default:
            "Couldn’t load usage (error \(code))."
        }
    }

    public static func message(for error: Error) -> String {
        if let http = error as? HTTPClientError {
            switch http {
            case .invalidURL:
                return invalidURL
            case let .badStatus(code, _):
                return message(forHTTPStatus: code)
            case let .transport(raw):
                return networkMessage(raw: raw)
            }
        }

        if let urlError = error as? URLError {
            return message(forURLError: urlError)
        }

        if error is DecodingError {
            return invalidResponse
        }

        let raw = error.localizedDescription
        if raw.isEmpty || raw == "The operation couldn’t be completed." {
            return "Something went wrong. Try Refresh."
        }
        return networkMessage(raw: raw)
    }

    public static func isRateLimitedMessage(_ message: String) -> Bool {
        message == rateLimited || message.hasPrefix("Rate limited")
    }

    public static func networkMessage(raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("not connected")
            || lower.contains("offline")
            || lower.contains("network connection was lost")
            || lower.contains("internet connection appears to be offline") {
            return offline
        }
        if lower.contains("timed out") || lower.contains("timeout") {
            return timedOut
        }
        if lower.contains("could not connect") || lower.contains("connection refused") {
            return offline
        }
        return raw
    }

    private static func message(forURLError error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            offline
        case .timedOut:
            timedOut
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            offline
        default:
            networkMessage(raw: error.localizedDescription)
        }
    }
}
