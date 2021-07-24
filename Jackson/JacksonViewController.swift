//
//  JacksonViewController.swift
//  Jackson
//
//  Created by Alan Westbrook on 6/30/15.
//  Copyright (c) 2015 rockwood. All rights reserved.
//

import Cocoa
import AVFoundation
import MediaPlayer

class JacksonViewController: NSViewController, NSTableViewDelegate, AVAudioPlayerDelegate, PlaylistDelegate {
    
    struct Keys {
        static let volume = "Volume"
        static let looping = "Looping"
    }

    static let hasTagOrganization = false
    
    @IBOutlet var tableView: NSTableView!
    @IBOutlet var playPause: NSButton!
    @IBOutlet var progressBar: NSSlider!
    @IBOutlet var totalTime: NSTextField!
    @IBOutlet var currentTime: NSTextField!
    @IBOutlet var playMenuItem: NSMenuItem!
    @IBOutlet var loopMenuItem: NSMenuItem!
    @IBOutlet var volumeMenuItem: NSMenuItem!

    
    var mainView: JacksonMainView {
        get {
            return view as! JacksonMainView
        }
    }
    
    private var player: AVAudioPlayer? {
        didSet {
            if let player = player {
                totalTime.stringValue = timeFormatter.string(from: player.duration)!
                currentTime.stringValue = timeFormatter.string(from: player.currentTime)!
                progressBar.isEnabled = true
                progressBar.maxValue = player.duration
                progressBar.doubleValue = 0
                
                if nil == updatePoller {
                    updatePoller = Timer.scheduledTimer(timeInterval: 1.0 / 20.0, target: self, selector: #selector(JacksonViewController.updateDisplay), userInfo: nil, repeats: true)
                }
            }
        }
    }
    
    private var playlist = Playlist()
    private var nextPlayer: AVAudioPlayer?
    private var updatePoller: Timer?
    private var playing = false
    private var looping = false {
        didSet {
            UserDefaults.standard.set(volume, forKey: Keys.looping)

            loopMenuItem?.state = looping ? .on : .off
            setNextPlayer()
        }
    }
    
    private let rowViewIdentifier = NSUserInterfaceItemIdentifier(rawValue: "rowView")

    private lazy var timeFormatter: DateComponentsFormatter = {
        var formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.minute, .second]
        return formatter
    }()
    
    private var volume: Float = 0.5 {
        didSet {
            UserDefaults.standard.set(volume, forKey: Keys.volume)
            
            player?.setVolume(volume, fadeDuration: 0.1)
            volumeMenuItem.title = "\(Int(volume * 100))%"
        }
    }
    
    // MARK: - Overrides
    
    override var acceptsFirstResponder:Bool { get { return true } }
    
    override func keyUp(with theEvent: NSEvent) {
        if theEvent.keyCode == 49 {
            togglePlayPause()
        }
        else {
            super.keyUp(with: theEvent)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mainView.registerForDraggedTypes([.fileURL])
        mainView.playlist = playlist
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(tableSelectionChanged(note:)),
                                               name: NSTableView.selectionDidChangeNotification,
                                               object: tableView)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(mediaKeyPressed(note:)),
                                               name: JacksonApp.MediaKey,
                                               object: nil)
        resetSongInfo()
        
        let defaults = UserDefaults.standard
        
        looping = defaults.bool(forKey: Keys.looping)
        volume = defaults.float(forKey: Keys.volume)
        if volume <= 0 { volume = 0.5 }
        
        tableView.dataSource = playlist
        tableView.becomeFirstResponder()

        playlist.delegate = self

        startPlayer()
        updateTableViewSelection()
    }

    // MARK: - Media key handling
    
    @objc func mediaKeyPressed(note: Notification) {
         guard let code = note.userInfo?[JacksonApp.CodeKey] as? Int,
            let state = note.userInfo?[JacksonApp.StateKey] as? Bool else {
            print("code or state missing")
                return
        }
        
        switch Int32(code) {
        case NX_KEYTYPE_PLAY:
            if state {
                togglePlayPause()  
            }
            
        case NX_KEYTYPE_NEXT:
            if state {} // Next pressed and released
            
        case NX_KEYTYPE_REWIND:
            if state {} //Previous pressed and released
            
        default:
            break
        }
    }
    
    // MARK: - TableViewDelegate
    
    @objc func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        let field: NSTextField = {
            if let view = tableView.makeView(withIdentifier: rowViewIdentifier,
                                             owner: self) as? NSTextField {
                return view
            }
            
            let view = NSTextField()
            view.isBordered = false
            view.identifier = rowViewIdentifier
            view.isEditable = false
            
            return view
        }()
        
        field.stringValue = playlist.songs[row].url.deletingPathExtension().lastPathComponent
        
        return field
    }
    
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }


    // MARK: - PlaylistDelegate
    
    func didUpdate(playlist: Playlist, position: Double) {
        progressBar.doubleValue = position
        if let stringTime = timeFormatter.string(from: position) {
            currentTime.stringValue = stringTime
        }
    }

    func didUpdate(playlist: Playlist, index: Int) {
        
        guard playlist.songs.count > 0 else {
            nextPlayer = nil
            player = nil
            return
        }
        
        if player == nil {
            player = avPlayerForSongIndex(index: index)
        }
        
        if playing {
            player?.play()
        }
        
        setNextPlayer()
        updateTableViewSelection()
    }
    
    func didUpdate(playlist: Playlist) {
        tableView.reloadData()
    }
    
    // MARK: - Actions
    
    @IBAction func openFileClicked(_ sender: NSMenuItem) {
        showFileBrowser()
    }
    
    @IBAction func showInFinderMenuInvoked(sender: NSMenuItem) {
        showCurrentSongInFinder()
    }
    
    @IBAction func playMenuInvoked(sender: NSMenuItem) {
        togglePlayPause()
    }

    @IBAction func loopMenuInvoked(sender: NSMenuItem) {
        toggleLoopCurrentSong()
    }

    @IBAction func playPauseClicked(button:NSButton) {
        togglePlayPause()
    }

    @IBAction func sliderClicked(sender: NSSlider) {
        player?.currentTime = sender.doubleValue
    }
        
    @IBAction func deleteBackward(sender: AnyObject?) {
        deleteSelectedSong()
    }
    
    @IBAction func volumeDown(sender: AnyObject?) {
        reduceVolume()
    }
    
    @IBAction func volumeUp(sender: AnyObject?) {
        increaseVolume()
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    @objc func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        advanceToNextSong()
    }
    
    // MARK: - Private
    
    @objc private func tableSelectionChanged(note: NSNotification) {
        let index = tableView.selectedRow
        
        if index == -1 {
            // empty space clicked.
            return
        }
        
        if index != playlist.index {
            player = nil
            playlist.index = index
        }
    }

    private func startPlayer() {
        if nil == player && playlist.songs.count > 0 {
            
            // We ensure that we start with a song we can play.
            var index = playlist.index

            if playlist.songs.count < index {
                index = 0
            }

            while player == nil && index < playlist.songs.count {
                player = avPlayerForSongIndex(index: index)
                index += 1
            }
            
            if index - 1 != playlist.index {
                playlist.index = index - 1
            }
            
            player?.play()
            updatePlayPause()
            
            setNextPlayer()
        }
    }
    
    private func setNextPlayer() {
        let index = looping ? playlist.index : playlist.nextIndex
        nextPlayer = avPlayerForSongIndex(index: index)
    }
    private func avPlayerForSongIndex(index: Int) -> AVAudioPlayer? {

        guard let result = try? AVAudioPlayer(contentsOf: playlist.songs[index].url) else {
            return nil
        }
        
        result.delegate = self
        result.prepareToPlay()
        result.volume = volume
        
        return result
    }

    private func advanceToNextSong() {

        player = nextPlayer
        
        if playing {
            player?.play()
        }
        
        if false == looping {
            playlist.advance()
        }
        
        showNotification()
    }
    
    func showNotification() -> Void {
        
        var artist:String?
        var title:String?
        
        let currentSong = playlist.songs[playlist.index]
        
        DispatchQueue.global().async {
            let playerItem = AVPlayerItem(url: currentSong.url)
            let metadataList = playerItem.asset.commonMetadata
            for item in metadataList {
                switch item.commonKey {
                case .some(.commonKeyTitle):
                    title = item.stringValue
                    
                case .some(.commonKeyArtist):
                    artist = item.stringValue
                    
                default:
                    break
                }
            }
            
            let notification = NSUserNotification()
            notification.title = "Now playing..."
            
            if let artistActual = artist,
                let titleActual = title {
                notification.informativeText = "\(artistActual) — \(titleActual)"
            }
            else {
                notification.informativeText = currentSong
                    .url
                    .deletingPathExtension()
                    .lastPathComponent
            }

            DispatchQueue.main.async {
                NSUserNotificationCenter.default.deliver(notification)
            }
        }
    }
    
    private func updatePlayPause() {
        if let player = player {
            var title = NSLocalizedString("Play", comment: "play button title")
            if player.isPlaying {
                title = NSLocalizedString("Pause", comment: "pause button title")
            }
            
            playPause.title = title
            playMenuItem.title = title
            playing = player.isPlaying
        }
    }
    
    private func deleteSelectedSong() {
        if tableView.selectedRow != -1 {
            player = nil
            playlist.delete(at: tableView.selectedRow)
        }
    }
    
    @objc private func updateDisplay() {
         if let player = player {
            playlist.position = player.currentTime
        }
    }
    
    private func togglePlayPause() {
        if let player = player {
            if player.isPlaying {
                player.pause()
            }
            else {
                player.play()
            }
            
            playing = player.isPlaying
        }
        updatePlayPause()        
    }
    
    private func toggleLoopCurrentSong() {
        looping.toggle()
    }
    
    private func showCurrentSongInFinder() {
        if playlist.songs.count < 1 { return }

        let item = playlist.songs[playlist.index]
        guard let path = item.url.absoluteString.removingPercentEncoding,
            let lastSlashIndex = path.lastIndex(of: "/") else {
            print("bad path")
            return
        }
        
        let root = String(path.prefix(through: lastSlashIndex))
        
        NSWorkspace.shared.openFile(root)
        if false == NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: root) {
            print("unable to select \(path), for some unknown reason, thanks Apple")
        }
    }
    
    private func reduceVolume() {
        
        if volume == 0 { return }
        
        var value = Int(volume * 100.0)
        
        // Yes, I am a bit nuts
        
        if value > 90 {
            value -= 1
        }
        else if value > 11 {
            value -= 10
        }
        else if value > 1 {
            value -= 1
        }
        
        volume = Float(value) / 100
    }
    
    private func increaseVolume() {
        
        if volume == 1 { return }
        
        var value = Int(volume * 100.0)

        // still crazy
        if value < 10 {
            value += 1
        }
        else if value < 90 {
            value += 10
        }
        else if value < 100 {
            value += 1
        }
        
        volume = Float(value) / 100
    }
    
    private func resetSongInfo() {
        totalTime.stringValue = ""
        currentTime.stringValue = ""
        progressBar.doubleValue = 0
        progressBar.maxValue = 0
        progressBar.isEnabled = false
    }
    
    private func showFileBrowser() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.begin { (result) in
            if result == NSApplication.ModalResponse.OK {
                let selectedFolder = panel.urls[0]
                self.player?.stop()
                self.player = nil
                self.resetSongInfo()
                self.playlist.deleteAll()
                self.playlist.addFrom(folder: selectedFolder)
            }
        }
    }
    
    private func updateTableViewSelection() {
        let index = playlist.index
        tableView.selectRowIndexes(IndexSet(integer: index),
                                   byExtendingSelection: false)
        tableView.scrollRowToVisible(index)
    }
}


