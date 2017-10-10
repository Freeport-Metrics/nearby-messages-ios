//
//  String+UTF8.swift
//  NearbyMessages
//
//  Created by Michal Cichecki on 09/10/2017.
//  Copyright © 2017 skamycki. All rights reserved.
//

import Foundation

extension String {
    
    static func utf8encoded(data: Data) -> String? {
        return String(data: data, encoding: .utf8)
    }
}
