//
//  MediaItem_+CoreDataProperties.swift
//  
//
//  Created by Bob on 2018/12/18.
//
//

import Foundation
import CoreData


extension MediaItem_ {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MediaItem_> {
        return NSFetchRequest<MediaItem_>(entityName: "MediaItem_")
    }

    @NSManaged public var albumPersistentID: String?
    @NSManaged public var albumTitle: String?
    @NSManaged public var artist: String?
    @NSManaged public var artistPersistentID: String?
    @NSManaged public var duration: Double
    @NSManaged public var fileURL: String?
    @NSManaged public var genre: String?
    @NSManaged public var genrePersistentID: String?
    @NSManaged public var mediaType: Int64
    @NSManaged public var mpPersistentID: String?
    @NSManaged public var persistentID: String?
    @NSManaged public var title: String?
    @NSManaged public var trackNumber: Int64
    @NSManaged public var fromCollection: MediaCollection_?
    @NSManaged public var representedCollection: MediaCollection_?

}
