//
//  Holophonor+Accessors.swift
//  Pods
//
//  Created by bob.sun on 25/05/2017.
//
//

import Foundation

import MediaPlayer
import CoreData
import AVFoundation

extension Holophonor {
    public func getAllSongs() -> [MediaItem] {
        var ret: [MediaItem] = []
        let req = NSFetchRequest<MediaItem>(entityName: "MediaItem")
        req.predicate = NSPredicate(format: "(mediaType == %llu) OR (mediaType == %llu)", MediaSource.iTunes.rawValue, MediaSource.Local.rawValue)
        do {
            let result = try context.execute(req) as! NSAsynchronousFetchResult<MediaItem>
            ret = result.finalResult ?? []
            #if DEBUG
                print("-----Scanned \(ret.count) songs -----")
            #endif
        } catch let e {
            print(e)
        }
        return ret
    }
    
    public func getAllAlbums() -> [MediaCollection] {
        var ret: [MediaCollection] = []
        let req = NSFetchRequest<MediaCollection>(entityName: "MediaCollection")
        let filter = NSPredicate(format: "collectionType == %llu ", CollectionType.Album.rawValue)
        req.predicate = filter
        do {
            let result = try context.execute(req) as! NSAsynchronousFetchResult<MediaCollection>
            ret = result.finalResult ?? []
            #if DEBUG
                print("-----Scanned \(ret.count) albums -----")
            #endif
        } catch {
            
        }
        return ret
    }
    
    public func getAllArtists() -> [MediaCollection] {
        var ret: [MediaCollection] = []
        let req = NSFetchRequest<MediaCollection>(entityName: "MediaCollection")
        let filter = NSPredicate(format: "collectionType == %llu ", CollectionType.Artist.rawValue)
        req.predicate = filter
        do {
            let result = try context.execute(req) as! NSAsynchronousFetchResult<MediaCollection>
            ret = result.finalResult ?? []
            #if DEBUG
                print("-----Scanned \(ret.count) artists -----")
            #endif
        } catch {
            
        }
        return ret
    }
    
    public func getAllGenres() -> [MediaCollection] {
        var ret: [MediaCollection] = []
        let req = NSFetchRequest<MediaCollection>(entityName: "MediaCollection")
        let filter = NSPredicate(format: "collectionType == %llu", CollectionType.Genre.rawValue)
        req.predicate = filter
        do {
            let result = try context.execute(req) as! NSAsynchronousFetchResult<MediaCollection>
            ret = result.finalResult ?? []
        } catch  {
            print(error)
        }
        return ret
    }
    
    public func getGenreBy(name: String) -> MediaCollection? {
        var ret: MediaCollection? = nil
        let req = NSFetchRequest<MediaCollection>(entityName: "MediaCollection")
        let filter = NSPredicate(format: "(collectionType == %llu) AND ()", CollectionType.Genre.rawValue)
        req.predicate = filter
        do {
            let result = try context.execute(req) as! NSAsynchronousFetchResult<MediaCollection>
            ret = result.finalResult?.first
        } catch {
            print(error)
        }
        return ret
    }
    
    public func getAlbumBy(name: String) -> MediaCollection? {
        var ret: MediaCollection? = nil
        let req = NSFetchRequest<MediaCollection>(entityName: "MediaCollection")
        let filter = NSPredicate(format: "(collectionType == %llu) AND (representativeTitle == %@) ",
                                 CollectionType.Album.rawValue,
                                 name)
        req.predicate = filter
        do {
            let result = try context.execute(req) as! NSAsynchronousFetchResult<MediaCollection>
            ret = result.finalResult?.first
        } catch {
            
        }
        return ret
    }
    
    public func getAlbumBy(artist: String, name: String) -> MediaCollection? {
        var ret: MediaCollection? = nil
        let req = NSFetchRequest<MediaCollection>(entityName: "MediaCollection")
        let filter = NSPredicate(format: "(collectionType == %llu) AND (representativeTitle == %@) AND (representativeItem.artist == %@)", CollectionType.Album.rawValue, name, artist)
        req.predicate = filter
        do {
            let result = try context.execute(req) as! NSAsynchronousFetchResult<MediaCollection>
            ret = result.finalResult?.first
        } catch  {
            
        }
        return ret
    }
    
    public func getAlbumBy(identifier: String) -> MediaCollection? {
        var ret: MediaCollection? = nil
        let req = NSFetchRequest<MediaCollection>(entityName: "MediaCollection")
        let filter = NSPredicate(format: "(collectionType == %llu) AND (persistentID == %@)", CollectionType.Album.rawValue, identifier)
        req.predicate = filter
        do {
            let result = try context.execute(req) as! NSAsynchronousFetchResult<MediaCollection>
            ret = result.finalResult?.first
        } catch {
            print(error)
        }
        return ret
    }
    
    public func getAlbumsBy(artist: String) -> [MediaCollection] {
        var ret: [MediaCollection] = []
        let req = NSFetchRequest<MediaCollection>(entityName: "MediaCollection")
        req.predicate = NSPredicate(format: "(collectionType == %llu) AND (ANY representativeItem.artist == %@)",
                                    CollectionType.Album.rawValue,
                                    artist)
        context.performAndWait {
            do {
                let result = try context.execute(req) as! NSAsynchronousFetchResult<MediaCollection>
                ret = result.finalResult ?? []
            } catch  {
                #if DEBUG
                    print(error)
                #endif
            }
        }
        return ret
    }
    
    public func getArtistsBy(genre: String) -> [MediaCollection] {
        var ret: [MediaCollection] = []
        let req = NSFetchRequest<MediaCollection>(entityName: "MediaCollection")
        req.predicate = NSPredicate(format: "(collectionType == %llu) AND (ANY representativeItem.genre == %@)",
                                    CollectionType.Artist.rawValue,
                                    genre)
        do {
            let result = try context.execute(req) as! NSAsynchronousFetchResult<MediaCollection>
            ret = result.finalResult ?? []
        } catch {
            print(error)
        }
        return ret;
    }
    public func getAlbumsBy(genre: String) -> [MediaCollection] {
        var ret: [MediaCollection] = []
        let req = NSFetchRequest<MediaCollection>(entityName: "MediaCollection")
        req.predicate = NSPredicate(format: "(collectionType == %llu) AND (ANY representativeItem.genre == %@)",
                                    CollectionType.Album.rawValue,
                                    genre)
        do {
            let result = try context.execute(req) as! NSAsynchronousFetchResult<MediaCollection>
            ret = result.finalResult ?? []
        } catch {
            print(error)
        }
        return ret;
    }
}
