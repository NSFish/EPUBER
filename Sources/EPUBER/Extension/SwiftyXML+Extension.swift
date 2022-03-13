//
//  SwiftyXML+Extension.swift
//  EPUBER
//
//  Created by nsfish on 2021/11/21.
//

import Foundation
import SwiftyXML

func copyXMLWithoutChildren(original xml: XML) -> XML {
    // SwiftyXML 目前不支持 removeChild，只好曲线救国
    return XML.init(name: xml.xmlName, attributes: xml.xmlAttributes, value: xml.xmlValue)
}

extension XMLSubscriptResult {
    
    public func tryGetXML() -> XML {
        return try! getXML()
    }
}
