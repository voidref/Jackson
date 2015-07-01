//
//  JacksonViewController.swift
//  Jackson
//
//  Created by Alan Westbrook on 6/30/15.
//  Copyright (c) 2015 rockwood. All rights reserved.
//

import Cocoa
import AVFoundation

class JacksonViewController: NSViewController, SongUpdateDelegate, NSTableViewDataSource, NSTableViewDelegate, AVAudioPlayerDelegate {

    @IBOutlet var tableView:NSTableView!
    @IBOutlet var playPause:NSButton!
    var mainView:JacksonMainView {
        get {
            return view as! JacksonMainView
        }
    }
    
    private var player:AVAudioPlayer?
    private var nextPlayer:AVAudioPlayer?
    private var songIndex = 0 {
        didSet {
            tableView.selectRowIndexes(NSIndexSet(index: songIndex - 1), byExtendingSelection: false)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        mainView.registerForDraggedTypes([NSFilenamesPboardType])
        mainView.songDelegate = self
    }
    
    // MARK: - Song Delegate 
    
    func songsUpdated() {
        tableView.reloadData()
        
        startPlayer()
    }
    
    // MARK: - TableViewness
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return mainView.songPaths.count
    }

    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var field:NSTextField? = tableView.makeViewWithIdentifier("rowView", owner: self) as? NSTextField
        
        if nil == field {
            field = NSTextField(frame: NSZeroRect)
            field?.bordered = false
            field?.identifier = "rowView"
        }
        
        field?.stringValue = mainView.songPaths[row].lastPathComponent.stringByDeletingPathExtension
        
        return field
    }
        
    // MARK: - Actions
    
    @IBAction func playPauseClicked(button:NSButton) {
        if let player = player {
            if player.playing {
                player.pause()
            }
            else {
                player.play()
            }
        }
        updatePlayPause()
    }

    @IBAction func nextClicked(button:NSButton) {
        advanceToNextSong()
    }

    // MARK: - AVAudioPlayer
    
    private func startPlayer() {
        if nil == player && mainView.songPaths.count > 0 {
            
            var index = 0
            while player == nil && index < mainView.songPaths.count {
                player = avPlayerForSongIndex(songIndex)
                index++
            }
            
            player?.play()
            updatePlayPause()

            if mainView.songPaths.count > index {
                nextPlayer = avPlayerForSongIndex(index)
            }
            
            songIndex = index
        }
    }
    
    func avPlayerForSongIndex(index: Int) -> AVAudioPlayer? {
        var result:AVAudioPlayer?
        if let url = NSURL(fileURLWithPath: mainView.songPaths[index]) {
            var error:NSError?
            result = AVAudioPlayer(contentsOfURL: url, error: &error)
            
            result?.delegate = self
            result?.prepareToPlay()
        }
        
        return result
    }
    
    func audioPlayerDidFinishPlaying(player: AVAudioPlayer!, successfully flag: Bool) {
        advanceToNextSong()
    }
    
    func advanceToNextSong() {
        songIndex++
        
        player = nextPlayer
        player?.play()
        
        if songIndex == mainView.songPaths.count {
            songIndex = 0
        }
        
        nextPlayer = avPlayerForSongIndex(songIndex)
    }
    
    func updatePlayPause() {
        if let player = player {
            if player.playing {
                playPause.title = NSLocalizedString("Pause", comment: "pause button title")
            }
            else {
                playPause.title = NSLocalizedString("Play", comment: "play button title")
            }
        }
    }
}
