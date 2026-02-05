# Customizable Character — Implementation Plan (Bubble Character Model)

## Goal

Allow players to customize their character’s appearance, animations, and gear in a way that is:

* Fast and responsive
* Cheap to operate
* Secure against cheating
* Easy to extend later (new cosmetics, seasons, monetization)
* Safe without a heavy backend

Additionally, the character style should:

* Avoid strict body-part alignment
* Favor expressive, code-driven animations
* Be visually consistent across devices and screen sizes

---

## High-Level Strategy (Key Decision)

> **Store all cosmetic assets and rules inside the app.
> Store only the player’s selected cosmetic IDs in Firestore.**

### Why this strategy?

* Cosmetics are **visual-only**
* All players share the same asset set
* Backend does not need to “understand” visuals
* Avoids storage, bandwidth, and sync complexity
* Supports offline rendering and instant previews

This keeps the system **simple now** and **scalable later**.

---

## Character Style Decision (New — Important)

> **Characters are composed of disconnected, floating “bubble” parts (Poptropica-style).**

### Why this matters

* No rigid skeletons or joints
* No exact alignment between parts required
* Animations are movement-based, not rig-based
* Dramatically reduces asset and animation complexity

This decision directly influences data structure, rendering, and asset sourcing.

---

## Phase 1 — Define the Character Data Contract

### What we do

Create a **CharacterProfile model** that only stores cosmetic IDs.

```json
characterProfile: {
  appearance: {
    head,
    body,
    feet
  },
  animations: {
    idle,
    run,
    capture,
    release,
    celebration
  },
  gear: {
    floatingItem,
    rideEffect
  },
  extras: {
    aura,
    proximitySound,
    profileBackground
  },
  version: 1
}
```

### Why we do this

* IDs are stable and lightweight
* No asset duplication
* Prevents invalid or hacked assets
* Matches the bubble-character model (no arms/legs dependency)
* Easy to migrate later using `version`

This remains the **single source of truth** for a player’s character.

---

## Phase 2 — Build the Cosmetic Catalog (In-App)

### What we do

Define a **local cosmetic catalog** in code.
Each cosmetic item represents a **self-contained visual or effect**.

```dart
CosmeticItem(
  id: "bubble_glass",
  slot: CosmeticSlot.head,
  assetPath: "assets/heads/bubble_glass.png",
  unlockLevel: 1,
)
```

### Why we do this

* Zero network dependency
* Instant loading
* Full control over availability
* Easy recolors and variants
* Prevents referencing missing assets

The app owns:

* What exists
* What it looks like
* How it animates
* When it unlocks

Firestore does **not**.

---

## Phase 3 — Main Menu Character Preview

### What we do

Render the player’s bubble character at the top of the Main Menu using:

* Saved `characterProfile`
* Local cosmetic catalog
* A single idle animation loop

### Why we do this

* Reinforces player identity
* Makes customization feel central
* Bubble animations are lightweight and expressive
* Cached assets → no lag

**Rule:**

> The preview is **read-only** and **idle-only**.

---

## Phase 4 — Customization Screen (Local-First)

### What we do

Create a **Character Customization Screen** with:

* Tabs: Appearance / Animations / Gear / Extras
* Live preview driven by **local state**
* Explicit **Save** action

### Flow

1. User selects items → preview updates instantly
2. Nothing is saved yet
3. User presses **Save**
4. Firestore is updated **once**

### Why we do this

* Avoids excessive writes
* Prevents partial saves
* Enables easy cancel/undo
* Safer if the app closes mid-edit

Firestore writes are **intentional**, not reactive.

---

## Phase 5 — Validation & Fallbacks

### What we do

When loading a saved profile:

* Validate each cosmetic ID against the local catalog
* Replace invalid or missing IDs with defaults

```dart
if (!catalog.contains(savedId)) {
  useDefault();
}
```

### Why we do this

* Handles removed or renamed cosmetics
* Prevents crashes after updates
* Supports seasonal or retired items
* Makes the system update-proof

---

## Phase 6 — Session Integration (Freeze-on-Start)

### What we do

When a game session starts:

* Load character profile
* Snapshot it locally
* Do **not** allow mid-session cosmetic changes

### Why we do this

* Prevents visual desync
* Keeps all players consistent
* Avoids network churn
* Ensures fairness

Cosmetics represent **identity**, not **live gameplay state**.

---

## Phase 7 — Performance & Rendering (Updated)

### What we do

Render the character as a **stack of independent visual layers**:

* Head bubble
* Body blob
* Feet / movement indicator
* Floating gear
* Aura / particle effects

Animations are:

* Bobbing
* Rotation
* Scaling
* Particles
* Trails

### Why we do this

* No skeletal animation required
* Very cheap to render
* Easy to extend with new effects
* Works perfectly for stylized characters
* Ideal for Flutter animation widgets

---

## Phase 8 — Unlocks & Progression (Optional, Later)

### What we do

Define unlock rules in the catalog:

```dart
unlock: UnlockCondition.level(10)
```

Supports:

* Level unlocks
* Achievements
* Seasonal cosmetics
* Future monetization

### Why we do this

* No backend logic required
* Offline-friendly
* Easy balancing
* Monetization-ready

---

## Phase 9 — Versioning & Future-Proofing

### What we do

Include a `version` field in `characterProfile`.

### Why we do this

* Enables migrations
* Allows adding new slots later (pets, companions, effects)
* Prevents breaking older users

---

## What This Plan Explicitly Avoids (On Purpose)

❌ Storing images in Firestore
❌ User-uploaded cosmetics (for now)
❌ Real-time cosmetic syncing
❌ Backend animation logic
❌ Gameplay-affecting cosmetics

Each avoided item removes:

* Cost
* Latency
* Cheating vectors
* Complexity

---

## Final Justification (Updated)

This implementation stores all cosmetic assets and animation logic directly in the app while persisting only lightweight cosmetic IDs in Firestore. By using a stylized, bubble-based character model with disconnected parts, the system avoids complex rigging, reduces asset constraints, improves performance, and enables expressive code-driven animations. Treating customization as a cosmetic identity layer ensures scalability, security, and future extensibility without introducing unnecessary backend complexity.

Absolutely — this is the **perfect next step**, because good **starter characters**:

* Set the visual tone of Chaser
* Teach players what *can* be customized
* Feel fair (no one starts “cooler” than others)
* Are easy to expand later

Below is a **clean, intentional starter lineup** designed specifically for your **bubble / disconnected character style**.

---

# Starter Character Set (Launch-Ready)

## Design Rules for Starters

All starter characters:

* Use **only base-tier cosmetics**
* Share the **same rarity**
* Differ by **personality, not power**
* Are recolors / simple variants (cheap to maintain)

This prevents:

* Early imbalance
* “Pay-to-look-cool” feelings
* Visual clutter

---

## Starter Set Size (Recommended)

**3–5 characters** is ideal.

I recommend **4 starters** so players feel choice without overload.

---

## Starter Characters

---

## 1. **Runner Blue** (Default / Balanced)

**Vibe:** Clean, neutral, athletic
**Role fantasy:** “I’m here to compete”

### Appearance

```json
head: "bubble_clear"
body: "blob_blue"
feet: "dots_standard"
```

### Animations

```json
idle: "idle_bob_soft"
run: "run_bounce_standard"
celebration: "celebrate_spin_small"
```

### Extras

```json
aura: "none"
proximitySound: "beep_soft"
```

**Why this works**

* Safe default
* Reads clearly on all backgrounds
* Becomes the “baseline” visual

---

## 2. **Pulse Red** (Aggressive / Chaser Energy)

**Vibe:** Intense, fast, competitive
**Role fantasy:** “I hunt”

### Appearance

```json
head: "bubble_glass_red"
body: "blob_red"
feet: "dots_fast"
```

### Animations

```json
idle: "idle_pulse"
run: "run_bounce_fast"
celebration: "celebrate_pop"
```

### Extras

```json
aura: "aura_pulse_red"
proximitySound: "beep_sharp"
```

**Why this works**

* Feels fast without affecting gameplay
* Strong visual identity
* Teaches players about animation differences

---

## 3. **Drift Green** (Calm / Runner Energy)

**Vibe:** Chill, smooth, evasive
**Role fantasy:** “You won’t catch me”

### Appearance

```json
head: "bubble_matte_green"
body: "blob_green"
feet: "dots_float"
```

### Animations

```json
idle: "idle_float"
run: "run_glide"
celebration: "celebrate_wave"
```

### Extras

```json
aura: "trail_soft_green"
proximitySound: "beep_soft_low"
```

**Why this works**

* Contrasts with aggressive styles
* Encourages player expression
* Uses motion instead of color intensity

---

## 4. **Neon Yellow** (Flashy / Fun)

**Vibe:** Energetic, playful, chaotic
**Role fantasy:** “Watch me go”

### Appearance

```json
head: "bubble_neon_yellow"
body: "blob_yellow"
feet: "dots_blink"
```

### Animations

```json
idle: "idle_jiggle"
run: "run_bounce_erratic"
celebration: "celebrate_spin_big"
```

### Extras

```json
aura: "spark_neon_yellow"
proximitySound: "beep_double"
```

**Why this works**

* Fun without being premium
* Shows off particle effects
* Memorable on screen

---

# How Players Choose a Starter

### First Launch Flow

1. Quick intro screen
2. “Choose your runner”
3. Carousel preview with idle animation
4. Confirm → saved as initial `characterProfile`

### Why this is good

* Immediate personalization
* No tutorial overload
* Makes the game feel *theirs* instantly

---

# Important: Starters Are Not Locked Forever

Players can later:

* Mix parts freely
* Recreate starter looks
* Evolve them into unique identities

Starters are **presets**, not classes.

---

# Asset Cost Control Tip

All starters can be built from:

* **Same shapes**
* **Different colors**
* **Different animation parameters**

This keeps asset count small.

---

## Optional Fifth Starter (If You Want Variety)

### **Shadow Gray**

Minimalist, stealthy, low-glow
Great for competitive players who want less visual noise.

---

## Final Recommendation

Launch with:

* **Runner Blue (default)**
* **Pulse Red**
* **Drift Green**
* **Neon Yellow**

This gives:

* Clear identity
* Visual diversity
* No balance issues
* Strong foundation for future cosmetics

Main 4 characters added to chaser/assets/Chaser_Starter_Assets