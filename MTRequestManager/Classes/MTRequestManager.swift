//
//  MTRequestManager.swift
//  MTRequestManager
//
//  Created by Alex Khodko on 08.08.2019.
//

import Foundation
import SwiftyJSON

final class MTRequestManager {
    
    private let baseURL: String
    private let defaultParameters: [String: Any]
    
    
    private let defaults: UserDefaults
    private let accessTokenKey: String?
    private let refreshTokenKey: String?
    
    private var accessToken: String {
        get {
            if let accessTokenKey = accessTokenKey {
                return defaults.string(forKey: accessTokenKey) ?? ""
            }
            return ""
        }
        
        set {
            if let accessTokenKey = accessTokenKey {
                defaults.set(newValue, forKey: accessTokenKey)
            }
        }
    }
    
    private var refreshToken: String {
        get {
            if let refreshTokenKey = refreshTokenKey {
                return defaults.string(forKey: refreshTokenKey) ?? ""
            }
            return ""
        }
        
        set {
            if let refreshTokenKey = refreshTokenKey {
                defaults.set(newValue, forKey: refreshTokenKey)
            }
        }
    }
    
    private var onRefreshTokenFailure: () -> ()
    private var refreshURL: String
    
//
//    #if TEST
//    private let baseURL = "https://maas.dev-k8s.movista.ru/api/"
//    //    private let baseURL = "http://192.168.32.167:8080/api/"
//    //    private let baseURL = "http://192.168.32.28:8080/api/"
//
//    #elseif STAGE
//    private let baseURL = "https://maasapi.stage-k8s.movista.ru/api/"
//    #elseif PRODUCTION
//    private let baseURL = "https://api.maas.movista.ru/api/"
//    #else
//    private let baseURL = "https://maas.dev-k8s.movista.ru/api/"
//    #endif
    
    init(url: String,
         defaultParameters: [String: Any],
         accessTokenKey: String?,
         refreshTokenKey: String?,
         defaults: UserDefaults,
         onRefreshTokenFailure: @escaping () -> () = { },
         refreshURL: String?) {
        baseURL = url
        self.defaultParameters = defaultParameters
        self.accessTokenKey = accessTokenKey
        self.refreshTokenKey = refreshTokenKey
        self.onRefreshTokenFailure = onRefreshTokenFailure
        
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.timeoutIntervalForRequest = 90.0
        sessionConfiguration.timeoutIntervalForResource = 90.0
        session = URLSession(configuration: sessionConfiguration)
    }
    
    private let session: URLSession
    
    enum HTTPMethod: String {
        case post
        case put
        case delete
        case get
    }
    
    public enum Response {
        case success(JSON)
        case error(NetworkError)
    }
    
    private class RefreshTokenRequest: Request {
        init(refreshToken: String, refreshURL: String) {
            let parameters: [String : Any] = ["refresh_token": refreshToken]
//            super.init(endpoint: "auth/refresh", method: .post, parameters: parameters)
            super.init(endpoint: refreshURL, method: .post, parameters: parameters)
        }
    }
}

extension MTRequestManager: IMTRequestManager {
    
    private func refreshToken(_ request: MTRequestManager.Request, onComplete: @escaping (MTRequestManager.Response) -> ()) {
        let refreshTokenRequest = RefreshTokenRequest(refreshToken: refreshToken, refreshURL: refreshURL)
        let requestURLString = baseURL + refreshTokenRequest.endpoint
        if let requestURL = URL(string: requestURLString) {
            var requestObject = URLRequest(url: requestURL)
            requestObject.addValue("application/json", forHTTPHeaderField: "Content-Type")
            requestObject.httpMethod = refreshTokenRequest.method.rawValue.uppercased()
            var parameters = refreshTokenRequest.parameters
            defaultParameters.forEach {
                parameters[$0.key] = $0.value
            }
//            let userID = UIDevice.current.identifierForVendor?.uuidString ?? "vendor id missing"
//            parameters["user_id"] = userID
//            parameters["version"] = Bundle.version
            do {
                let JSON = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
                requestObject.httpBody = JSON
            } catch let error {
                let loggableError = LoggableError(error: error, errorCode: 5011)
                logger.log(error: loggableError)
            }
            let task = session.dataTask(with: requestObject) { [weak self] (data, response, error) in
                guard let self = self else { return }
                if let error = error as NSError? {
                    if error.code == -999 {
                        return
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: { [weak self] in
                        guard let self = self else { return }
                        self.refreshToken(request, onComplete: onComplete)
                    })
                    return
                }
                
                if let response = response as? HTTPURLResponse, response.statusCode != 200 {
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "kLogout"), object: nil)
                    return
                }
                
                guard let data = data else {
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "kLogout"), object: nil)
                    return
                }
                
                do {
                    let object = try JSON(data: data)
                    logger.log(message: LoggableMessage(message: "\(object.dictionaryValue)"))
                    guard let token = object["access_token"].string, let refreshToken = object["refresh_token"].string else {
//                        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "kLogout"), object: nil)
                        self.onRefreshTokenFailure()
                        return
                    }
                    
                    self.accessToken = token
                    self.refreshToken = refreshToken
                    self.execute(request, onComplete: onComplete)
                } catch {
//                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "kLogout"), object: nil)
                    self.onRefreshTokenFailure()
                    return
                }
            }
            task.resume()
        }
    }
    
    @discardableResult
    func execute(_ request: Request, onComplete: @escaping (Response) -> ()) -> URLSessionDataTask? {
        var requestURLString = baseURL + request.endpoint
        let query = request.query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        requestURLString += query
        if let requestURL = URL(string: requestURLString) {
            var requestObject = URLRequest(url: requestURL)
            requestObject.addValue("application/json", forHTTPHeaderField: "Content-Type")
//            if let token = defaults.app.string(forKey: DefaultKeys.newToken) {
//                requestObject.addValue(token, forHTTPHeaderField: "Authorization")
//            }
            requestObject.addValue(accessToken, forHTTPHeaderField: "Authorization")
            requestObject.httpMethod = request.method.rawValue.uppercased()
            var parameters = request.parameters
            defaultParameters.forEach {
                parameters[$0.key] = $0.value
            }
            
//            let userID = UIDevice.current.identifierForVendor?.uuidString ?? "vendor id missing"
//            parameters["user_id"] = userID
//            parameters["version"] = Bundle.version
            
            #if TEST || STAGE
            logger.log(message: LoggableMessage(message: userID))
            #endif
            
            do {
                let JSON = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
                requestObject.httpBody = JSON
            } catch let error {
                let loggableError = LoggableError(error: error, errorCode: 5012)
                logger.log(error: loggableError)
            }
            
            #if TEST || STAGE
            logger.log(message: LoggableMessage(message: "\(requestObject)"))
            logger.log(message: LoggableMessage(message: "\(parameters)"))
            #endif
            
            let task = session.dataTask(with: requestObject) { [weak self] (data, response, error) in
                guard let self = self else { return }
                if let error = error as NSError? {
                    if error.code == -999 {
                        return
                    }
                    let networkError = NetworkError(with: String(error.code), url: request.endpoint, data: request.parameters)
                    let loggableError = LoggableError(error: error, errorCode: 5013)
                    logger.log(error: loggableError)
                    DispatchQueue.main.async {
                        onComplete(.error(networkError))
                    }
                    return
                }
                
                if let response = response as? HTTPURLResponse, response.statusCode ==  401, !request.endpoint.contains("ping/location") {
                    self.refreshToken(request, onComplete: onComplete)
                    return
                }
                
                if let response = response as? HTTPURLResponse, response.statusCode != 200 {
                    let error = NetworkError(with: String(response.statusCode), url: request.endpoint, data: request.parameters)
                    let loggableError = LoggableError(error: error, errorCode: 5014)
                    logger.log(error: loggableError)
                    DispatchQueue.main.async {
                        onComplete(.error(error))
                    }
                    return
                }
                
                guard let data = data else {
                    let error = NetworkError(with: "-1", url: request.endpoint, data: request.parameters)
                    let loggableError = LoggableError(error: error, errorCode: 5015)
                    logger.log(error: loggableError)
                    DispatchQueue.main.async {
                        onComplete(.error(error))
                    }
                    return
                }
                
                do {
                    let object = try JSON(data: data)
                    logger.log(message: LoggableMessage(message: "\(object.dictionaryValue)"))
                    if let errorCode = object["error"]["code"].string {
                        let error = NetworkError(with: errorCode, url: request.endpoint, data: request.parameters)
                        let loggableError = LoggableError(error: error, errorCode: 5016)
                        logger.log(error: loggableError)
                        DispatchQueue.main.async {
                            onComplete(.error(error))
                        }
                        return
                    }
                    DispatchQueue.main.async {
                        onComplete(.success(object))
                    }
                } catch {
                    let error = NetworkError.invalidResponse(data, request.endpoint)
                    let loggableError = LoggableError(error: error, errorCode: 5017)
                    logger.log(error: loggableError)
                    DispatchQueue.main.async {
                        onComplete(.error(error))
                    }
                    return
                }
            }
            task.resume()
            return task
        }
        return nil
    }
}
