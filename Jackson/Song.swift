//
//  Song.swift
//  Jackson
//
//  Created by Alan Westbrook on 7/12/18.
//  Copyright © 2018 rockwood. All rights reserved.
//

import Foundation
import AudioToolbox


// MARK: Model Item
struct Song : CustomStringConvertible, Comparable, Hashable {
    var url:URL
    var track:Int?
    var album:String?
    
    var description:String {
        get {
            let trackStr = track == nil ? "no track data"
                : String(describing: track)
            
            return "\(url.lastPathComponent) / \(trackStr) / \(album ?? "no album data")"
        }
    }
    
    var hashValue: Int {
        get {
            return pPath.hashValue
        }
    }
    
    init(url: URL) {
        self.url = url
        
        var fileID:AudioFileID? = nil
        //let url = NSURL(fileURLWithPath: path) as CFURL
        AudioFileOpenURL(url as CFURL, .readPermission, AudioFileTypeID(0), &fileID)
        
        if fileID != nil {
            var dict:CFDictionary = [:] as CFDictionary
            var piDataSize:UInt32 = UInt32(MemoryLayout<CFDictionary.Type>.size)
            
            //  Populates a CFDictionary with the ID3 tag properties
            _ = AudioFileGetProperty(fileID!, AudioFilePropertyID(kAudioFilePropertyInfoDictionary), &piDataSize, &dict)
            
            let info = dict as! Dictionary<String, String>
            
            if let trackFuckery = info[kAFInfoDictionary_TrackNumber] {
                let trackInfo = trackFuckery.components(separatedBy: "/")
                track = Int(trackInfo[0])
            }
            
            album = info[kAFInfoDictionary_Album]
        }
    }
}

func ==(lhs:Song, rhs:Song) -> Bool {
    return lhs.url == rhs.url &&
        lhs.track == rhs.track &&
        lhs.album == lhs.album
}

func tagSorting(_ lhs: Song, _ rhs: Song) -> Bool? {
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
            else if rhs.track != nil {
                return false
            }
            else {
                return aLeft < aRight
            }
        }
    }
    else if rhs.album != nil {
        return false
    }
    
    return nil
}

func <(lhs:Song, rhs:Song) -> Bool {
    if JacksonViewController.hasTagOrganization {
        if let sortOrder = tagSorting(lhs, rhs) {
            return sortOrder
        }
    }
    
    return lhs.url.lastPathComponent < rhs.url.lastPathComponent
}
