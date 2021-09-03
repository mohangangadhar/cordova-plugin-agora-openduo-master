//
//  Helper.swift
//  Vertulio
//
//  Created by Aman Sharma on 27/01/21.
//

import Foundation

class Helper {
    static func parseValueJsonObject(jsonData: String, fieldName: String, defaultValue: String) -> String {
        print("parseValueJsonObject_jsonData", jsonData);
        var toReturn = defaultValue;
        let data = jsonData.data(using: .utf8);
        do {
            if let jsonObject = try JSONSerialization.jsonObject(with: data!, options : .allowFragments) as? Dictionary<String,Any>
            {
                toReturn = jsonObject[fieldName] as! String;
            } else {
                print("bad json")
            }
        } catch let error as NSError {
            print("parseValueJsonObject_error", error)
        }
        print("parseValueJsonObject_returning", toReturn);
        return toReturn;
    }
    
}
