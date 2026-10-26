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
    /// DEV playground pseudo-level (PLAYGROUND button on the briefing
    /// screen). Never part of `levels`: no stars, no unlocks, no rewards.
    static let playgroundDef = LevelDef(
        id: 999,
        name: "Playground",
        subtitle: "Unit inspection range",
        briefing: "DEV ONLY. A tiny range with one player tower and no enemy tower; the gate releases one unit of this briefing's debut hostile per wave. Remove when done.",
        mapArtName: "MapBG",
        enemyWaves: 0,
        towerHP: 200,
        baseHP: 200)
    /// The 35-region takeback of Emra, west → east: verdant woods (1-6),
    /// white sands and dune seas (7-12), mountain passes (13-20), ice
    /// (21-27), then the dark core (28-35). Castles punctuate the major
    /// regions (ids 3 / 6 / 12 / 20 / 27 / 35).
    static let levels: [LevelDef] = [
        LevelDef(id: 1, name: "Verdant Landing", subtitle: "First push — learn the lane",
                 briefing: "Emra was humanity's cradle before the dark swallowed it. Drop into Verdant Landing, break the outpost pickets and plant our beacon. Objective: destroy the enemy HQ.",
                 mapArtName: "LevelSelectionBG", enemyWaves: 3, towerHP: 200, baseHP: 500),
        LevelDef(id: 2, name: "Rootwall Thicket", subtitle: "Pincer through the pines",
                 briefing: "The pines of Rootwall hide raider nests, and the Ranger ships in with a long rifle to pick them off. Objective: clear the thicket and raze the HQ.",
                 mapArtName: "MapBG", enemyWaves: 4, towerHP: 220, baseHP: 550),
        LevelDef(id: 3, name: "Thornwood Bastion", subtitle: "Storm the timber castle",
                 briefing: "A timber fortress blocks the east road and the Heavy has just rolled off the dropship to crack it — but the enemy answers with siege Brutes. Objective: bring Thornwood Bastion down.",
                 mapArtName: "MapBG", enemyWaves: 5, towerHP: 250, baseHP: 600),
        LevelDef(id: 4, name: "Mosslight Hollow", subtitle: "Slip through the twilight woods",
                 briefing: "Mosslight Hollow is a drowned grove of blue-green fog and hanging roots. Raider pickets have strung lamps through the trees — follow the light, break the line, then burn the outpost. Objective: destroy the enemy HQ.",
                 mapArtName: "MapBG", enemyWaves: 5, towerHP: 260, baseHP: 620),
        LevelDef(id: 5, name: "Fernreach Wilds", subtitle: "Break the forest cordon",
                 briefing: "Fernreach is the last deep wood before the sand. Axe-teams have felled a corridor through the ferns, and Reavers hold the far side. Objective: punch through the Wilds and destroy the enemy HQ.",
                 mapArtName: "MapBG", enemyWaves: 6, towerHP: 280, baseHP: 660),
        LevelDef(id: 6, name: "Ironbark Keep", subtitle: "Storm the forest citadel",
                 briefing: "The Ironbark Keep was a ranger hall before the dark took it. Its timber walls are old but its guns are new. Objective: breach the Keep and destroy the enemy HQ.",
                 mapArtName: "MapBG", enemyWaves: 6, towerHP: 300, baseHP: 700),
        LevelDef(id: 7, name: "Sirocco Dunes", subtitle: "Ride the dune sea",
                 briefing: "Past the woods the desert opens into a golden dune sea — shifting sands, bleached bones, and the enemy dug in deep. Objective: cross the Sirocco Dunes and destroy the enemy HQ.",
                 mapArtName: "MapBG", enemyWaves: 7, towerHP: 320, baseHP: 760),
        LevelDef(id: 8, name: "Oasis Waste", subtitle: "Cross the green mirage",
                 briefing: "What looks like water is a trap — the oases are crawling, and something nests in the ruin arches. The Vanguard drops in with you tonight. Objective: cross the Oasis Waste and destroy the enemy HQ.",
                 mapArtName: "MapBG", enemyWaves: 7, towerHP: 340, baseHP: 820),
        LevelDef(id: 9, name: "Duskfall Flats", subtitle: "Hold out through sundown",
                 briefing: "The sun is going down over the flats and the machines are coming with it — something heavy, walking, and shooting in bursts. Objective: survive the dusk and destroy the enemy HQ.",
                 mapArtName: "MapBG", enemyWaves: 8, towerHP: 360, baseHP: 880),
        LevelDef(id: 10, name: "Glasswind Basin", subtitle: "Cross the mirror flats",
                 briefing: "The Glasswind Basin is a dried salt sea: white ground, hot wind, and no cover for either army. Objective: cross the flats and destroy the enemy HQ.",
                 mapArtName: "MapBG", enemyWaves: 8, towerHP: 380, baseHP: 940),
        LevelDef(id: 11, name: "Sunforge Redoubt", subtitle: "Breach the desert foundry",
                 briefing: "A foundry-fortress burns through the night in the heart of the waste, pouring ember-lit smoke across the moon. Its outer wall carries a fourth gun tower. Objective: break Sunforge Redoubt and destroy the enemy HQ.",
                 mapArtName: "MapBG", enemyWaves: 9, towerHP: 400, baseHP: 1000),
        LevelDef(id: 12, name: "Sirocco Canyon", subtitle: "Force the moonlit canyon",
                 briefing: "The dunes pinch into a canyon road that runs silver under the moon, and the enemy has mined every switchback. Tall buttes throw black shadows across the sand. Objective: force Sirocco Canyon and destroy the enemy HQ.",
                 mapArtName: "MapBG", enemyWaves: 9, towerHP: 420, baseHP: 1060),
        LevelDef(id: 13, name: "Stonewatch Pass", subtitle: "Climb into the crags",
                 briefing: "The dunes end at a wall of black rock. Stonewatch Pass is the only way through, and it is watched. Objective: take the pass and destroy the enemy HQ.",
                 mapArtName: "MapBG", enemyWaves: 10, towerHP: 440, baseHP: 1120),
        LevelDef(id: 14, name: "Granite Reach", subtitle: "March the high plateau",
                 briefing: "Above the pass the world turns to bare granite and thin air. Pines cling to the crags and the road runs across a high rock shelf. The enemy holds the high ground; take it anyway. Objective: cross Granite Reach and destroy the enemy HQ.",
                 mapArtName: "MapBG", enemyWaves: 10, towerHP: 460, baseHP: 1180),
        LevelDef(id: 15, name: "Titan's Gate", subtitle: "Break the mountain gate",
                 briefing: "A gate carved for giants bars the eastern road — old stone, new guns. Objective: break Titan's Gate and destroy the enemy HQ.",
                 mapArtName: "MapBG", enemyWaves: 11, towerHP: 480, baseHP: 1240),
        LevelDef(id: 16, name: "Cinderpeak Ascent", subtitle: "Take the burning slope",
                 briefing: "Cinderpeak smoulders under old lava seams. The climb is narrow, exposed, and covered by artillery. Objective: take the Ascent and destroy the enemy HQ.",
                 mapArtName: "MapBG", enemyWaves: 11, towerHP: 500, baseHP: 1300),
        LevelDef(id: 17, name: "Highridge Redoubt", subtitle: "Storm the ridge fort",
                 briefing: "The ridge fort looks down on every approach. Break its towers or bleed on the rocks below. Objective: storm Highridge Redoubt and destroy the enemy HQ.",
                 mapArtName: "MapBG", enemyWaves: 11, towerHP: 520, baseHP: 1360),
        LevelDef(id: 18, name: "Riven Pass", subtitle: "Cross the shattered pass",
                 briefing: "The pass was split by an old quake — a maze of ledges and blind corners, perfect for ambushes. Objective: cross Riven Pass and destroy the enemy HQ.",
                 mapArtName: "MapBG", enemyWaves: 12, towerHP: 540, baseHP: 1420),
        LevelDef(id: 19, name: "Stormcrown Summit", subtitle: "Silence the storm king",
                 briefing: "Lightning walks the summit and the enemy has learned to aim it. Objective: silence Stormcrown and destroy the enemy HQ.",
                 mapArtName: "MapBG", enemyWaves: 12, towerHP: 560, baseHP: 1480),
        LevelDef(id: 20, name: "Ironhold Bastion", subtitle: "Crack the mountain stronghold",
                 briefing: "The last mountain fortress is built into the peak itself. No flank, no siege line, just a door. Objective: crack Ironhold Bastion and destroy the enemy HQ.",
                 mapArtName: "MapBG", enemyWaves: 12, towerHP: 590, baseHP: 1560),
        LevelDef(id: 21, name: "Frostbite Approach", subtitle: "Into the white",
                 briefing: "Snow blind, wind screaming, steel brittle as glass. Bulwark leads into the white. Objective: push the Approach and destroy the HQ.",
                 mapArtName: "MapBG", enemyWaves: 13, towerHP: 620, baseHP: 1640),
        LevelDef(id: 22, name: "Whiteout Redoubt", subtitle: "Siege the ice fortress",
                 briefing: "An ice fortress inside a storm that never ends. Siege it fast or freeze slow. Objective: crack Whiteout Redoubt.",
                 mapArtName: "MapBG", enemyWaves: 13, towerHP: 640, baseHP: 1700),
        LevelDef(id: 23, name: "Howling Causeway", subtitle: "Cross the ice bridge",
                 briefing: "One ice bridge over a black abyss, and Wardens walk it. Both sides raise a fifth gun tower to close the middle gap — five towers a side from here on. Do not stop mid-span. Objective: cross the Causeway and raze the HQ.",
                 mapArtName: "MapBG", enemyWaves: 13, towerHP: 660, baseHP: 1760),
        LevelDef(id: 24, name: "Rimewatch Crag", subtitle: "Climb the frozen spire",
                 briefing: "A watch-post of blue ice rises above the whiteout. Whoever holds it sees every move on the glacier. Objective: take Rimewatch Crag and destroy the enemy HQ.",
                 mapArtName: "MapBG", enemyWaves: 14, towerHP: 680, baseHP: 1820),
        LevelDef(id: 25, name: "Frozen Narrows", subtitle: "Break the ice line",
                 briefing: "The glacier pinches into a narrow channel of black water and brittle ice. There is no room to flank. Objective: break the Frozen Narrows and destroy the enemy HQ.",
                 mapArtName: "MapBG", enemyWaves: 14, towerHP: 700, baseHP: 1880),
        LevelDef(id: 26, name: "Rimevault", subtitle: "Raid the frozen vault",
                 briefing: "An old vault under the ice, packed with the enemy's winter stores and a garrison that never sleeps. Objective: raid Rimevault and destroy the enemy HQ.",
                 mapArtName: "MapBG", enemyWaves: 14, towerHP: 720, baseHP: 1940),
        LevelDef(id: 27, name: "Pale Abyss", subtitle: "Descend into the white dark",
                 briefing: "The ice ends at a crevasse that goes down further than light. Something is waiting at the bottom. Objective: cross the Pale Abyss and destroy the enemy HQ.",
                 mapArtName: "MapBG", enemyWaves: 15, towerHP: 750, baseHP: 2020),
        LevelDef(id: 28, name: "Umbral Outskirts", subtitle: "Break the outer dark",
                 briefing: "The dark here is thick enough to touch. Ash drifts over black rock, and the first red fires are burning on the horizon. Objective: break the outer dark.",
                 mapArtName: "MapBG", enemyWaves: 15, towerHP: 780, baseHP: 2100),
        LevelDef(id: 29, name: "Ashen March", subtitle: "March through the ash",
                 briefing: "Ash falls like grey snow and the ground is warm underfoot. Command has cleared the Tempest for the field — a flying artillery drone with the longest reach in the army. It takes its time to spin up each shot, then answers with the widest blast we have. Objective: cross the Ashen March and destroy the enemy HQ.",
                 mapArtName: "MapBG", enemyWaves: 15, towerHP: 810, baseHP: 2180),
        LevelDef(id: 30, name: "Blackroot Vale", subtitle: "Cross the dead vale",
                 briefing: "Black roots break through the ash and the air tastes of iron. Nothing green has grown here in years — but something red hunts above the roots: the Phoenix, a graviton strike-fighter faster than anything we have flown against. Objective: cross Blackroot Vale and destroy the enemy HQ.",
                 mapArtName: "MapBG", enemyWaves: 16, towerHP: 840, baseHP: 2260),
        LevelDef(id: 31, name: "Cinder Gate", subtitle: "Force the ember gate",
                 briefing: "A gate of scorched iron glows dull red — and both tower lines have been refitted into taller, bulkier Mk-III siege towers that answer every push with a 4-missile salvo. Beyond the gate, the dark answers with fire. Objective: force the Cinder Gate and destroy the enemy HQ.",
                 mapArtName: "MapBG", enemyWaves: 16, towerHP: 870, baseHP: 2340),
        LevelDef(id: 32, name: "Shadowrift", subtitle: "Cross the rift",
                 briefing: "The ground splits into a burning rift, and the only crossing is a black bridge under enemy guns. Command has cleared the Revrent for the field — a bluish carrier ringed by 5 interceptor droids that each fire on the enemy. Objective: cross Shadowrift and destroy the enemy HQ.",
                 mapArtName: "MapBG", enemyWaves: 16, towerHP: 900, baseHP: 2420),
        LevelDef(id: 33, name: "Dread Hollow", subtitle: "Enter the hollow",
                 briefing: "A bowl of black rock ringed by jagged peaks. The enemy's banners hang from the spires, lit by red fire. Objective: enter Dread Hollow and destroy the enemy HQ.",
                 mapArtName: "MapBG", enemyWaves: 17, towerHP: 930, baseHP: 2500),
        LevelDef(id: 34, name: "Obsidian Gate", subtitle: "Break the gate",
                 briefing: "The last gate is a wall of obsidian and iron, veined with violet void-light — and something new drifts above it: the Vesper, a void-herald glider raining a fan of weaving void splinters. Objective: break the Obsidian Gate and destroy the enemy HQ.",
                 mapArtName: "MapBG", enemyWaves: 17, towerHP: 970, baseHP: 2600),
        LevelDef(id: 35, name: "Embral Core", subtitle: "Break the enemy core",
                 briefing: "This is it — the heart of the enemy on Emra. Their HQ rises as a huge Mordor core-fortress crowned by the Burning Eye, answering every push with a 5-missile salvo while ours holds as the same Mk-II citadel. Everything earned, everything unlocked, ends here. Objective: destroy the Embral Core and take humanity home.",
                 mapArtName: "MapBG", enemyWaves: 18, towerHP: 1020, baseHP: 2750),
    ]

    private static let unlockedKey = "campaign.unlockedLevel"
    private static let starsKeyPrefix = "campaign.stars.level."
    private static let mapPanFracKey = "campaign.mapPanFraction"

    /// DEBUG: unlock all campaign levels for testing.
    static let debugUnlockAllLevels = true

    /// Highest level id the player may enter. Starts at 1.
    static var unlockedLevel: Int {
        get {
            if debugUnlockAllLevels { return levels.count }
            return max(1, UserDefaults.standard.integer(forKey: unlockedKey) == 0 ? 1 : UserDefaults.standard.integer(forKey: unlockedKey))
        }
        set { UserDefaults.standard.set(min(newValue, levels.count), forKey: unlockedKey) }
    }

    static func isUnlocked(_ level: LevelDef) -> Bool { level.id <= unlockedLevel }

    /// Last free-pan position of the campaign map, as a fraction of one
    /// screen width (0 = west edge). nil = never browsed the map yet.
    static var lastMapPanFraction: Double? {
        get { UserDefaults.standard.object(forKey: mapPanFracKey) as? Double }
        set {
            if let v = newValue {
                UserDefaults.standard.set(v, forKey: mapPanFracKey)
            } else {
                UserDefaults.standard.removeObject(forKey: mapPanFracKey)
            }
        }
    }

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
        lastMapPanFraction = nil
    }
}

/// Hero roster ported from Unity's ConfigurationUI (Hero_icon1..6 + BigViews).
/// Art: Art/Imported/HeroIcons/*.png
struct HeroDef: Identifiable {
    let id: String
    let displayName: String
    /// Imported art basename, e.g. "Hero_icon1".
    let iconArtName: String
    /// Detailed pixel-art kind: the armory + briefing twin of the fighter
    /// you play in battle (Vanguard matches the battle hero exactly).
    var pixelKind: HeroPixelArt.Kind {
        switch id {
        case "scout": return .scout
        case "bulwark": return .bulwark
        case "ranger": return .ranger
        case "saboteur": return .saboteur
        case "warlord": return .warlord
        case "titan": return .titan
        case "wraith": return .wraith
        case "paladin": return .paladin
        case "juggernaut": return .juggernaut
        case "spectre": return .spectre
        case "inferno": return .inferno
        default: return .vanguard
        }
    }
    /// One-word battlefield role for dossiers.
    var trait: String {
        switch id {
        case "scout": return "FAST SKIRMISH"
        case "bulwark": return "HEAVY TANK"
        case "ranger": return "MARKSMAN"
        case "saboteur": return "STRUCTURE KILLER"
        case "warlord": return "BRUISER"
        case "titan": return "SIEGE WALL"
        case "wraith": return "GHOST INFILTRATOR"
        case "paladin": return "OATHBOUND GUARD"
        case "juggernaut": return "DEMOLITIONS"
        case "spectre": return "RIG ENGINEER"
        case "inferno": return "PYRO VETERAN"
        default: return "BALANCED FRONTLINE"
        }
    }
    let maxHealth: Int
    let speed: Double
    /// Flat damage added to every shot fired (0 scout … 14 warlord).
    let baseDamage: Int
    let blurb: String
    /// Campaign level that unlocks this hero (0 = available from the start).
    /// Only Vanguard starts unlocked; the rest are milestone grants that the
    /// future UnlockStore will claim (diamonds buyout plugs in here later).
    let unlockLevel: Int
}

struct HeroRoster {
    /// Hero Roster. Scout + Vanguard (Level 8 milestone) + Bulwark
    /// (Level 15 milestone) + Ranger (Level 21 milestone). Everything
    /// else stays locked (99).
    static let heroes: [HeroDef] = [
        HeroDef(id: "scout", displayName: "Scout", iconArtName: "Hero_icon1",
                maxHealth: 100, speed: 10, baseDamage: 0,
                blurb: "Fast feet, light frame. Your Unity starting build.",
                unlockLevel: 0),
        HeroDef(id: "vanguard", displayName: "Vanguard", iconArtName: "Hero_Icon2",
                maxHealth: 160, speed: 13, baseDamage: 6,
                blurb: "Balanced fighter for the first push.",
                unlockLevel: 8),
        HeroDef(id: "bulwark", displayName: "Bulwark", iconArtName: "Hero_Icon3",
                maxHealth: 220, speed: 11, baseDamage: 12,
                blurb: "Slow tank. Holds the lane under tower fire.",
                unlockLevel: 15),
        HeroDef(id: "ranger", displayName: "Ranger", iconArtName: "Hero_icon4",
                maxHealth: 290, speed: 20, baseDamage: 8,
                blurb: "Gun-ready skirmisher.",
                unlockLevel: 21),
        HeroDef(id: "saboteur", displayName: "Saboteur", iconArtName: "Hero_icon5",
                maxHealth: 380, speed: 17, baseDamage: 10,
                blurb: "Tower-killer. Bonus vs structures (stage 2).",
                unlockLevel: 99),
        HeroDef(id: "warlord", displayName: "Warlord", iconArtName: "Hero_Icon6",
                maxHealth: 580, speed: 14, baseDamage: 14,
                blurb: "Late-campaign bruiser. Locked feel for now, playable in MVP.",
                unlockLevel: 99),
        HeroDef(id: "titan", displayName: "Titan", iconArtName: "Hero_icon1",
                maxHealth: 700, speed: 11, baseDamage: 16,
                blurb: "Walking siege wall. Slow, unstoppable, volcanic.",
                unlockLevel: 99),
        HeroDef(id: "wraith", displayName: "Wraith", iconArtName: "Hero_icon4",
                maxHealth: 280, speed: 20, baseDamage: 12,
                blurb: "Ghost infiltrator. There, then gone, then behind you.",
                unlockLevel: 99),
        HeroDef(id: "paladin", displayName: "Paladin", iconArtName: "Hero_Icon2",
                maxHealth: 520, speed: 12, baseDamage: 14,
                blurb: "Oathbound guard. Holds the line so others push it.",
                unlockLevel: 99),
        HeroDef(id: "juggernaut", displayName: "Juggernaut", iconArtName: "Hero_Icon3",
                maxHealth: 620, speed: 10, baseDamage: 18,
                blurb: "Demolitions bulk. Brings its own door-knocker.",
                unlockLevel: 99),
        HeroDef(id: "spectre", displayName: "Spectre", iconArtName: "Hero_icon5",
                maxHealth: 340, speed: 19, baseDamage: 13,
                blurb: "RIG-suited engineer. Cuts through anything.",
                unlockLevel: 99),
        HeroDef(id: "inferno", displayName: "Inferno", iconArtName: "Hero_Icon6",
                maxHealth: 420, speed: 15, baseDamage: 15,
                blurb: "Pyro veteran. Everything flammable has been warned.",
                unlockLevel: 99),
    ]

    private static let selectedKey = "campaign.selectedHero"

    /// DEBUG — explore mode: every hero selectable while we tune.
    /// OFF for now: Scout only.
    static let debugUnlockAll = false

    /// A hero is selectable once its milestone is claimed in battle (e.g.
    /// Vanguard on Level 8). Progress alone does NOT unlock — the claim
    /// modal is the gate, so the briefing always gets its moment.
    static func isUnlocked(_ hero: HeroDef) -> Bool {
        debugUnlockAll || hero.unlockLevel <= 0 || HeroRosterClaims.owns(hero)
    }

    static var unlockedHeroes: [HeroDef] { heroes.filter(isUnlocked) }

    static var selectedHeroId: String {
        get {
            let stored = UserDefaults.standard.string(forKey: selectedKey) ?? "scout"
            // Migrate old installs (and guard corrupt ids): a locked stored
            // hero always falls back to Scout, never to a locked pick.
            if let match = heroes.first(where: { $0.id == stored }), isUnlocked(match) {
                return match.id
            }
            return "scout"
        }
        set {
            // Never persist a locked hero.
            if let match = heroes.first(where: { $0.id == newValue }), isUnlocked(match) {
                UserDefaults.standard.set(newValue, forKey: selectedKey)
            }
        }
    }

    static var selectedHero: HeroDef {
        heroes.first(where: { $0.id == selectedHeroId }) ?? heroes[0]
    }
}
