---
name: swiftui-ios16-compat
description: SwiftUI compatibility for iOS 16 targets. Use when fixing compile errors for iOS 16 related to .onChange(of:) or .toolbar(content:), or when writing new SwiftUI code that must run on iOS 16.
---

# SwiftUI iOS 16 Compatibility

This skill describes how to fix common SwiftUI compile failures when the deployment target is iOS 16. Apply it when you see the errors below or when adding/modifying `.onChange` or `.toolbar` in a project targeting iOS 16.

## 1. `.onChange(of:)` — Single vs two-parameter closure

### What goes wrong

- **iOS 17+** uses a two-parameter closure: `{ oldValue, newValue in ... }`.
- **iOS 16** only has the single-parameter form: `{ newValue in ... }` (the new value only).

Code written for iOS 17 that uses `{ _, newValue in ... }` or `{ oldValue, newValue in ... }` will **not compile** when the target is iOS 16.

### Fix (behavior unchanged)

Use a **single-parameter** closure. Drop the first (old value) parameter.

```swift
// Wrong on iOS 16:
.onChange(of: value) { _, newValue in
    if newValue { doSomething() }
}

// Correct for iOS 16:
.onChange(of: value) { newValue in
    if newValue { doSomething() }
}
```

Logic stays the same; only the closure signature changes.

---

## 2. `.toolbar(content:)` — Ambiguous use

### Error you may see

- **"Ambiguous use of 'toolbar(content:)'"** with two candidates:
  - `toolbar(@ViewBuilder content: () -> Content) where Content : View`
  - `toolbar(@ToolbarContentBuilder content: () -> Content) where Content : ToolbarContent`

The compiler cannot choose between the View and ToolbarContent overloads when the closure return type is not explicit.

### What NOT to do (these do not fix it or introduce new errors)

- Adding the `content:` label only: still ambiguous.
- Switching to `ToolbarItemGroup` or changing placement (e.g. `.navigationBarLeading`): may still be ambiguous.
- Using a **computed property** and passing it: `private var cancelToolbarContent: some ToolbarContent { ... }` then `.toolbar(content: cancelToolbarContent)` — still ambiguous.
- Using an **explicit closure return type** with `some`:  
  `.toolbar(content: { () -> some ToolbarContent in ... })`  
  This triggers: **"'some' types are only permitted in properties, subscripts, and functions"** — you cannot use `some` as the return type of a closure in Swift.

### Correct fix: method returning `some ToolbarContent`

Use a **method** (not a property) annotated with `@ToolbarContentBuilder` that returns `some ToolbarContent`. Then pass the **method reference** to `.toolbar(content:)`. The method’s return type is `some ToolbarContent`, which is allowed; the compiler then unambiguously selects the `@ToolbarContentBuilder` overload.

**Step 1 — Define a method:**

```swift
@ToolbarContentBuilder
private func cancelToolbarContent() -> some ToolbarContent {
    ToolbarItem(placement: .navigationBarLeading) {
        Button("Cancel") { isPresented = false }
            .foregroundColor(Color("RoyalBlue"))
            .font(.headline)
    }
}
```

**Step 2 — Use the method reference (no closure):**

```swift
.toolbar(content: cancelToolbarContent)
```

Do **not** wrap it in a closure. Passing the method name is enough; its type is `() -> some ToolbarContent`, which disambiguates the overload.

### Same pattern for principal (centered) title

```swift
@ToolbarContentBuilder
private func principalToolbarContent() -> some ToolbarContent {
    ToolbarItem(placement: .principal) {
        Text("The Word")
            .font(.system(size: 36, weight: .bold))
            .foregroundColor(.white)
    }
}

// In body:
.toolbar(content: principalToolbarContent)
```

---

## When to use this skill

- Project or target has **iOS 16** (or lower) as minimum deployment.
- You see **"Ambiguous use of 'toolbar(content:)'"** or **"'some' types are only permitted in properties, subscripts, and functions"** when using `.toolbar(content:)`.
- `.onChange(of:)` fails to compile with a two-parameter closure.

Prefer applying the fixes above directly instead of trying alternative placements or closure shapes; that avoids repeated failed attempts.
