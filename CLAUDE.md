# CLAUDE.md — Workspace Execution Directive

## 🚨 STRICT COMPLIANCE CORE RULE
* **YOU ARE A PURE EXECUTOR OF THE PRD.md SPECIFICATION.**
* **DO NOT** innovate, extrapolate, or implement any feature, button, toggle, or capability that is not explicitly declared inside `PRD.md`.
* **DO NOT** expand codebase code blocks beyond the exact Milestone currently requested by the user. Keep modifications tightly bound to the current context.

## ⚠️ CRITICAL AI AGENT WORKFLOW GUIDELINE
* You are operating in a split workspace model (VS Code edits files, Xcode builds and compiles code targets).
* **NEVER WRITE LOGIC INTO A NEW OR NON-EXISTENT FILE WITHOUT EXPLICIT USER CONFIRMATION.**
* If a target file does not yet exist within the workspace directory, instruct the user to create the empty file inside Xcode via the `Cmd + N` system protocol first. This ensures Xcode writes correct physical layout references into the complex `.xcodeproj/project.pbxproj` indexing table.

## 💻 Technical Code Commitments & Guardrails
* **UI Paradigms:** 100% Native declarative SwiftUI design. Integration of old UIKit wrappers or bridging code blocks is prohibited unless expressly requested by the user.
* **Concurrency Protocols:** Exclusively apply structured Swift Concurrency strategies (`async/await`, `Task`, `Actors`, and `@MainActor` decorators). Legacy multi-threading structures such as `DispatchQueue.main.async` or GCD loops are strictly banned.
* **Error Mitigation Rules:** Always handle optionals safely via deterministic `guard let` or `if let` fallback structures. Force-unwrapping operators (`!`) are forbidden unless isolating mock parameters inside test suites.
* **Data Flow Mechanics:** Implement the modern `@Observable` state macro design structures across Views and ViewModels. Maintain absolute isolation boundaries between state engines and persistence wrappers.

## 🏎️ Performance Boundaries & Resource Control
1. **Zero Framing Hitch Overhead:** Complex text string parsers, regular expression comparisons, and Natural Language parsing loops must be strictly confined to background Actors. Never execute parsing logic on the main presentation thread.
2. **SwiftData Thread Decoupling:** SwiftData entities are non-Sendable across async actor environments. Never bridge a database record directly across different thread contexts; forward the object's `PersistentIdentifier` and parse the target context inside the destination actor.
3. **Air-Gapped Local Target Verification:** Initialize the transcription framework strictly with `requiresOnDeviceRecognition = true`. Catch and surface errors cleanly if local asset libraries are unavailable.