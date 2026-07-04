# GuildUI+

**The definitive guild management addon for World of Warcraft 3.3.5a (Wrath of the Lich King).**

GuildUI+ replaces the default guild frame with a fully modular, high-performance guild management system. Built from the ground up with zero external dependencies, a versioned communication protocol, and a persistent settings layer — designed to render every existing guild addon obsolete.

---

## Features

### Roster
- **10 sortable columns** — Name, Class, Level, Rank, Zone, Note, Officer Note, Last Online, Status, Achievement Points
- **Search-as-you-type** across all visible fields
- **Alt-grouping** with real main-character resolution (not fragile officer-note heuristics)
- **Multi-filter** — filter by rank, class, online status, alt visibility
- **Frame pool** rendering for 1000+ member rosters at <0.5ms/frame

### Forum
- Reddit-style threaded posts with nested replies
- Sticky posts, polls with voting, edit history
- Comm-synced across all addon users in the guild

### Schedule
- Calendar with event creation, role sign-up (Tank/Healer/DPS)
- Recurring events (daily/weekly)
- Automatic 30-minute reminders

### Recruitment
- Applicant → Trial → Raider pipeline with status tracking
- Trade-channel ad rotation with cooldown sync across officers
- Auto-welcome DM on trial acceptance

### Attendance
- Automatic zone-delta tracking
- Absence reports and weekly digests
- Per-member session history

### Ledger
- DKP or EPGP system with immutable hash-chain audit log
- Undo window (60 seconds) for accidental entries
- Integrity verification

### Notifier
- Rule engine with configurable triggers:
  - Officer / crafter online
  - Members in same zone
  - Achievement cap reached
  - Ledger events
  - Schedule reminders
  - New forum posts
- Per-rule cooldowns, guild-chat output + webhook sink

### Webhook
- Discord outbound via officer-channel proxy
- Templates for kicks, promotions, joins, ledger events, forum posts
- Retry queue with rate limiting

### Banker
- Tab-level filters by quality, subtype, item class
- Auctioneer value-floor integration
- Multi-pass sort with gap-fill

### Dashboard
- Class distribution bar chart
- Level histogram
- Online count trend (24h)
- Recruitment funnel snapshot

### Locator
- Guild member zones on world map
- Same-zone whisper shortcuts
- Auto-broadcast on zone change

### MOTD
- Synced refresh intervals
- First-of-day re-prompt in chat

### Tutorial
- 8-step interactive overlay tour
- Auto-shows on first login
- Dismissable, remembers completion

---

## Architecture

```
GuildUIPlus/
├── GuildUIPlus.toc
├── Core/
│   ├── Util.lua        — FramePool, CRC32, class colors, time/string/table helpers
│   ├── Loader.lua      — Module registry, lazy-load, event bus
│   ├── Comm.lua        — Versioned text protocol (GG1), 32 OP codes, dedup ring buffer
│   ├── Settings.lua    — Per-account settings with char overrides, migration chain
│   └── UI.lua          — Main frame, module rail, tab switching, slash commands
└── Modules/
    ├── Roster.lua      — 10-column sortable roster with search/filter/alt-grouping
    ├── Forum.lua       — Threaded forum with sticky/polls/edit-history
    ├── Schedule.lua    — Event calendar with role sign-up
    ├── Attendance.lua  — Zone-delta tracking and absence reports
    ├── Notifier.lua    — Rule engine for guild notifications
    ├── Ledger.lua      — DKP/EPGP with hash-chain audit
    ├── Recruitment.lua — Applicant pipeline and ad rotation
    ├── Banker.lua      — Guild bank tab filters
    ├── Webhook.lua     — Discord outbound templates
    ├── Dashboard.lua   — Class/level/online analytics
    ├── Locator.lua     — World-map guild member pins
    ├── MOTD.lua        — Synced message of the day
    └── Tutorial.lua    — Interactive first-run tour
```

### Communication Protocol

GuildUI+ uses a custom versioned text protocol over the standard `SendAddonMessage` API:

| Field | Size | Description |
|-------|------|-------------|
| Magic | 3 bytes | `GG1` prefix |
| Version | 1 byte | Protocol version (currently `1`) |
| OP Code | 1 byte | Message type (32 defined operations) |
| Flags | 1 byte | Urgent / broadcast / whisper flags |
| Message ID | 2 bytes | Dedup key (ring buffer of 512) |
| Payload | variable | Module-specific body |

All incoming messages are deduplicated via a per-sender ring buffer. Unknown protocol versions are silently ignored for forward compatibility.

### Settings & Migration

- **Per-account** `GuildUIPlusDB` with optional **per-character** overrides
- Numbered migration chain (`version` field) — dry-run on load, safe rollback on failure
- Import/export for settings transfer between characters or servers

### Performance Budget

| Metric | Target |
|--------|--------|
| Roster refresh (1000 members) | <2.5ms |
| Single event frame render | <0.5ms |
| Frame pool reuse | 100% (zero allocations after warmup) |
| Update throttle | 1Hz coalesced diffs |

---

## Installation

### Manual Install

1. Download the latest release or clone this repository
2. Copy the `GuildUIPlus` folder into your WoW addon directory:
   ```
   World of Warcraft/
   └── Interface/
       └── AddOns/
           └── GuildUIPlus/
               ├── GuildUIPlus.toc
               ├── Core/
               └── Modules/
   ```
3. Restart World of Warcraft or type `/reload` in chat
4. At the character selection screen, click **AddOns** and verify **GuildUI+** is checked
5. Log in to a character that is in a guild

### Verify Installation

- Type `/gg` in chat to open the addon
- The main frame should appear with a module rail on the left side
- The **Tutorial** overlay will show automatically on first login

---

## Usage

### Slash Commands

| Command | Description |
|---------|-------------|
| `/gg` | Toggle main window |
| `/gg roster` | Open the Roster module |
| `/gg forum` | Open the Forum module |
| `/gg schedule` | Open the Schedule module |
| `/gg help` | Show all available commands |

### Keybindings

Open **Esc → Key Bindings → GuildUI+** to set a toggle keybind for the main window.

### Roster

- **Click column headers** to sort ascending/descending
- **Type in the search box** to filter by name, rank, class, zone, or notes
- **Use filter buttons** (All Class, Offline, Alts) to narrow results
- **Click a member** to open their detail panel
- Right-click context menu for promote/demote/whisper/inspect (coming soon)

### Forum

- Click **New Thread** to create a top-level post with title and body
- Click any thread to view replies
- Officers can mark posts as **Sticky**
- Create polls by enabling the poll option when posting

### Schedule

- Click **New Event** to create a raid or guild activity
- Set roles required (Tank/Healer/DPS counts)
- Members click **Sign Up** and select their role
- Reminders fire automatically 30 minutes before start

### Settings

Access via the **Settings** module in the rail or by editing `GuildUIPlusDB` in-game:

- **Module Toggles** — enable/disable any module
- **UI Scale** — adjust frame scale (0.75x – 1.5x)
- **Font Scale** — adjust text size (0.75x – 1.5x)
- **Colorblind Mode** — switch to colorblind-safe palette
- **Import/Export** — backup or transfer settings

---

## Adding a Module

GuildUI+ uses a registry-based module loader. To add a new module:

```lua
local ADDON, NS = ...

local MyModule = {
    name = "mymod",
    label = "My Module",
}

NS.Loader:Register("mymod", MyModule)

function MyModule:OnLoad()
    -- Called once when the addon loads
end

-- Hook into lifecycle events
NS.Loader:On("ON_READY", function()
    NS.UI:RegisterModuleTab("mymod", "My Module", nil, 99)
    -- Build your UI panel here
end)
```

### Available Lifecycle Events

| Event | Fires When |
|-------|-----------|
| `ON_LOAD` | All registered modules loaded |
| `ON_READY` | `PLAYER_ENTERING_WORLD` fires |
| `ON_ROSTER` | `GUILD_ROSTER_UPDATE` fires |
| `ON_COMM` | Incoming message with our prefix |
| `ON_ZONE` | `ZONE_CHANGED_NEW_AREA` fires |
| `ON_CHAT` | `GUILD_MOTD_CHANGED` fires |
| `ON_BANK` | Guild bank frame opens |

### Sending Messages

```lua
-- Broadcast to guild
NS.Comm:Send(NS.Comm.OP.MY_OP, payload, "GUILD")

-- Whisper a specific player
NS.Comm:Send(NS.Comm.OP.MY_OP, payload, "WHISPER", targetName)

-- Handle incoming
NS.Comm:On(NS.Comm.OP.MY_OP, function(sender, payload, channel, msg)
    -- msg.version, msg.op, msg.flags, msg.msgId
end)
```

---

## Contributing

This project is not open for external contributions at this time. Forking is permitted only for personal viewing, study, backup, or installation purposes. Forks may not be modified, redistributed, or used as the basis for another project without prior written permission.

If you have a bug report or feature suggestion, please open an issue on the GitHub repository.

### Testing

- Install on a WotLK 3.3.5a private server
- Verify each module loads without errors (`/console reloadui`)
- Check the Lua errors frame (`/console scriptErrors 1`)
- Test with a guild of 50+ members for roster performance
- Test addon-comm with a second account

---

## License

Proprietary — **Copyright (c) 2026 Zendevve. All rights reserved.**

Personal, non-commercial use within World of Warcraft is permitted. Modification, redistribution, and derivative works are prohibited without prior written permission. See [LICENSE](LICENSE.md) for full terms.

---

## Support

If you find GuildUI+ useful and want to support continued development:

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-yellow?style=for-the-badge&logo=buy-me-a-coffee)](https://buymeacoffee.com/zendevve)

Your support helps maintain the addon, write documentation, and build new features. Every coffee counts.

---

## Acknowledgments

- Built for the **World of Warcraft 3.3.5a** private server community
- Designed as a clean-room implementation — no code reused from existing guild addons
- Inspired by the feature sets of GManager, GuildManager, GuildMaster, and ImprovedGuildWindow, but built from scratch with modern architecture
