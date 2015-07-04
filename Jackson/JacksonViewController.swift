//
//  JacksonViewController.swift
//  Jackson
//
//  Created by Alan Westbrook on 6/30/15.
//  Copyright (c) 2015 rockwood. All rights reserved.
//

import Cocoa
import AVFoundation
import AudioToolbox


struct SongData : Printable, Comparable, Hashable {
    var path:String
    var track:Int?
    var album:String?
    
    var description:String {
        get {
            return "\(path.lastPathComponent) / \(track) / \(album)"
        }
    }
    
    var hashValue: Int {
        get {
            return path.hashValue
        }
    }

    init(path:String) {
        self.path = path
        
        var fileID:AudioFileID = nil
        let url = NSURL(fileURLWithPath: path)! as CFURL
        AudioFileOpenURL(url, Int8(kAudioFileReadPermission), AudioFileTypeID(0), &fileID)
        
        if fileID != nil {
            var dict:CFDictionary = [:] as CFDictionary 
            var piDataSize:UInt32 = UInt32(sizeof(CFDictionaryRef.Type))
            
            //  Populates a CFDictionary with the ID3 tag properties
            let err = AudioFileGetProperty(fileID, AudioFilePropertyID(kAudioFilePropertyInfoDictionary), &piDataSize, &dict)
            
            let info = dict as Dictionary

            if let trackFuckery = info[kAFInfoDictionary_TrackNumber] as? String {
                let trackInfo = trackFuckery.componentsSeparatedByString("/")
                track = trackInfo[0].toInt()
            }
            
            album = info[kAFInfoDictionary_Album] as? String
        }
    }
}

func ==(lhs:SongData, rhs:SongData) -> Bool {
    return lhs.path == rhs.path &&
        lhs.track == rhs.track &&
        lhs.album == lhs.album
}

func <(lhs:SongData, rhs:SongData) -> Bool {
    if let aLeft = lhs.album {
        if let aRight = rhs.album {
            if let tLeft = lhs.track {
                if let tRight = rhs.track {
                    if aRight == aLeft {
                        return tLeft < tRight
                    }
                    else {
                        return aLeft < aRight
                    }
                }
            }
            else if let tRight = rhs.track {
                return false
            }
            else {
                return aLeft < aRight
            }
        }
    }
    else if let aRight = rhs.album {
        return false
    }
        
    return lhs.path < rhs.path
}

class JacksonViewController: NSViewController, SongDelegate, NSTableViewDataSource, NSTableViewDelegate, AVAudioPlayerDelegate {

    @IBOutlet var tableView:NSTableView!
    @IBOutlet var playPause:NSButton!
    @IBOutlet var progressBar:NSSlider!
    @IBOutlet var totalTime:NSTextField!
    @IBOutlet var currentTime:NSTextField!
    @IBOutlet var playMenuItem:NSMenuItem!
    
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
    private var songs:[SongData] = []
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
    
    // MARK: - Overrides
    override var acceptsFirstResponder:Bool { get { return true } }
    
    override func keyUp(theEvent: NSEvent) {
        if theEvent.keyCode == 49 {
            togglePlayPause()
        }
        else {
            super.keyUp(theEvent)
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

    override func deleteBackward(sender: AnyObject?) {
        deleteSelectedSong()
    }
    
    // MARK: - Song Delegate 
    
    func addSongPaths(paths: [String]) {
        let data = paths.map { SongData(path: $0) }
        let songSet = Set(songs)
        songs = Array<SongData>(songSet.union(data))
        sortSongs()
        
        tableView.reloadData()
        startPlayer()
    }
    
    // MARK: - TableViewness
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return songs.count
    }

    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var field:NSTextField? = tableView.makeViewWithIdentifier("rowView", owner: self) as? NSTextField
        
        if nil == field {
            field = NSTextField(frame: NSZeroRect)
            field?.bordered = false
            field?.identifier = "rowView"
            field?.editable = false
        }
        
        field?.stringValue = songs[row].path.lastPathComponent.stringByDeletingPathExtension
        
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
    
    @IBAction func playMenuInvoked(sender: NSMenuItem) {
        togglePlayPause()
    }

    @IBAction func playPauseClicked(button:NSButton) {
        togglePlayPause()
    }

    @IBAction func sliderClicked(sender:NSSlider) {
        currentTime.stringValue = timeFormatter.stringFromTimeInterval(sender.doubleValue)!
        player?.currentTime = sender.doubleValue
    }
    
    // MARK: - AVAudioPlayer
    
    private func startPlayer() {
        if nil == player && songs.count > 0 {
            
            var index = 0
            while player == nil && index < songs.count {
                player = avPlayerForSongIndex(songIndex)
                index++
            }
            
            player?.play()
            updatePlayPause()

            if songs.count > index {
                nextPlayer = avPlayerForSongIndex(index)
            }
            
            songIndex = 0
        }
    }
    
    func avPlayerForSongIndex(index: Int) -> AVAudioPlayer? {
        var result:AVAudioPlayer?
        if let url = NSURL(fileURLWithPath: songs[index].path) {
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
        songs.sort { (lhs, rhs) -> Bool in
            return lhs < rhs
        }
    }
    
    private func advanceToNextSong() {
        songIndex++

        player = nextPlayer
        
        if playing {
            player?.play()
        }
        
        if songIndex == songs.count {
            songIndex = 0
        }
        
        var nextIndex = songIndex + 1
        if nextIndex == songs.count {
            nextIndex = 0
        }
        
        nextPlayer = avPlayerForSongIndex(nextIndex)
    }
    
    private func updatePlayPause() {
        if let player = player {
            var title = NSLocalizedString("Play", comment: "play button title")
            if player.playing {
                title = NSLocalizedString("Pause", comment: "pause button title")
            }
            
            playPause.title = title
            playMenuItem.title = title
            playing = player.playing
        }
    }
    
    private func deleteSelectedSong() {
        if tableView.selectedRow != NSNotFound {
            songs.removeAtIndex(tableView.selectedRow)
            songIndex--
            tableView.reloadData()
            advanceToNextSong()
        }
    }
    
    @objc private func updateDisplay() {
        if let player = player {
            currentTime.stringValue = timeFormatter.stringFromTimeInterval(player.currentTime)!
            progressBar.doubleValue = player.currentTime
        }
    }
    
    private func togglePlayPause() {
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
}
