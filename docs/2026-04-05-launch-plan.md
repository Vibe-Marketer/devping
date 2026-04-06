# DevPing Launch Plan — Step by Step

_Date: 2026-04-05_

This plan folds together:

- the launch audit
- requested copy/content changes
- GSD support planning
- free vs paid strategy
- launch packaging and productization work

This plan assumes:

- **ship direct first**
- **defer Mac App Store release**
- **treat DevPing as a real product launch**

---

# 0. Immediate findings from today's audit

## Config duplication exists right now

### Claude Code
Current `~/.claude/settings.json` has:
- **4 duplicate DevPing `Stop` hooks**
- **1 DevPing `Notification` hook**

### OpenCode
Current `~/.config/opencode/settings.json` has:
- **6 duplicate DevPing `Stop` hooks**
- **1 legacy OpenCode notify-complete hook**
- **1 DevPing `Notification` hook**
- **1 legacy OpenCode permission hook**

### Aider
Current `~/.aider.conf.yml` has one DevPing notification command and does **not** appear duplicated.

## Marketing/community UI is currently a little too heavy

Current friction points:
- “Join the Vibe Marketing Community” feels more promotional than product-native
- onboarding finish step stacks test + settings + star + community asks all at once
- About tab contains many social tiles, but not all are equally product-critical
- product messaging should feel built-in and natural, not needy

## GSD is not integrated yet

Current state:
- `gsd` is installed locally
- DevPing onboarding supports only:
  - Claude Code
  - OpenCode
  - Aider
- GSD does **not** appear to use the same Claude/OpenCode-style `Stop`/`Notification` hook config path
- GSD appears to have an extension/event model (`agent_end`, UI notify events, remote questions), so **proper support likely requires a DevPing-for-GSD extension/integration**, not just another JSON hook entry

---

# 1. Product strategy

## 1.1 Free plan
Create an **incredibly free** version that is genuinely useful.

### Free should include
- Claude Code support
- OpenCode support
- Aider support
- GSD support once integrated
- native notifications
- sound selection
- popup position
- test notification
- onboarding
- basic themes
- launch-at-login

### Free positioning
- the best free desktop notifier for AI coding tools on macOS
- no account required to get started
- useful within 2 minutes

## 1.2 Paid plan
Paid should unlock **deeper workflow value**, not basic functionality.

### Better paid directions than “pay to notify”
- premium theme packs
- advanced notification rules / routing
- per-tool profiles
- focus modes / schedules / DND presets
- session history / notification history
- team presets / sync
- licensing / account portal
- optional cloud backup / preferences sync
- push messaging / product updates / launch announcements

## 1.3 Monetization recommendation
### Recommended pricing shape
- **Free** — core DevPing
- **Pro one-time** — $19–39
- **Optional recurring plan later** only if cloud, sync, history, or team features are added

---

# 2. UX / copy / brand cleanup

## 2.1 Immediate copy changes
1. Change onboarding/community CTA:
   - from: `Join the Vibe Marketing Community`
   - to: `Join the Community`
2. Review all mentions of “Vibe Marketing” inside the product
3. Make community/support CTAs sound product-native, not creator-centric
4. Reduce stack of asks on final onboarding step

## 2.2 “Stats-style” support popup direction
Create a tasteful support/links dialog inspired by the Stats example:
- occasional, not frequent
- easy to dismiss
- clear value framing
- support options without guilt pressure
- should feel like part of the product

### Good use cases
- post-update “What’s new / Support DevPing” modal
- first major release celebration modal
- optional “Help support the project” panel in About

### Avoid
- aggressive interruptive donation walls
- repeated nagging
- blocking primary workflow

## 2.3 Social / marketing architecture
Split links into tiers.

### Tier 1: Product-critical
- GitHub
- Community
- Website
- Support / Contact

### Tier 2: Personal / creator network
- X / Twitter
- LinkedIn
- Instagram
- Facebook

### Tier 3: Coming soon / optional
- YouTube
- TikTok

Recommendation: keep Tier 1 prominent; demote the rest.

---

# 3. GSD support plan

## 3.1 Goal
Make DevPing visibly support GSD as a first-class tool.

## 3.2 Product requirement
In “Connect to your AI tools”:
- add **GSD** to the list
- detect whether GSD is installed
- if not installed, show it grayed out / unavailable
- if installed, allow setup

## 3.3 Important technical finding
GSD likely needs a different integration path than Claude/OpenCode/Aider.

### Why
Local inspection suggests GSD exposes:
- extension lifecycle events like `agent_end`
- internal UI notify mechanisms
- extension-driven behavior

So the likely implementation path is:

### Phase A — Detection only
- detect `gsd` in PATH
- add GSD row to onboarding UI
- mark installed vs not installed
- disable if not installed

### Phase B — Real integration
Build a small GSD extension or bridge that:
- hooks into `agent_end` / relevant events
- launches DevPing for completion / attention-needed events
- passes enough context for title/project/tool labeling

### Phase C — Installer support
Add DevPing setup for GSD that:
- writes the extension into the proper GSD extension location
- enables it safely
- checks if already installed
- avoids duplicates

## 3.4 Acceptance criteria
- GSD shows up in onboarding
- GSD install state is detected correctly
- setup is idempotent
- DevPing actually fires from GSD on real completion / attention-needed events
- no duplicate registrations

---

# 4. Duplicate hook cleanup plan

## 4.1 Problem
DevPing hook entries are currently duplicated in real user config.

## 4.2 Likely causes
- setup run multiple times over time
- previous installer logic did not fully dedupe existing entries in all historical states
- legacy hooks coexist alongside DevPing hooks

## 4.3 Required fix
Add a **dedupe / repair pass** to installer logic.

### For Claude/OpenCode JSON settings
- normalize existing hooks
- remove duplicate DevPing `Stop` entries
- remove duplicate DevPing `Notification` entries
- preserve unrelated hooks
- optionally preserve legacy hooks unless user chooses “replace existing notifier hooks”

### For Aider YAML
- confirm single `notifications-command`
- no duplicate injection

## 4.4 UX requirement
In onboarding / settings:
- show whether hooks are:
  - not installed
  - installed cleanly
  - installed but duplicated / repair recommended

## 4.5 Acceptance criteria
- running setup repeatedly does not create duplicates
- existing duplicates can be repaired automatically
- unrelated hooks remain intact

---

# 5. Marketing / link audit plan

## 5.1 What is currently wired
Current hardcoded URLs observed:
- X / Twitter → `https://x.com/andrewnaegele`
- Instagram → `https://instagram.com/andrew.naegele`
- Facebook → `https://facebook.com/andrewnaegele`
- LinkedIn → `https://linkedin.com/in/andrewnaegele`
- AI Simple → `https://aisimple.co`
- GitHub → `https://github.com/Vibe-Marketer/devping`
- Skool / Community → `https://skool.com/vibe-marketing`

## 5.2 Verification status
- X: reachable
- Instagram: reachable
- Facebook: reachable
- AI Simple: reachable
- GitHub: reachable
- Skool: reachable
- LinkedIn: automated verification blocked; manual check needed

## 5.3 Improvements needed
- centralize link definitions in one config/model
- separate product links from personal/social links
- support future A/B updates without hunting through views
- decide whether all current social links belong in-app

## 5.4 Recommendation
Replace scattered hardcoded links with a single source of truth:
- `SocialLink` / `MarketingLink` model
- visibility tier
- status (`active`, `comingSoon`, `hidden`)
- optional analytics tag later

---

# 6. Notifications / push / account / license strategy

## 6.1 “Push” notifications to users
This should **not** be the first shipping feature.

### Why
It requires:
- user identity
- backend
- consent/preferences
- message delivery design
- abuse prevention
- privacy policy
- opt-in / opt-out management

### Recommendation
Defer this to a later milestone.

## 6.2 Better first version
Start with:
- local notifications only
- optional in-app changelog / announcement panel
- optional “check for updates” / release notes

## 6.3 Accounts / email / licenses
This is a real monetization track, but should be phased.

### Phase 1
No mandatory account for free use.

### Phase 2
Add optional account for:
- Pro license management
- download access
- upgrade path
- email receipt / updates

### Phase 3
If needed later:
- cloud sync
- preferences sync
- team management
- remote announcements

## 6.4 Licensing model recommendation
For direct distribution:
- email + license key
- local activation check
- lightweight account portal later

Possible vendors:
- Lemon Squeezy
- Paddle
- Gumroad + custom licensing
- Polar / other indie billing options

---

# 7. Launch hardening plan

## 7.1 Packaging / release
1. production signing
2. notarization
3. staple notarization ticket
4. create clean release zip/dmg
5. test install on clean machine
6. create proper uninstall instructions

## 7.2 Trust / transparency
Add docs for:
- what files DevPing modifies
- what permissions it may request
- how notifications work
- what data is stored locally
- how to uninstall cleanly

## 7.3 Support docs
Add:
- FAQ
- troubleshooting guide
- permissions guide
- “hooks not firing” guide
- “duplicate hooks repair” guide

---

# 8. Codebase polish plan

## 8.1 Structural refactor
Split `Sources/main.swift` into focused files:
- `App/` app entry + menu bar controller
- `Settings/` settings model + persistence
- `Notifications/` notification window + view
- `Onboarding/` onboarding flow + steps
- `Integrations/` tool models + installer logic
- `Branding/` links, copy, footer, about metadata

## 8.2 Testing priorities
Add tests for:
- hook dedupe behavior
- JSON patcher behavior
- YAML patcher behavior
- install state detection
- link model correctness
- GSD detection logic

## 8.3 Release automation
Create:
- release build script
- codesign/notarize script
- version bump checklist
- artifact naming convention

---

# 9. Recommended implementation order

## Milestone 1 — Cleanup + truth pass
- audit current copy/links/hooks
- fix duplicate hook repair path
- centralize marketing links
- change “Join the Vibe Marketing Community” → “Join the Community”
- reduce end-screen promotional weight

## Milestone 2 — GSD groundwork
- add GSD row to onboarding
- detect GSD installation
- gray out when missing
- research/implement actual GSD integration path

## Milestone 3 — Launch readiness
- docs
- support pages
- privacy page
- permissions docs
- installer/uninstaller polish
- clean build/release pipeline

## Milestone 4 — Product packaging
- define free vs Pro boundary
- decide license vendor
- create upgrade messaging
- create launch site / release copy / screenshots

## Milestone 5 — Public launch
- ship direct download
- Homebrew update
- GitHub release
- launch post/thread
- community announcement

## Milestone 6 — Post-launch monetization
- Pro unlock
- license flow
- optional account system
- optional support popup / changelog / release announcements

---

# 10. Immediate next actions

## Recommend doing next, in order
1. fix the duplicate hook problem in installer logic
2. implement the copy change to “Join the Community”
3. centralize all social/product links
4. add GSD as a detected-but-not-yet-fully-integrated tool row
5. design the GSD integration architecture
6. tone down onboarding finish screen so it feels more natural
7. create trust/docs package for launch

---

# 11. Decision for now

## Official stance
- **Do now:** direct launch as product + lead magnet
- **Do now:** free + future Pro planning
- **Do now:** GSD support planning and implementation
- **Do later:** official Mac App Store release
- **Do later:** push notifications / accounts / licensing backend

---

# 12. Success definition

DevPing is ready to launch when:
- setup is idempotent
- duplicates are repaired or prevented
- all displayed links are correct
- onboarding feels clean and not needy
- GSD is represented properly and support path is clear
- direct-download build is signed/notarized
- docs/support pages exist
- free offer is genuinely valuable
- paid path is defined but not forced into first use
