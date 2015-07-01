//
//  JacksonViewController.swift
//  Jackson
//
//  Created by Alan Westbrook on 6/30/15.
//  Copyright (c) 2015 rockwood. All rights reserved.
//

import Cocoa
import AVFoundation

class JacksonViewController: NSViewController, SongDelegate, NSTableViewDataSource, NSTableViewDelegate, AVAudioPlayerDelegate {

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
            tableView.selectRowIndexes(NSIndexSet(index: songIndex), byExtendingSelection: false)
            tableView.scrollRowToVisible(songIndex)
        }
    }
    private var songPaths:[String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        mainView.registerForDraggedTypes([NSFilenamesPboardType])
        mainView.songDelegate = self
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "tableSelectionChanged:", name: NSTableViewSelectionDidChangeNotification, object: tableView)
    }
    
    // MARK: - Song Delegate 
    
    func addSongPaths(paths: [String]) {
        
        songPaths = Array<String>((Set(songPaths).union(paths)))
        
        sortSongs()
        
        tableView.reloadData()
        startPlayer()
    }
    
    // MARK: - TableViewness
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return songPaths.count
    }

    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var field:NSTextField? = tableView.makeViewWithIdentifier("rowView", owner: self) as? NSTextField
        
        if nil == field {
            field = NSTextField(frame: NSZeroRect)
            field?.bordered = false
            field?.identifier = "rowView"
        }
        
        field?.stringValue = songPaths[row].lastPathComponent.stringByDeletingPathExtension
        
        return field
    }
        
    func tableView(tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }
    
    func tableView(tableView:NSTableView, rowSelected:Int) {
        
    }
    
    func tableSelectionChanged(note:NSNotification) {
        var index = tableView.selectedRow
        
        if index != songIndex {
            nextPlayer = avPlayerForSongIndex(index)
            // Bit of a hack, advance updates the index, so we have to pretend we were on the previous one.
            songIndex = index - 1
            
            advanceToNextSong()
        }
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
        if nil == player && songPaths.count > 0 {
            
            var index = 0
            while player == nil && index < songPaths.count {
                player = avPlayerForSongIndex(songIndex)
                index++
            }
            
            player?.play()
            updatePlayPause()

            if songPaths.count > index {
                nextPlayer = avPlayerForSongIndex(index)
            }
            
            songIndex = 0
        }
    }
    
    func avPlayerForSongIndex(index: Int) -> AVAudioPlayer? {
        var result:AVAudioPlayer?
        if let url = NSURL(fileURLWithPath: songPaths[index]) {
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
    
    // MARK: - Private
    
    private func sortSongs() {
        songPaths.sort { (lhs, rhs) -> Bool in
            return lhs < rhs
        }
    }
    
    private func advanceToNextSong() {
        songIndex++

        let playing = player?.playing
        player = nextPlayer
        
        if let playingActual = playing where playingActual == true {
            player?.play()
        }
        
        if songIndex == songPaths.count {
            songIndex = 0
        }
        
        var nextIndex = songIndex + 1
        if nextIndex == songPaths.count {
            nextIndex = 0
        }
        
        nextPlayer = avPlayerForSongIndex(nextIndex)
    }
    
    private func updatePlayPause() {
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
