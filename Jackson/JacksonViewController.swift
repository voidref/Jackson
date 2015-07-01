//
//  JacksonViewController.swift
//  Jackson
//
//  Created by Alan Westbrook on 6/30/15.
//  Copyright (c) 2015 rockwood. All rights reserved.
//

import Cocoa

class JacksonViewController: NSViewController, SongUpdateDelegate, NSTableViewDataSource, NSTableViewDelegate {

    @IBOutlet var tableView:NSTableView!
    var mainView:JacksonMainView {
        get {
            return view as! JacksonMainView
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        mainView.registerForDraggedTypes([NSFilenamesPboardType])
        mainView.songDelegate = self
    }
    
    func songsUpdated() {
        print(mainView.songPaths)
        tableView.reloadData()
    }
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return mainView.songPaths.count
    }

    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var field:NSTextField? = tableView.makeViewWithIdentifier("rowView", owner: self) as? NSTextField
        
        if nil == field {
            field = NSTextField(frame: NSZeroRect)
            
            field?.identifier = "rowView"
        }
        
        field?.stringValue = mainView.songPaths[row]
        
        return field
    }
}
