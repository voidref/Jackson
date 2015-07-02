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
    @IBOutlet var progressBar:NSSlider!
    @IBOutlet var totalTime:NSTextField!
    @IBOutlet var currentTime:NSTextField!
    
    var mainView:JacksonMainView {
        get {
            return view as! JacksonMainView
        }
    }
    
    private var player:AVAudioPlayer? { 
        didSet {
            if let player = player {
                totalTime.stringValue = timeFormatter.stringFromTimeInterval(player.duration)!
                currentTime.stringValue = timeFormatter.stringFromTimeInterval(player.currentTime)!
                progressBar.enabled = true
                progressBar.maxValue = player.duration
                progressBar.doubleValue = 0
                
                if nil == updatePoller {
                    updatePoller = NSTimer.scheduledTimerWithTimeInterval(1.0 / 20.0, target: self, selector: "updateDisplay", userInfo: nil, repeats: true)
                }
            }
        }
    }
    
    private var nextPlayer:AVAudioPlayer?
    private var songPaths:[String] = []
    private var updatePoller:NSTimer?
    private var playing = false
    
    private lazy var timeFormatter:NSDateComponentsFormatter = {
        var formatter = NSDateComponentsFormatter()
        formatter.unitsStyle = .Positional
        formatter.zeroFormattingBehavior = .Pad
        formatter.allowedUnits = .CalendarUnitMinute | .CalendarUnitSecond           
        return formatter
    }()
    
    private var songIndex = 0 {
        didSet {
            tableView.selectRowIndexes(NSIndexSet(index: songIndex), byExtendingSelection: false)
            tableView.scrollRowToVisible(songIndex)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        mainView.registerForDraggedTypes([NSFilenamesPboardType])
        mainView.songDelegate = self
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "tableSelectionChanged:", name: NSTableViewSelectionDidChangeNotification, object: tableView)
        totalTime.stringValue = ""
        currentTime.stringValue = ""
        progressBar.doubleValue = 0
        progressBar.maxValue = 0
        progressBar.enabled = false
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
            
            playing = player.playing
        }
        updatePlayPause()
    }

    @IBAction func sliderClicked(sender:NSSlider) {
        currentTime.stringValue = timeFormatter.stringFromTimeInterval(sender.doubleValue)!
        player?.currentTime = sender.doubleValue
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

        player = nextPlayer
        
        if playing {
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
            
            playing = player.playing
        }
    }
    
    @objc private func updateDisplay() {
        if let player = player {
            currentTime.stringValue = timeFormatter.stringFromTimeInterval(player.currentTime)!
            progressBar.doubleValue = player.currentTime
        }
    }
}
