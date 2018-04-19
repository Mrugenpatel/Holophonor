import Foundation

import MediaPlayer
import CoreData
import AVFoundation

open class Holophonor: NSObject {
    
    var authorized: Bool
    var localDirectories: [String] = []
    var context: NSManagedObjectContext
    var coordinator: NSPersistentStoreCoordinator
    var holophonorQueue: DispatchQueue
    
    public static let instance : Holophonor = {
        let ret = Holophonor()
        return ret
    }()
    
    convenience override init() {
        self.init(dbName: "Holophonor.sqlite")
    }
    
    public init(dbName: String) {
        if #available(iOS 9.3, *) {
            authorized = MPMediaLibrary.authorizationStatus() == .authorized ||
                MPMediaLibrary.authorizationStatus() == .restricted
        } else {
            authorized = true
        }
        
        let url = Bundle(for: Holophonor.self).url(forResource: "Holophonor", withExtension: "momd")
        var storeUrl: String
        #if DEBUG
            storeUrl = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first as String!
        #else
            storeUrl = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first as String!
        #endif
        storeUrl = storeUrl.appending("/" + dbName)
        let mom = NSManagedObjectModel(contentsOf: url!)
        
        coordinator = NSPersistentStoreCoordinator(managedObjectModel: mom!)
        do {
            try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: URL(fileURLWithPath: storeUrl), options: nil)
        } catch let e {
            print(e)
        }
        
        context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        holophonorQueue = DispatchQueue(label: "holophonor_queue" )
        super.init()
    }
    
    open func addLocalDirectory(dir: String) -> Holophonor {
        localDirectories.append(dir)
        return self
    }
    
    open func rescan(_ force: Bool = false, complition: @escaping () -> Void) {
        if !authorized {
            if #available(iOS 9.3, *) {
                MPMediaLibrary.requestAuthorization({ (result) in
                    self.authorized = result == .authorized || result == .restricted
                    self.reloadIfNeeded(force, complition: complition)
                })
            } else {
                self.reloadIfNeeded(force, complition: complition)
            }
        } else {
            self.reloadIfNeeded(force, complition: complition)
        }
    }
    
    func reloadIfNeeded(_ force: Bool = false, complition: @escaping () -> Void) {
        self.holophonorQueue.async {
            let _ = MPMediaLibrary.default().lastModifiedDate
                self.reloadiTunes()
                self.reloadLocal()
                DispatchQueue.main.sync {
                    complition()
            }
        }
    }
    
    fileprivate func reloadiTunes() {
        let songs = MPMediaQuery.songs().items ?? []
        if songs.count > 0 {
            self.dropAll()
        }
        for song in songs {
            
            let entity = NSEntityDescription.entity(forEntityName: "MediaItem", in: context)
            var insert: MediaItem? = nil
            self.context.performAndWait {
                insert = MediaItem(entity: entity!, insertInto: context)
                insert?.title = song.title
                insert?.albumTitle = song.albumTitle
                insert?.artist = song.artist ?? "Unknown Artist"
                insert?.genre = song.genre ?? "Unknown Genre"
                insert?.fileURL = song.assetURL?.absoluteString
                insert?.mpPersistentID = "\(song.persistentID.littleEndian)"
                insert?.mediaType = MediaSource.iTunes.rawValue
                insert?.persistentID = UUID().uuidString
            }
            
            
            addCollectionFromiTunesSong(item: song, wrapped: insert!)
        }
    
    
        do {
            try self.context.save()
        } catch let e {
            #if DEBUG
            print("----Can not save----")
            print(e)
            #endif
        }
        return
    }
    
    fileprivate func addCollectionFromiTunesSong(item: MPMediaItem, wrapped: MediaItem) {
        //Album
        let albumReq = NSFetchRequest<MediaCollection>(entityName: "MediaCollection")
        albumReq.predicate = NSPredicate(format: "(representativeTitle == %@) AND (representativeItem.artist == %@) AND (collectionType == %llu)",
                                         item.albumTitle ?? "",
                                         item.artist ?? "",
                                         CollectionType.Album.rawValue)
        albumReq.includesPendingChanges = true;
        var album: MediaCollection? = nil
        var artist: MediaCollection? = nil
        var genre: MediaCollection? = nil
        do {
            var result: [MediaCollection] = []
            result = try self.context.fetch(albumReq)
            if result.count == 0 {
                //ADD
                let entityCollection = NSEntityDescription.entity(forEntityName: "MediaCollection", in: self.context)
                let entityItem = NSEntityDescription.entity(forEntityName: "MediaItem", in: self.context)
                self.context.performAndWait {
                    let repItem = MediaItem(entity: entityItem!, insertInto: self.context)
                    repItem.albumPersistentID = "\(item.albumPersistentID.littleEndian)"
                    repItem.albumTitle = item.albumTitle
                    repItem.title = ""
                    repItem.artistPersistentID = "\(item.albumArtistPersistentID.littleEndian)"
                    repItem.artist = item.artist
                    repItem.genre = item.genre
                    repItem.genrePersistentID = "\(item.genrePersistentID.littleEndian)"
                    repItem.mediaType = MediaSource.Representative.rawValue
                    repItem.persistentID = UUID().uuidString
                    
                    let toAdd = MediaCollection(entity: entityCollection!, insertInto: self.context)
                    toAdd.persistentID = UUID().uuidString
                    toAdd.mpPersistenceID = "\(item.albumPersistentID.littleEndian)"
                    toAdd.representativeItem = repItem
                    toAdd.representativeTitle = item.albumTitle
                    toAdd.addToItems(wrapped)
                    toAdd.collectionType = CollectionType.Album.rawValue
                    album = toAdd
                }
            } else {
                //APPEND
                album = result.first!
                if album?.mpPersistenceID == nil {
                    album?.mpPersistenceID = "\(item.albumPersistentID.littleEndian)"
                }
                self.context.performAndWait {
                    album?.addToItems(wrapped)
                }
            }
        } catch {
            #if DEBUG
            print("----Can not save album collection----")
            #endif
        }
        
        //Artist
        let artistReq = NSFetchRequest<MediaCollection>(entityName: "MediaCollection")
        artistReq.includesPendingChanges = true;
        artistReq.predicate = NSPredicate(format: "(representativeTitle == %@) AND (collectionType == %llu)", item.artist ?? "Unknown Artist", CollectionType.Artist.rawValue)
        do {
            var result: [MediaCollection] = []
            result = try self.context.fetch(artistReq)
            if result.count == 0 {
                let entityCollection = NSEntityDescription.entity(forEntityName: "MediaCollection", in: self.context)
                let entityItem = NSEntityDescription.entity(forEntityName: "MediaItem", in: self.context)
                self.context.performAndWait {
                    let repItem = MediaItem(entity: entityItem!, insertInto: self.context)
                    repItem.artistPersistentID = "\(item.albumArtistPersistentID.littleEndian)"
                    repItem.artist = item.artist
                    repItem.mediaType = MediaSource.Representative.rawValue
                    repItem.persistentID = UUID().uuidString
                    
                    let toAdd = MediaCollection(entity: entityCollection!, insertInto: self.context)
                    toAdd.mpPersistenceID = "\(item.artistPersistentID.littleEndian)"
                    toAdd.representativeItem = repItem
                    toAdd.representativeTitle = item.artist
                    toAdd.collectionType = CollectionType.Artist.rawValue
                    toAdd.persistentID = UUID().uuidString
                    toAdd.addToItems((album?.representativeItem!)!)
                    artist = toAdd
                }
            } else {
                artist = result.first!
                self.context.performAndWait {
                    artist?.addToItems((album?.representativeItem!)!)
                }
                if artist?.mpPersistenceID == nil {
                    artist?.mpPersistenceID = "\(item.artistPersistentID.littleEndian)"
                }
            }
            self.context.performAndWait {
                artist?.addToItems(wrapped)
            }
        } catch {
            #if DEBUG
            print("----Can not save artist collection----")
            #endif
        }
        
        //Genre
        let genreReq = NSFetchRequest<MediaCollection>(entityName: "MediaCollection")
        genreReq.includesPendingChanges = true;
        genreReq.predicate = NSPredicate(format: "(representativeTitle == %@) AND (collectionType == %llu)", item.genre ?? "Unkown Genre", CollectionType.Genre.rawValue)
        do {
            var result: [MediaCollection] = []
            result = try self.context.fetch(genreReq)
            if result.count == 0 {
                let entityCollection = NSEntityDescription.entity(forEntityName: "MediaCollection", in: self.context)
                let entityItem = NSEntityDescription.entity(forEntityName: "MediaItem", in: self.context)
                
                let repItem = MediaItem(entity: entityItem!, insertInto: self.context)
                repItem.genrePersistentID = "\(item.genrePersistentID.littleEndian)"
                repItem.genre = item.genre
                repItem.mediaType = MediaSource.Representative.rawValue
                repItem.persistentID = UUID().uuidString
                
                let toAdd = MediaCollection(entity: entityCollection!, insertInto: self.context)
                toAdd.mpPersistenceID = "\(item.genrePersistentID.littleEndian)"
                toAdd.representativeItem = repItem
                toAdd.representativeTitle = item.genre
                toAdd.collectionType = CollectionType.Genre.rawValue
                toAdd.persistentID = UUID().uuidString
            
                
                toAdd.addToItems((album?.representativeItem!)!)
                toAdd.addToItems((artist?.representativeItem!)!)
                genre = toAdd
            } else {
                genre = result.first!
                genre?.addToItems((album?.representativeItem!)!)
                genre?.addToItems((artist?.representativeItem!)!)
                if genre?.mpPersistenceID == nil {
                    genre?.mpPersistenceID = "\(item.genrePersistentID.littleEndian)"
                }
            }
        } catch {
            #if DEBUG
            print("----Can not save genre collection----")
            #endif
        }
        
        wrapped.albumPersistentID = album?.persistentID
        wrapped.artistPersistentID = artist?.persistentID
        wrapped.genrePersistentID = genre?.persistentID
    }
    
    
    fileprivate func reloadLocal() {
        let fm = FileManager.default
        for dir in localDirectories {
            let files: [String]
            do {
                try files = fm.contentsOfDirectory(atPath: dir)
            } catch {
                continue
            }
            for file in files {
                if file.hasSuffix("m4a") || file.hasSuffix("mp3") || file.hasSuffix("wav") {
                    addItemFromFile(path: dir + "/" + file)
                }
            }
        }
    
        do {
            try self.context.save()
        } catch let e {
            print("----Can not save----")
            print(e)
        }
    }
    
    fileprivate func addItemFromFile(path: String) {
        let asset: AVAsset = AVAsset(url: URL(fileURLWithPath: path))
        let entity = NSEntityDescription.entity(forEntityName: "MediaItem", in: context)
        let insert = MediaItem(entity: entity!, insertInto: context)
        insert.mediaType = MediaSource.Local.rawValue
        insert.fileURL = URL(fileURLWithPath: path).absoluteString
        
        let fmts = asset.availableMetadataFormats
        for fmt in fmts {
            let values = asset.metadata(forFormat: fmt)
            for value in values {
                if (value.commonKey == nil) {
                    continue
                } else {
                    let commonKey = value.commonKey!
                    switch commonKey {
                    case AVMetadataKey.commonKeyTitle:
                        insert.title = value.stringValue
                        break
                    case AVMetadataKey.commonKeyAlbumName:
                        insert.albumTitle = value.stringValue
                        break
                    case AVMetadataKey.commonKeyArtist:
                        insert.artist = value.stringValue
                        break
                    case AVMetadataKey.commonKeyType:
                        insert.genre = value.stringValue
                    default:
                        break
                    }
                }
            }
        }
        insert.persistentID = UUID().uuidString
        addCollectionFromLocalSong(item: insert)
    }
    
    fileprivate func addCollectionFromLocalSong(item: MediaItem) {
        //Album
        let albumReq = NSFetchRequest<MediaCollection>(entityName: "MediaCollection")
        albumReq.includesPendingChanges = true;
        albumReq.predicate = NSPredicate(format: "(representativeTitle == %@) AND (representativeItem.artist == %@) AND (collectionType == %llu)",
                                         item.albumTitle ?? "",
                                         item.artist ?? "",
                                         CollectionType.Album.rawValue)
        var album: MediaCollection? = nil
        var artist: MediaCollection? = nil
        var genre: MediaCollection? = nil
        do {
            var result: [MediaCollection] = []
            result = try self.context.fetch(albumReq)
            if result.count == 0 {
                //ADD
                let entityCollection = NSEntityDescription.entity(forEntityName: "MediaCollection", in: self.context)
                let entityItem = NSEntityDescription.entity(forEntityName: "MediaItem", in: self.context)
                
                let repItem = MediaItem(entity: entityItem!, insertInto: self.context)
                repItem.albumTitle = item.albumTitle
                repItem.artist = item.artist
                repItem.genre = item.genre
                repItem.mediaType = MediaSource.Representative.rawValue
                repItem.persistentID = UUID().uuidString
                
                let toAdd = MediaCollection(entity: entityCollection!, insertInto: self.context)
                toAdd.representativeItem = repItem
                toAdd.representativeTitle = item.albumTitle
                toAdd.addToItems(item)
                toAdd.collectionType = CollectionType.Album.rawValue
                toAdd.persistentID = UUID().uuidString
                album = toAdd
            } else {
                //APPEND
                album = result.first!
                album?.addToItems(item)
            }
            
        } catch {
            #if DEBUG
            print("----Can not save album collection for localfile----")
            #endif
        }
        
        //Artist
        let artistReq = NSFetchRequest<MediaCollection>(entityName: "MediaCollection")
        artistReq.includesPendingChanges = true;
        artistReq.predicate = NSPredicate(format: "(representativeTitle == %@) AND (collectionType == %llu)", item.artist!, CollectionType.Artist.rawValue)

        do {
            var result: [MediaCollection] = []
            result = try self.context.fetch(artistReq)
            if result.count == 0 {
                let entityCollection = NSEntityDescription.entity(forEntityName: "MediaCollection", in: self.context)
                let entityItem = NSEntityDescription.entity(forEntityName: "MediaItem", in: self.context)
                
                let repItem = MediaItem(entity: entityItem!, insertInto: self.context)
                repItem.artist = item.artist
                repItem.mediaType = MediaSource.Representative.rawValue
                repItem.persistentID = UUID().uuidString
                
                let toAdd = MediaCollection(entity: entityCollection!, insertInto: self.context)
                toAdd.representativeTitle = item.artist
                toAdd.representativeItem = repItem
                toAdd.representativeTitle = item.artist
                toAdd.collectionType = CollectionType.Artist.rawValue
                toAdd.persistentID = UUID().uuidString
                toAdd.addToItems((album?.representativeItem!)!)
                artist = toAdd
            } else {
                artist = result.first!
                artist?.addToItems((album?.representativeItem)!)
            }

        } catch {
            #if DEBUG
            print("----Can not save artist collection----")
            #endif
        }
        
        //Genre
        let genreReq = NSFetchRequest<MediaCollection>(entityName: "MediaCollection")
        genreReq.includesPendingChanges = true;
        genreReq.predicate = NSPredicate(format: "(representativeTitle == %@) AND (collectionType == %llu)", item.genre ?? "Unkown Genre", CollectionType.Genre.rawValue)
        
        do {
            var result: [MediaCollection] = []
            result = try self.context.fetch(genreReq)
            if result.count == 0 {
                let entityCollection = NSEntityDescription.entity(forEntityName: "MediaCollection", in: self.context)
                let entityItem = NSEntityDescription.entity(forEntityName: "MediaItem", in: self.context)
                let repItem = MediaItem(entity: entityItem!, insertInto: self.context)
                repItem.genre = item.genre
                repItem.mediaType = MediaSource.Representative.rawValue
                repItem.persistentID = UUID().uuidString
                
                let toAdd = MediaCollection(entity: entityCollection!, insertInto: self.context)
                toAdd.representativeTitle = item.genre
                toAdd.representativeItem = repItem
                toAdd.representativeTitle = item.genre
                toAdd.collectionType = CollectionType.Genre.rawValue
                toAdd.persistentID = UUID().uuidString
                toAdd.addToItems((album?.representativeItem!)!)
                genre = toAdd
            } else {
                genre = result.first!
                genre?.addToItems((album?.representativeItem!)!)
                genre?.addToItems((artist?.representativeItem!)!)
            }
            
        } catch {
            print("----Can not save genre collection----")
        }
        item.albumPersistentID = album?.persistentID
        item.artistPersistentID = artist?.persistentID
        item.genrePersistentID = genre?.persistentID
    }
    
    fileprivate func dropAll() {
        let fetchItem = NSFetchRequest<MediaItem>(entityName: "MediaItem")
        let fetchCollection = NSFetchRequest<MediaCollection>(entityName: "MediaCollection")
        do {
            let items = try self.context.fetch(fetchItem)
            let collections = try self.context.fetch(fetchCollection)
            
            for item in items {
                self.context.delete(item)
            }
            
            for collect in collections {
                self.context.delete(collect)
            }
            try self.context.save()
        } catch {
            print("----Can not drop----")
        }
    }

}
