# AI Coding Assistant Guidelines for Roblox Script Development

This document serves as the architectural standard and development handbook for AI coding assistants working on this codebase (and future Roblox script projects). Follow these principles, patterns, and guidelines strictly to ensure performant, stable, and conflict-free code.

---

## 1. Project Structure & Modular Design

Organize the codebase cleanly into distinct directory layers:
*   **/core**: Generic, game-agnostic utilities (localization, networking, state management, thread locking).
*   **/features**: Game-specific features, loops, and behaviors.
*   **main.lua / loader.lua**: The entry point that initializes the UI, loads core libraries, and activates features.

### Dependency Injection (Context Pattern)
Do **not** pass individual dependencies as loose function arguments (e.g., `function(Window, Utils, Webhook)`). Instead, group them into a single `ctx` (Context) object injected into all features.

```lua
-- Example Feature Structure
return function(ctx)
    local Utils = ctx.Utils
    local Controller = ctx.SystemController
    local Config = ctx.Config
    
    -- Feature logic here...
end
```

---

## 2. Centralized State & Config Management

*   **Single Source of Truth:** Avoid scattered config files (`*.json`) for each feature. Use a centralized configuration module (`core/config_manager.lua`) to read, write, and serialize settings.
*   **Encapsulation:** Features must query state using `ctx.Config:Get("FeatureName.Setting")` rather than mutating global variables.

---

## 3. Cooperative Multitasking (Mutex Locking)

Roblox exploits run in separate threads. To prevent features from fighting over character control (teleporting, attacking, riding mounts):
*   **Register Locks:** All features that teleport or manipulate character position must register with the `SystemController`.
*   **Acquire & Release:** Before performing any movement, request a lock. Release the lock as soon as the task completes to yield to other modules.

```lua
-- Mutex Lock Pattern
local hasLock = Controller.RequestLock("AutoDungeon")
if hasLock then
    -- Perform CFrame teleport / combat...
    Controller.ReleaseLock("AutoDungeon")
else
    -- Standby or pause behavior...
end
```

---

## 4. Event-Driven Programming over Polling (CPU Optimization)

Avoid heavy polling loops (`while task.wait(0.5) do`) to query UI changes, instance existence, or event changes. Polling wastes CPU cycles and reduces FPS, especially during multiboxing.

*   **Instance Detection:** Use `Workspace.ObbyEventFolder.ChildAdded` or `ChildRemoved` to detect mini-games rather than loop scanning.
*   **UI Updates:** Use `Instance:GetPropertyChangedSignal("Text")` or `GetPropertyChangedSignal("Visible")` to listen to game state changes dynamically.
*   **Throttling:** If a loop is absolutely necessary, adjust the interval based on importance (e.g., combat scanning = `0.1s`, lobby check = `2s`).

---

## 5. Safe Teleportation & Anti-Fall Mechanisms

Teleporting in Roblox can cause characters to fall out of the world if game assets or collision parts have not loaded locally (due to `StreamingEnabled`).

*   **Dismount Check:** Always check if the player is riding a mount. Call the dismount remote and jump the character before changing `CFrame` positions to prevent character model glitching.
*   **Safe Platforms:** Spawn a temporary anchored platform (`BasePart`) below the destination coordinates just before teleportation. Clean it up once the feature ends.
*   **CFrame Offsets:** When teleporting above a target (e.g. monsters, chests), offset the Y coordinate (`Vector3.new(0, 3.5, 0)`) to avoid clipping into models.

---

## 6. Structured Error Handling (SafeCall)

Do **not** use raw `pcall` blocks that swallow errors silently. Swallow-only error handling makes remote diagnostics impossible.

*   **xpcall with Stack Traces:** Implement a wrapper `Utils.SafeCall(func, errorContext)` using `xpcall` to retrieve the exact line number and stack trace of any failure.
*   **Debug Logs:** Output errors to the developer console (`warn`) or dispatch them to a private Discord Webhook only if Debug Mode is enabled in settings.

---

## 7. File Extensions and Build System

*   **File Naming:** Write all script files with `.lua` or `.luau` extensions to enable IDE syntax highlighting, autocomplete, code linting (e.g., Selene/Luau), and auto-formatting (e.g., StyLua).
*   **Bundling:** Use `bundle.py` (or a similar build script) to automatically parse, assemble, and compress modular development files into a single production bundle.

---

## 8. General Coding Conventions

*   **Local Variables:** Cache services and global APIs locally at the top of every file (e.g., `local Players = game:GetService("Players")`).
*   **Attributes Check:** Use `Instance:GetAttribute()` for network-replicated states instead of creating Value objects.
*   **Virtual Input Safety:** When simulating keyboard presses (like spamming `E` prompt), use `fireproximityprompt` if available; otherwise, wrap key events in short delays to prevent prompt failure.
