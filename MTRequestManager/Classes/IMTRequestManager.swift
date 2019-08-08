//
//  IMTRequestManager.swift
//  MTRequestManager
//
//  Created by Alex Khodko on 08.08.2019.
//

import Foundation
protocol IMTRequestManager {
    @discardableResult
    func execute(_ request: MTRequestManager.Request, onComplete: @escaping (MTRequestManager.Response) -> ()) -> URLSessionDataTask?
}
