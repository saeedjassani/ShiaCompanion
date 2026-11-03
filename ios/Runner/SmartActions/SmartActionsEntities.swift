import AppIntents
import CoreSpotlight
import CryptoKit
import Foundation
import UniformTypeIdentifiers

// What Siri, Shortcuts and Spotlight can name: the reader's playlists, the
// duas with a recitation (for playing), and every zikr (for opening). All
// three are read from the catalog Dart keeps in the app group, so a query
// works while the app - and Dart - is not running.

@available(iOS 17.0, *)
struct PlaylistEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Playlist"
    static var defaultQuery = PlaylistEntityQuery()

    let id: String
    let name: String
    let subtitle: String?

    init(_ playlist: CatalogPlaylist) {
        id = playlist.id
        name = playlist.name
        subtitle = playlist.subtitle
    }

    var displayRepresentation: DisplayRepresentation {
        if let subtitle {
            return DisplayRepresentation(title: "\(name)", subtitle: "\(subtitle)")
        }
        return DisplayRepresentation(title: "\(name)")
    }
}

@available(iOS 17.0, *)
struct PlaylistEntityQuery: EntityStringQuery {
    func entities(for identifiers: [PlaylistEntity.ID]) async throws -> [PlaylistEntity] {
        let playlists = SmartActionsCatalog.playlists()
        return identifiers.compactMap { id in
            playlists.first { $0.id == id }.map(PlaylistEntity.init)
        }
    }

    func entities(matching string: String) async throws -> [PlaylistEntity] {
        SmartActionsCatalog.playlists()
            .filter { SmartActionsCatalog.matches(string, [$0.name, $0.subtitle ?? ""]) }
            .map(PlaylistEntity.init)
    }

    func suggestedEntities() async throws -> [PlaylistEntity] {
        SmartActionsCatalog.playlists().map(PlaylistEntity.init)
    }
}

/// A dua, ziyarat or surah with a recitation, by content uid - the same
/// recitation under two titles (an alias) is one entity.
@available(iOS 17.0, *)
struct RecitationEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Recitation"
    static var defaultQuery = RecitationEntityQuery()

    let id: String
    let name: String
    let subtitle: String?

    init(_ zikr: CatalogZikr) {
        id = zikr.uid
        name = zikr.name
        subtitle = zikr.subtitle
    }

    var displayRepresentation: DisplayRepresentation {
        if let subtitle {
            return DisplayRepresentation(title: "\(name)", subtitle: "\(subtitle)")
        }
        return DisplayRepresentation(title: "\(name)")
    }

    /// One zikr per recitation, the canonical entry rather than an alias.
    static func all() -> [CatalogZikr] {
        var byUid: [String: CatalogZikr] = [:]
        var order: [String] = []
        for zikr in SmartActionsCatalog.zikrs() where zikr.audio {
            if let existing = byUid[zikr.uid] {
                if existing.id != existing.uid && zikr.id == zikr.uid { byUid[zikr.uid] = zikr }
            } else {
                byUid[zikr.uid] = zikr
                order.append(zikr.uid)
            }
        }
        return order.compactMap { byUid[$0] }
    }
}

@available(iOS 17.0, *)
struct RecitationEntityQuery: EntityStringQuery {
    func entities(for identifiers: [RecitationEntity.ID]) async throws -> [RecitationEntity] {
        let zikrs = RecitationEntity.all()
        return identifiers.compactMap { id in
            zikrs.first { $0.uid == id }.map(RecitationEntity.init)
        }
    }

    func entities(matching string: String) async throws -> [RecitationEntity] {
        SmartActionsCatalog.zikrs()
            .filter { $0.audio }
            .filter { SmartActionsCatalog.matches(string, [$0.name, $0.subtitle ?? ""] + $0.keywords) }
            .reduce(into: [CatalogZikr]()) { found, zikr in
                if !found.contains(where: { $0.uid == zikr.uid }) { found.append(zikr) }
            }
            .map(RecitationEntity.init)
    }

    /// What Siri's "Play … in Shia Companion" listens for.
    func suggestedEntities() async throws -> [RecitationEntity] {
        RecitationEntity.all().map(RecitationEntity.init)
    }
}

/// Any zikr, recitation or not, by its `zikr.json` key: what "Open Dua"
/// opens.
@available(iOS 17.0, *)
struct ZikrEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Dua"
    static var defaultQuery = ZikrEntityQuery()

    let id: String
    let name: String
    let subtitle: String?
    let link: String
    let keywords: [String]

    init(_ zikr: CatalogZikr) {
        id = zikr.id
        name = zikr.name
        subtitle = zikr.subtitle
        link = zikr.link
        keywords = zikr.keywords
    }

    var displayRepresentation: DisplayRepresentation {
        if let subtitle {
            return DisplayRepresentation(title: "\(name)", subtitle: "\(subtitle)")
        }
        return DisplayRepresentation(title: "\(name)")
    }
}

@available(iOS 17.0, *)
struct ZikrEntityQuery: EntityStringQuery {
    func entities(for identifiers: [ZikrEntity.ID]) async throws -> [ZikrEntity] {
        let zikrs = SmartActionsCatalog.zikrs()
        return identifiers.compactMap { id in
            zikrs.first { $0.id == id }.map(ZikrEntity.init)
        }
    }

    func entities(matching string: String) async throws -> [ZikrEntity] {
        SmartActionsCatalog.zikrs()
            .filter { SmartActionsCatalog.matches(string, [$0.name, $0.subtitle ?? ""] + $0.keywords) }
            .map(ZikrEntity.init)
    }

    func suggestedEntities() async throws -> [ZikrEntity] {
        RecitationEntity.all().map(ZikrEntity.init)
    }
}

/// Spotlight: typing "Kumayl" on the home screen finds the dua, and tapping
/// it opens it (`SmartActionsBridge.continueUserActivity`).
///
/// Plain Core Spotlight items, not app entities (`IndexedEntity`): those
/// need iOS 18, and a tap on one reached the app as a search-result user
/// activity that nothing handled, so it only opened Home. These work on
/// every iOS the app runs on, and each item's identifier is the zikr's
/// `zikr.json` key, which the tap hands back.
enum SmartActionsSpotlight {
    /// Digest of the zikr catalog last indexed, so an unchanged one - every
    /// launch but those after an update or a language change - costs nothing.
    private static let indexedDigestKey = "sc_smart_spotlight_digest"
    /// Part of the digest, so a change to how items are built re-indexes an
    /// unchanged catalog too. Bump it with any such change.
    private static let indexFormat = "searchable-items-1"
    private static let domainIdentifier = "zikr"

    static func indexIfChanged() async {
        guard let raw = SmartActionsCatalog.rawZikrs else { return }
        let digest = SHA256.hash(data: Data((indexFormat + raw).utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        if UserDefaults.standard.string(forKey: indexedDigestKey) == digest { return }

        let items = SmartActionsCatalog.zikrs().map(searchableItem)
        do {
            let index = CSSearchableIndex.default()
            // Starts over, so a zikr since removed or retitled leaves nothing
            // stale behind - nor the app entities an earlier build indexed.
            // The app indexes nothing else.
            try await index.deleteAllSearchableItems()
            try await index.indexSearchableItems(items)
            UserDefaults.standard.set(digest, forKey: indexedDigestKey)
        } catch {
            NSLog("Spotlight indexing failed: \(error)")
        }
    }

    private static func searchableItem(_ zikr: CatalogZikr) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: UTType.text)
        attributes.title = zikr.name
        attributes.displayName = zikr.name
        // The title in the reader's zikr language, which can be searched too.
        attributes.contentDescription = zikr.subtitle
        attributes.keywords = zikr.keywords + [zikr.subtitle].compactMap { $0 }
        let item = CSSearchableItem(
            uniqueIdentifier: zikr.id,
            domainIdentifier: domainIdentifier,
            attributeSet: attributes
        )
        // Items otherwise expire after a month, and an unchanged catalog is
        // never indexed again.
        item.expirationDate = .distantFuture
        return item
    }

    /// The zikr a tapped Spotlight result stands for, if it is one of ours.
    static func zikr(for activity: NSUserActivity) -> CatalogZikr? {
        guard activity.activityType == CSSearchableItemActionType,
              let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
        else { return nil }
        return SmartActionsCatalog.zikrs().first { $0.id == id }
    }
}
