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
    /// The 15-region takeback of Emra, west → east: verdant woods give way
    /// to dunes, then volcanic wastes, then frost, then the umbral core.
    /// Castles punctuate each biome (ids 3 / 6 / 9 / 11 / 15).
    static let levels: [LevelDef] = [
        LevelDef(id: 1, name: "Verdant Landing", subtitle: "First push — learn the lane",
                 mapArtName: "LevelSelectionBG", enemyWaves: 3, towerHP: 200, baseHP: 500),
        LevelDef(id: 2, name: "Rootwall Thicket", subtitle: "Pincer through the pines",
                 mapArtName: "MapBG", enemyWaves: 4, towerHP: 220, baseHP: 550),
        LevelDef(id: 3, name: "Thornwood Bastion", subtitle: "Storm the timber castle",
                 mapArtName: "MapBG", enemyWaves: 5, towerHP: 250, baseHP: 600),
        LevelDef(id: 4, name: "Dune Atoll", subtitle: "Cross the white sands",
                 mapArtName: "MapBG", enemyWaves: 5, towerHP: 260, baseHP: 650),
        LevelDef(id: 5, name: "Sunscorch Expanse", subtitle: "Hold out at high noon",
                 mapArtName: "MapBG", enemyWaves: 6, towerHP: 300, baseHP: 700),
        LevelDef(id: 6, name: "Sandhold Citadel", subtitle: "Breach the desert keep",
                 mapArtName: "MapBG", enemyWaves: 6, towerHP: 320, baseHP: 800),
        LevelDef(id: 7, name: "Cinder Gate", subtitle: "Enter the burn",
                 mapArtName: "MapBG", enemyWaves: 7, towerHP: 350, baseHP: 900),
        LevelDef(id: 8, name: "Hell Grounds", subtitle: "Hold the middle",
                 mapArtName: "MapBG", enemyWaves: 8, towerHP: 400, baseHP: 1000),
        LevelDef(id: 9, name: "Ashfall Bastion", subtitle: "Take the ash keep",
                 mapArtName: "MapBG", enemyWaves: 9, towerHP: 440, baseHP: 1100),
        LevelDef(id: 10, name: "Frostbite Approach", subtitle: "Into the white",
                 mapArtName: "MapBG", enemyWaves: 9, towerHP: 460, baseHP: 1150),
        LevelDef(id: 11, name: "Whiteout Redoubt", subtitle: "Siege the ice fortress",
                 mapArtName: "MapBG", enemyWaves: 10, towerHP: 500, baseHP: 1250),
        LevelDef(id: 12, name: "Howling Causeway", subtitle: "Cross the ice bridge",
                 mapArtName: "MapBG", enemyWaves: 10, towerHP: 540, baseHP: 1350),
        LevelDef(id: 13, name: "Stormwatch Crag", subtitle: "Silence the spire",
                 mapArtName: "MapBG", enemyWaves: 11, towerHP: 560, baseHP: 1400),
        LevelDef(id: 14, name: "Umbral Outskirts", subtitle: "Break the outer dark",
                 mapArtName: "MapBG", enemyWaves: 12, towerHP: 600, baseHP: 1450),
        LevelDef(id: 15, name: "Embral Core", subtitle: "Break the enemy core",
                 mapArtName: "MapBG", enemyWaves: 12, towerHP: 650, baseHP: 1500),
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
