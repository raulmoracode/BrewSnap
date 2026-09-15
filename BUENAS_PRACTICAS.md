# Swift Best Practices for Clean Code (Ready for AI)

Checklist for writing clear and organized Swift before passing it to an AI.

## 1. Structure and Organization

- [ ] One type per file (or few if closely related)
- [ ] File name matches main type (`UserProfileView.swift`, not `Screen2.swift`)
- [ ] Separation by layers: Models, Views, ViewModels, Services, Utils
- [ ] Use `// MARK: -` to group sections in long files

## 2. Clear Names

- [ ] Descriptive and complete names (`fetchUserProfile()`, not `fetch()` or `f1()`)
- [ ] Standard conventions: `camelCase` for variables/functions, `PascalCase` for types
- [ ] No ambiguous abbreviations (except standard like `id`, `url`)
- [ ] Booleans that read as questions: `isLoading`, `hasError`, `canSubmit`

## 3. Small Functions and Types

- [ ] Short functions, single responsibility
- [ ] If a function needs comments for internal "sections", split it
- [ ] Avoid functions with many parameters (use configuration structs)
- [ ] Prefer `struct` over `class` when you don't need inheritance or reference identity

## 4. Typing and Safety

- [ ] Avoid `Any`, `AnyObject` and force unwraps (`!`)
- [ ] Use `guard let` / `if let` instead of `!`
- [ ] Enums with associated values instead of magic strings or combined boolean flags
- [ ] Avoid `as!`; use `as?` with failure handling

## 5. Error Handling

- [ ] Use `throws` / `Result` instead of silencing errors or returning `nil` without context
- [ ] Define custom error types (`enum NetworkError: Error`) instead of generic `NSError`

## 6. Comments and Documentation

- [ ] Comment the **why**, not the what
- [ ] Use `///` to document public or complex functions
- [ ] Brief comment at the top of the file explaining its general purpose

## 7. Consistency

- [ ] Single format style (indentation, braces, spaces)
- [ ] Use **SwiftLint** or **swift-format** to automate style
- [ ] Consistent order: properties → initializers → public methods → private methods

## 8. Explicit Dependencies

- [ ] Avoid singletons and hidden global state (`UserDefaults.standard` scattered)
- [ ] Inject dependencies in `init`

## 9. Before Passing to an AI

- [ ] Remove dead code (unused functions, old comments, obsolete `// TODO`)
- [ ] Remove sensitive data: API keys, tokens, internal URLs, real client names
- [ ] Pass only the relevant fragment + context of used types (protocols, related structs) if the project is large
- [ ] Indicate Swift version and target (iOS/macOS, SwiftUI/UIKit)
