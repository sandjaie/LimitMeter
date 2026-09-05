import Foundation

public enum HTTPClientError: Error, Equatable, LocalizedError {
    case invalidURL
    case badStatus(Int, Data)
    case transport(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid URL"
        case let .badStatus(code, _):
            "HTTP \(code)"
        case let .transport(message):
            message
        }
    }
}

public struct HTTPResponse: Sendable {
    public var statusCode: Int
    public var data: Data

    public init(statusCode: Int, data: Data) {
        self.statusCode = statusCode
        self.data = data
    }
}

public protocol HTTPPerforming: Sendable {
    func data(for request: URLRequest) async throws -> HTTPResponse
}

public struct URLSessionHTTPClient: HTTPPerforming {
    public var session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> HTTPResponse {
        do {
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            return HTTPResponse(statusCode: status, data: data)
        } catch let error as URLError {
            throw error
        } catch {
            throw HTTPClientError.transport(error.localizedDescription)
        }
    }
}
