import Foundation

/// Stage 1 campaign model. Mirrors the Unity flow:
/// MainMenu -> MapLevels (world map) -> LevelSelection1 (level intro) -> ConfigurationUI (hero pick) -> MainLevel.
/// MVP: 3 level defs, only Level 1 unlocked. Progress persists in UserDefaults.
struct LevelDef: Identifiable, Codable {
    let id: Int
    let name: String
    let subtitle: String
    /// Name of the imported map art (without extension), e.g. "LevelSelectionBG".
    let mapArtName: String
    let enemyWaves: Int
    let towerHP: Int
    let baseHP: Int
}

struct CampaignData {
    static let levels: [LevelDef] = [
        LevelDef(id: 1, name: "Outpost Breach", subtitle: "First push — learn the lane",
                 mapArtName: "LevelSelectionBG", enemyWaves: 3, towerHP: 200, baseHP: 500),
        LevelDef(id: 2, name: "Hell Grounds", subtitle: "Hold the middle",
                 mapArtName: "MapBG", enemyWaves: 5, towerHP: 300, baseHP: 750),
        LevelDef(id: 3, name: "Core Assault", subtitle: "Break the enemy base",
                 mapArtName: "MapBG", enemyWaves: 8, towerHP: 400, baseHP: 1000),
    ]

    private static let unlockedKey = "campaign.unlockedLevel"
    private static let starsKeyPrefix = "campaign.stars.level."

    /// Highest level id the player may enter. Starts at 1.
    static var unlockedLevel: Int {
        get { max(1, UserDefaults.standard.integer(forKey: unlockedKey) == 0 ? 1 : UserDefaults.standard.integer(forKey: unlockedKey)) }
        set { UserDefaults.standard.set(min(newValue, levels.count), forKey: unlockedKey) }
    }

    static func isUnlocked(_ level: LevelDef) -> Bool { level.id <= unlockedLevel }

    static func stars(for levelId: Int) -> Int {
        UserDefaults.standard.integer(forKey: starsKeyPrefix + String(levelId))
    }

    static func awardStars(_ count: Int, for levelId: Int) {
        let key = starsKeyPrefix + String(levelId)
        let best = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(max(best, count), forKey: key)
        if levelId >= unlockedLevel { unlockedLevel = levelId + 1 }
    }

    static func reset() {
        UserDefaults.standard.set(1, forKey: unlockedKey)
        for level in levels {
            UserDefaults.standard.removeObject(forKey: starsKeyPrefix + String(level.id))
        }
    }
}

/// Hero roster ported from Unity's ConfigurationUI (Hero_icon1..6 + BigViews).
/// Art: Art/Imported/HeroIcons/*.png
struct HeroDef: Identifiable {
    let id: String
    let displayName: String
    /// Imported art basename, e.g. "Hero_icon1".
    let iconArtName: String
    let maxHealth: Int
    let speed: Double
    let blurb: String
}

struct HeroRoster {
    static let heroes: [HeroDef] = [
        HeroDef(id: "scout", displayName: "Scout", iconArtName: "Hero_icon1",
                maxHealth: 100, speed: 12, blurb: "Fast feet, light frame. Your Unity starting build."),
        HeroDef(id: "vanguard", displayName: "Vanguard", iconArtName: "Hero_Icon2",
                maxHealth: 140, speed: 10, blurb: "Balanced fighter for the first push."),
        HeroDef(id: "bulwark", displayName: "Bulwark", iconArtName: "Hero_Icon3",
                maxHealth: 180, speed: 8, blurb: "Slow tank. Holds the lane under tower fire."),
        HeroDef(id: "ranger", displayName: "Ranger", iconArtName: "Hero_icon4",
                maxHealth: 110, speed: 11, blurb: "Gun-ready skirmisher."),
        HeroDef(id: "saboteur", displayName: "Saboteur", iconArtName: "Hero_icon5",
                maxHealth: 120, speed: 11, blurb: "Tower-killer. Bonus vs structures (stage 2)."),
        HeroDef(id: "warlord", displayName: "Warlord", iconArtName: "Hero_Icon6",
                maxHealth: 200, speed: 9, blurb: "Late-campaign bruiser. Locked feel for now, playable in MVP."),
    ]

    private static let selectedKey = "campaign.selectedHero"

    static var selectedHeroId: String {
        get { UserDefaults.standard.string(forKey: selectedKey) ?? heroes[0].id }
        set { UserDefaults.standard.set(newValue, forKey: selectedKey) }
    }

    static var selectedHero: HeroDef {
        heroes.first(where: { $0.id == selectedHeroId }) ?? heroes[0]
    }
}
