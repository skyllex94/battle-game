import Foundation

/// Stage 1 campaign model. Mirrors the Unity flow:
/// MainMenu -> MapLevels (world map) -> LevelSelection1 (level intro) -> ConfigurationUI (hero pick) -> MainLevel.
/// MVP: 3 level defs, only Level 1 unlocked. Progress persists in UserDefaults.
struct LevelDef: Identifiable, Codable {
    let id: Int
    let name: String
    let subtitle: String
    /// 2-3 sentence planet intro + objective, shown on the briefing screen.
    let briefing: String
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
                 briefing: "Emra was humanity's cradle before the dark swallowed it. Drop into Verdant Landing, break the outpost pickets and plant our beacon. Objective: destroy the enemy HQ.",
                 mapArtName: "LevelSelectionBG", enemyWaves: 3, towerHP: 200, baseHP: 500),
        LevelDef(id: 2, name: "Rootwall Thicket", subtitle: "Pincer through the pines",
                 briefing: "The pines of Rootwall hide raider nests, and the Heavy has just rolled off the dropship. Objective: clear the thicket and raze the HQ.",
                 mapArtName: "MapBG", enemyWaves: 4, towerHP: 220, baseHP: 550),
        LevelDef(id: 3, name: "Thornwood Bastion", subtitle: "Storm the timber castle",
                 briefing: "A timber fortress blocks the east road and its guns own the lane. Bring towers, bring friends, bring everything. Objective: bring Thornwood Bastion down.",
                 mapArtName: "MapBG", enemyWaves: 5, towerHP: 250, baseHP: 600),
        LevelDef(id: 4, name: "Dune Atoll", subtitle: "Cross the white sands",
                 briefing: "Beyond the woods Emra turns to glass-white sand. The Ranger volunteered for point — open ground is a skirmisher's home. Objective: cross the Atoll, kill the HQ.",
                 mapArtName: "MapBG", enemyWaves: 5, towerHP: 260, baseHP: 650),
        LevelDef(id: 5, name: "Sunscorch Expanse", subtitle: "Hold out at high noon",
                 briefing: "High noon on the Expanse: no cover, no shade, no mercy. Keep moving or cook where you stand. Objective: hold the line and break their base.",
                 mapArtName: "MapBG", enemyWaves: 6, towerHP: 300, baseHP: 700),
        LevelDef(id: 6, name: "Sandhold Citadel", subtitle: "Breach the desert keep",
                 briefing: "The desert keep has never fallen — its walls have buried better armies than ours. Be the first. Objective: breach Sandhold Citadel.",
                 mapArtName: "MapBG", enemyWaves: 6, towerHP: 320, baseHP: 800),
        LevelDef(id: 7, name: "Cinder Gate", subtitle: "Enter the burn",
                 briefing: "Ash chokes the pass and the ground glows through the cracks. The Cannon is hot and waiting at the gate. Objective: force Cinder Gate.",
                 mapArtName: "MapBG", enemyWaves: 7, towerHP: 350, baseHP: 900),
        LevelDef(id: 8, name: "Hell Grounds", subtitle: "Hold the middle",
                 briefing: "The middle of nowhere, and it shoots back. Saboteur up — their towers are the mission now. Objective: hold the middle, kill the HQ.",
                 mapArtName: "MapBG", enemyWaves: 8, towerHP: 400, baseHP: 1000),
        LevelDef(id: 9, name: "Ashfall Bastion", subtitle: "Take the ash keep",
                 briefing: "A keep of black glass under falling ash. Something new hunts the treeline here — watch your flanks. Objective: take Ashfall Bastion.",
                 mapArtName: "MapBG", enemyWaves: 9, towerHP: 440, baseHP: 1100),
        LevelDef(id: 10, name: "Frostbite Approach", subtitle: "Into the white",
                 briefing: "Snow blind, wind screaming, steel brittle as glass. Bulwark leads into the white. Objective: push the Approach and destroy the HQ.",
                 mapArtName: "MapBG", enemyWaves: 9, towerHP: 460, baseHP: 1150),
        LevelDef(id: 11, name: "Whiteout Redoubt", subtitle: "Siege the ice fortress",
                 briefing: "An ice fortress inside a storm that never ends. Siege it fast or freeze slow. Objective: crack Whiteout Redoubt.",
                 mapArtName: "MapBG", enemyWaves: 10, towerHP: 500, baseHP: 1250),
        LevelDef(id: 12, name: "Howling Causeway", subtitle: "Cross the ice bridge",
                 briefing: "One ice bridge over a black abyss, and Wardens walk it. Do not stop mid-span. Objective: cross the Causeway and raze the HQ.",
                 mapArtName: "MapBG", enemyWaves: 10, towerHP: 540, baseHP: 1350),
        LevelDef(id: 13, name: "Stormwatch Crag", subtitle: "Silence the spire",
                 briefing: "The spire sings and the sky answers with lightning. The Warlord takes point — nothing else survives up there. Objective: silence Stormwatch Crag.",
                 mapArtName: "MapBG", enemyWaves: 11, towerHP: 560, baseHP: 1400),
        LevelDef(id: 14, name: "Umbral Outskirts", subtitle: "Break the outer dark",
                 briefing: "The dark here is thick enough to touch. One last stretch of haunted ground before the Core. Objective: break the outer dark.",
                 mapArtName: "MapBG", enemyWaves: 12, towerHP: 600, baseHP: 1450),
        LevelDef(id: 15, name: "Embral Core", subtitle: "Break the enemy core",
                 briefing: "This is it — the heart of the enemy on Emra. Everything earned, everything unlocked, ends here. Objective: destroy the Embral Core and take humanity home.",
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
    /// Campaign level that unlocks this hero (0 = available from the start).
    /// Only Vanguard starts unlocked; the rest are milestone grants that the
    /// future UnlockStore will claim (diamonds buyout plugs in here later).
    let unlockLevel: Int
}

struct HeroRoster {
    static let heroes: [HeroDef] = [
        HeroDef(id: "scout", displayName: "Scout", iconArtName: "Hero_icon1",
                maxHealth: 100, speed: 12, blurb: "Fast feet, light frame. Your Unity starting build.",
                unlockLevel: 2),
        HeroDef(id: "vanguard", displayName: "Vanguard", iconArtName: "Hero_Icon2",
                maxHealth: 140, speed: 10, blurb: "Balanced fighter for the first push.",
                unlockLevel: 0),
        HeroDef(id: "bulwark", displayName: "Bulwark", iconArtName: "Hero_Icon3",
                maxHealth: 180, speed: 8, blurb: "Slow tank. Holds the lane under tower fire.",
                unlockLevel: 10),
        HeroDef(id: "ranger", displayName: "Ranger", iconArtName: "Hero_icon4",
                maxHealth: 110, speed: 11, blurb: "Gun-ready skirmisher.",
                unlockLevel: 4),
        HeroDef(id: "saboteur", displayName: "Saboteur", iconArtName: "Hero_icon5",
                maxHealth: 120, speed: 11, blurb: "Tower-killer. Bonus vs structures (stage 2).",
                unlockLevel: 8),
        HeroDef(id: "warlord", displayName: "Warlord", iconArtName: "Hero_Icon6",
                maxHealth: 200, speed: 9, blurb: "Late-campaign bruiser. Locked feel for now, playable in MVP.",
                unlockLevel: 13),
    ]

    private static let selectedKey = "campaign.selectedHero"

    /// A hero is selectable when its milestone is claimed. Until the
    /// UnlockStore lands, only unlockLevel 0 (Vanguard) is available.
    static func isUnlocked(_ hero: HeroDef) -> Bool {
        hero.unlockLevel <= 0
    }

    static var unlockedHeroes: [HeroDef] { heroes.filter(isUnlocked) }

    static var selectedHeroId: String {
        get {
            let stored = UserDefaults.standard.string(forKey: selectedKey) ?? "vanguard"
            // Migrate old installs (and guard corrupt ids): a locked stored
            // hero always falls back to Vanguard, never to a locked pick.
            if let match = heroes.first(where: { $0.id == stored }), isUnlocked(match) {
                return match.id
            }
            return "vanguard"
        }
        set {
            // Never persist a locked hero.
            if let match = heroes.first(where: { $0.id == newValue }), isUnlocked(match) {
                UserDefaults.standard.set(newValue, forKey: selectedKey)
            }
        }
    }

    static var selectedHero: HeroDef {
        heroes.first(where: { $0.id == selectedHeroId }) ?? heroes[1]
    }
}
