//
//  NetworkingCore.swift
//  MyMessenger
//
//  Created by Yaroslav Zarechnyy on 4/8/20.
//  Copyright © 2020 Yaroslav Zarechnyy. All rights reserved.
//

import Foundation

enum CustomError: LocalizedError {
    case runtime(String)
    case undefined
    
    var errorDescription: String? {
        switch self {
        case .runtime(let value):
            return value
        case .undefined:
            return "Undefined error"
        }
    }
}

enum HTTPMethod: String {
    case POST
    case GET
    case PATCH
    case DELETE
    case PUT
}

struct EndpointCollection { }

struct Endpoint {
    var method: HTTPMethod
    var pathEnding: String
    var fullPathString: String?
    
    init(method: HTTPMethod, pathEnding: String) {
        self.method = method
        self.pathEnding = pathEnding
    }
    
    init(method: HTTPMethod, fullPath: String) {
        self.method = method
        self.fullPathString = fullPath
        self.pathEnding = ""
    }
}

extension Endpoint {
    
    var url: URL {
        if let fullPath = fullPathString {
            return URL(string: fullPath)!
        }
        let pathString = Config.basePath /*+ Config.apiVersion*/ + pathEnding
        return URL(string: pathString.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!)!
    }
    
}

enum Result<T: Decodable> {
    case success(T)
    case failure(Error)
}

class NetworkingService {
    
    private let urlSession = URLSession.shared
    
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    @discardableResult
    func performRequest<D: Encodable, R: Decodable>(to endpoint: Endpoint, with jsonData: D, completion: @escaping (Result<R>) -> Void) -> URLSessionDataTask {
        print("Requesting \(endpoint) with \(jsonData)")
        var data: Data
        do {
            data = try encoder.encode(jsonData)
        } catch {
            preconditionFailure(error.localizedDescription)
        }
        return request(to: endpoint, with: data) { [weak self] (data, response, error) in
            guard let strongSelf = self else { return }
            if let error = error {
                completion(.failure(error))
            } else if let data = data {
                do {
                    let response = try strongSelf.decoder.decode(R.self, from: data)
                    completion(.success(response))
                    return
                } catch {
                    print("Code: \((response as? HTTPURLResponse)?.statusCode ?? -1) Data: ", String(data: data, encoding: .utf8) ?? "nil")
                    completion(.failure(error))
                    return
                }
            } else {
                completion(.failure(CustomError.undefined))
                return
            }
        }
    }
    
    @discardableResult
    func performRequest<R: Decodable>(to endpoint: Endpoint, completion:  @escaping (Result<R>) -> Void) -> URLSessionDataTask {
        print("Requesting \(endpoint)")
        return request(to: endpoint, with: nil) { [weak self] (data, response, error) in
            guard let strongSelf = self else { return }
            if let error = error {
                completion(.failure(error))
            } else if let data = data {
                do {
                    let response = try strongSelf.decoder.decode(R.self, from: data)
                    completion(.success(response))
                    return
                } catch {
                    print("Code: \((response as? HTTPURLResponse)?.statusCode ?? -1) Data: ", String(data: data, encoding: .utf8) ?? "nil")
                    completion(.failure(error))
                    return
                }
            } else {
                completion(.failure(CustomError.undefined))
                return
            }
        }
    }
    
    private func request(to endpoint: Endpoint, with data: Data?, responseHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        var request = URLRequest(url: endpoint.url)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = User.current?.token {
            print("Using token:", token)
            request.addValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        } else {
            print("No token")
        }
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = data
        let task = urlSession.dataTask(with: request, completionHandler: { (data, response, error) in
            responseHandler(data, response, error)
        })
        task.resume()
        return task
    }
    
}
