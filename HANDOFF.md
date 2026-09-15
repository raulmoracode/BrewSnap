# BrewSnap — Handoff de Iteraciones

> Documento vivo donde se registra cada iteración del desarrollo. Cada entrada incluye: fecha, objetivo, cambios realizados, decisiones, estado del build y próximos pasos. Sirve como memoria del proyecto y punto de entrada para retomar trabajo en cualquier momento.

---

## Cómo usar este documento

- **Una iteración = un bloque `## Iteración N`** con fecha, rama y resumen.
- Mantener orden cronológico descendente (la última iteración arriba).
- Marcar estado: `🟢 Completada` / `🟡 En curso` / `🔴 Bloqueada`.
- Referenciar archivos clave con `ruta:línea` cuando sea relevante.
- Al cerrar una iteración, actualizar también la tabla de resumen.

---

## Resumen de iteraciones

| # | Fecha | Objetivo | Estado | Branch | Commit / Tag |
|---|-------|----------|--------|--------|--------------|
| 0 | 2026-09-15 | Bootstrap + MVP compilable (Fase 1: Snapshot, GitHub, Sync, Perfiles) | 🟢 Completada | `main` | — |
| 1 | — | Import en nueva máquina + Diff + dry-run | 🔜 Pendiente | — | — |
| 2 | — | Menu bar + Historial + Auto-snapshot | 🔜 Pendiente | — | — |

---

## Iteración 0 — Bootstrap + MVP compilable (Fase 1)

**Fecha:** 2026-09-15  
**Estado:** 🟢 Completada  
**Branch:** `main`  
**Objetivo:** Crear el handoff, inicializar el proyecto Xcode (Swift 6 / SwiftUI / macOS 15+) y dejar un MVP compilable de Fase 1 según `README.md:26-177`.

### Contexto

- Proyecto vacío: solo existía `README.md:1-370`.
- Stack en `README.md:28-33`: Swift 6, SwiftUI, macOS 15+, GitHub API v3, Keychain, Process, @Observable.
- Estructura objetivo en `README.md:37-71` y modelo JSON en `README.md:73-127`.
- Features Fase 1 en `README.md:133-177`: Snapshot, GitHub Integration, Sync, Perfiles.
- Restricción 2 repos en `README.md:330-352`.

### Cambios realizados

- [x] Creado `HANDOFF.md` (este archivo) como registro de iteraciones (`HANDOFF.md:1-105`).
- [x] Scaffold Xcode: `BrewSnap.xcodeproj/project.pbxproj:1-334` con `PBXFileSystemSynchronizedRootGroup` (Xcode 16+), target `BrewSnap`, bundle `com.raulmorasanchez.BrewSnap` (`README.md:315`), deployment target macOS 15.0, Swift 6, `SWIFT_STRICT_CONCURRENCY=complete`.
- [x] Estructura: `BrewSnap/App/`, `Views/`, `Views/Components/`, `Models/`, `Services/`, `Utilities/`, `Resources/Assets.xcassets` (con `AppIcon` + `AccentColor #FBB040`).
- [x] App: `BrewSnap/App/BrewSnapApp.swift:1-38` (WindowGroup + MenuBarExtra + Settings), `App/AppState.swift:1-41` (@Observable, Keychain + UserDefaults para token/repo).
- [x] Models faithful al JSON `README.md:74-126`: `Models/BrewSnapshot.swift:1-92` (Codable con init custom para compat), `Models/Package.swift:1-28` (BrewFormula/BrewCask), `Models/Tap.swift:1-8`, `Models/Service.swift:1-18` (BrewService), `Models/Profile.swift:1-13`.
- [x] Utilities: `Utilities/ShellExecutor.swift:1-73` (wrapper Process + `runShell` vía zsh -l), `Utilities/JSONEncoder+Pretty.swift:1-38` (encoder brewsnap + toPrettyJSON), `Utilities/VersionHelper.swift:1-62` (parseBrewVersions, tap-info, services, systemInfo).
- [x] Services (Fase 1 completos): `Services/BrewService.swift:1-134` (`HomebrewService` scan formulae/casks/taps/services/pinned/diskUsage), `Services/SnapshotService.swift:1-27`, `Services/GitHubService.swift:1-106` (validate, createPrivateRepo, fetchFile, putFile, commitSnapshot vía `PUT /contents`), `Services/DiffService.swift:1-68`, `Services/KeychainService.swift:1-56`.
- [x] Views MVP 3 pestañas: `Views/MainView.swift:1-46` (NavigationSplitView), `Views/ExportView.swift:1-119` (Create Snapshot → preview JSON + lista formulae/casks/taps), `Views/SyncView.swift:1-93` (Create Private Repo + Update), `Views/ProfilesView.swift:1-56` (work/personal/dev + Diff preview), `Views/SettingsView.swift:1-71` (token Keychain + validar `GET /user`), `Views/MenuBarView.swift:1-40`, componentes `PackageRow`, `StatusBadge`, `DiffView`.
- [x] Ajuste conflicto de nombres: `BrewService` (modelo `Models/Service.swift:3`) vs `HomebrewService` (actor `Services/BrewService.swift:15`) — renombrado actor para resolver ambigüedad `BrewService is ambiguous`.
- [x] Fix Swift 6 isolation: `actor` → `final class: Sendable` en BrewService/GitHubService para evitar `main actor-isolated` errors.
- [x] Fix `UniformTypeIdentifiers` import para `.json` en `Views/ExportView.swift:95`.
- [x] Verificación: `xcodebuild -project BrewSnap.xcodeproj -scheme BrewSnap -configuration Debug build` → **BUILD SUCCEEDED** (2026-09-15).

### Decisiones técnicas

| Decisión | Alternativa descartada | Motivo |
|----------|------------------------|--------|
| Xcode project con `PBXFileSystemSynchronizedRootGroup` (Xcode 16+) | Listado manual de 24 PBXBuildFile | Nuevo estándar Xcode 27, evita olvidar ficheros, autogenera DerivedSources |
| `@Observable` macro (Swift 6) | `ObservableObject` + Combine | Alineado con `README.md:33` y Swift 6 strict concurrency |
| `Process` + `ShellExecutor` vía `/bin/zsh -l -c` | `Process` inline por vista | Centraliza PATH de brew (shims) y testabilidad; `-l` carga login shell |
| `final class: Sendable` en Services | `actor` | Actor aislaba helpers (`isSuccess`, `parseBrewVersions`) y bloqueaba `toPrettyJSON()` cross-actor |
| `UniformTypeIdentifiers` para `.json` | `kUTTypeJSON` legacy | Swift 6 member import visibility |
| Bundle `com.raulmorasanchez.BrewSnap` + `com.apple.product-type.application` macOS only | Multiplatform target | README pide macOS 15+ nativo, simplifica entitlements/sandbox |

### Verificación

- Comando: `xcodebuild -project BrewSnap.xcodeproj -scheme BrewSnap -configuration Debug build`
- Resultado: **BUILD SUCCEEDED** (único warning: `appintentsmetadataprocessor` sin AppIntents, inocuo)
- Artefacto: `DerivedData/BrewSnap-.../Build/Products/Debug/BrewSnap.app`
- Pendiente manual: `open BrewSnap.xcodeproj` → Cmd+R → probar Create Snapshot con brew real y validar token.

### Pendientes / Riesgos

- [ ] Validar que `brew` esté en PATH dentro de app sandboxed (`ENABLE_APP_SANDBOX=YES` puede bloquear `Process`). Si falla, desactivar sandbox o añadir entitlement `com.apple.security.cs.allow-unsigned-executable-memory`.
- [ ] `brew services list --json` output varía según versión — testear parse real.
- [ ] Sync actual usa `PUT /contents` directo (no git clone/pull en `/tmp` como describe `README.md:170`). Para Fase 1 es suficiente, pero para historial/timeline habrá que migrar a clone local.
- [ ] Añadir `.gitignore` para `DerivedData/`, `*.xcuserstate`.

### Próximos pasos

1. **Iteración 1 — Import & Diff (Fase 2)**: `Import from repo` (descarga JSON, checklist, taps→formulae→casks→services, barra progreso), `Diff entre máquinas` vista completa, dry-run.
2. **Iteración 2 — Menu bar + Historial + Auto-snapshot (Fase 3 parcial)**: MenuBarExtra pulido, `GET /commits` timeline, watcher `brew` background.
3. **Iteración 3 — Distribución**: Workflow GitHub Actions para DMG + update `homebrew-tap` (`README.md:346-352`).

---

## Plantilla para nuevas iteraciones

```markdown
## Iteración N — Título corto

**Fecha:** YYYY-MM-DD
**Estado:** 🟢 Completada | 🟡 En curso | 🔴 Bloqueada
**Branch:** `nombre-rama`
**Objetivo:** Una frase clara.

### Cambios realizados
- [ ] Item 1 (`ruta/archivo:línea`)
- [ ] Item 2

### Decisiones técnicas
| Decisión | Alternativa | Motivo |
|----------|-------------|--------|

### Verificación
- Comando: `xcodebuild ...`
- Resultado: OK / FAIL (log relevante)

### Próximos pasos
- ...
```

---

## Notas y convenciones

- Bundle ID canónico: `com.raulmorasanchez.BrewSnap` (`README.md:315`).
- Colores de marca: `#FBB040` (naranja brew) + `#1D3557` (azul) (`README.md:314`).
- Commits de sync: `snapshot: 67 formulae, 23 casks — YYYY-MM-DD` (`README.md:243`).
