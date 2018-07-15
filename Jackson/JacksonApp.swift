//
//  JacksonApp.swift
//  Jackson
//
//  Created by Alan Westbrook on 7/14/18.
//  Copyright © 2018 rockwood. All rights reserved.
//

import Cocoa

@objc(JacksonApp)
class JacksonApp: NSApplication {
    
    public static let MediaKey: Notification.Name = Notification.Name(rawValue: "Media")
    public static let CodeKey = "code"
    public static let StateKey = "state"

    override func sendEvent(_ theEvent: NSEvent) {
        if theEvent.type == NSEvent.EventType.systemDefined &&
           theEvent.subtype.rawValue == 8 {

            let keyCode = ((theEvent.data1 & 0xFFFF0000) >> 16)
            let keyFlags = (theEvent.data1 & 0x0000FFFF)
            let keyState = (((keyFlags & 0xFF00) >> 8)) == 0xA
//            let keyRepeat = (keyFlags & 0x1) == 1
            
            keyWindow?.sendEvent(theEvent)
            NotificationCenter.default.post(name: JacksonApp.MediaKey,
                                            object: self,
                                            userInfo: [JacksonApp.CodeKey: keyCode,
                                                       JacksonApp.StateKey: keyState])
            return
        }

        super.sendEvent(theEvent)
    }
}
