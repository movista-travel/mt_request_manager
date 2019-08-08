//
//  Error.swift
//  MTRequestManager
//
//  Created by Alex Khodko on 08.08.2019.
//

import Foundation
import SwiftyJSON

public enum NetworkError: Error {
    case unauthorised(String)
    case serverError(String)
    case unknown(String)
    case noInternetConnection(String)
    case invalidResponse(Data, String)
    case corruptedResponse(JSON, String)
    
    init(with statusCode: String, url: String, data: [String : Any]) {
        let description = "status code \(statusCode). network error @ \(url) with \(data)"
        switch statusCode {
        case "500": self = .serverError(description)
        case "401": self = .unauthorised(description)
        case "-1009", "-1001": self = .noInternetConnection(description)
        default: self = .unknown(description)
        }
    }
}

extension NetworkError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unauthorised(let description):
            return "unauthorised. \(description)"
        case .serverError(let description):
            return "server error. \(description)"
        case .unknown(let description):
            return "Что-то пошло не так. \(description)"
        case .noInternetConnection(let description):
            return "no internet connection. \(description)"
        case .invalidResponse(let data, let url):
            return "invalid response @ \(url):\n \(data)"
        case .corruptedResponse(let data, let url):
            return "corrupted response @ \(url):\n \(data.dictionaryValue)"
        }
    }
}
