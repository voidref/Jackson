//
//  AppDelegate.swift
//  Jackson
//
//  Created by Alan Westbrook on 6/30/15.
//  Copyright (c) 2015 rockwood. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // if only ... "launchctl unload -w /System/Library/LaunchAgents/com.apple.rcd.plist"
    }

    func applicationWillTerminate(aNotification: NSNotification) {
    }


}

