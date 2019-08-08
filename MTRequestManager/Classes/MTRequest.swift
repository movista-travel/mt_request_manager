//
//  MTRequest.swift
//  MTRequestManager
//
//  Created by Alex Khodko on 08.08.2019.
//

import Foundation

extension MTRequestManager {
    public class Request {
        let endpoint: String
        let method: MTRequestManager.HTTPMethod
        let query: String
        let parameters: [String : Any]
    
        init(endpoint: String, method: MTRequestManager.HTTPMethod, parameters: [String: Any] = [:], query: String = "") {
            self.endpoint = endpoint
            self.method = method
            self.query = query
            self.parameters = parameters
        }
    }
}

