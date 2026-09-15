# BrewSnap

**Tu entorno Homebrew, sincronizado y protegido.**

App nativa macOS (SwiftUI) que exporta el estado de Homebrew a JSON y lo sincroniza automáticamente con un repositorio privado en GitHub.

---

## Problema

Cuando cambias de Mac o reinstalas macOS, pierdes todo tu entorno Homebrew:
- No sabes qué paquetes tenías instalados
- `brew bundle` genera un Brewfile (Ruby DSL) que no es legible ni diffable
- No recuerdas las versiones exactas que tenías
- No existe una forma cómoda de gestionar backups sin tocar la terminal

## Solución

BrewSnap es una app nativa macOS que:
1. Escanea tu entorno Homebrew (formulae, casks, taps, servicios)
2. Genera un JSON limpio y versionado
3. Lo sincroniza con un repositorio privado en GitHub — un clic, sin comandos git

---

## Arquitectura

### Stack
- **Swift 6** / **SwiftUI** / **macOS 15+ (Sequoia)**
- **GitHub API v3** (octokit.swift o URLSession directa) para crear repos y push
- **Keychain** para almacenar el token GitHub de forma segura
- **Process** para ejecutar comandos `brew` internamente
- **Combine** / **@Observable** para data flow

### Estructura del proyecto

```
BrewSnap/
├── App/
│   ├── BrewSnapApp.swift           # Entry point, menú bar + ventana
│   ├── AppState.swift              # Estado global observable
├── Views/
│   ├── MainView.swift              # Ventana principal con las 3 pestañas
│   ├── MenuBarView.swift           # Menu bar extra (icono + acciones rápidas)
│   ├── ExportView.swift            # Vista de exportar / crear snapshot
│   ├── ProfilesView.swift          # Lista de perfiles (work, personal, etc.)
│   ├── SyncView.swift              # Estado de sync con GitHub
│   ├── SettingsView.swift          # Configuración (token, repo, etc.)
│   └── Components/
│       ├── PackageRow.swift        # Fila de paquete con nombre + versión
│       ├── StatusBadge.swift       # Badge de estado (synced, out of sync, etc.)
│       └── DiffView.swift          # Vista de diferencias entre snapshots
├── Models/
│   ├── BrewSnapshot.swift          # Modelo principal del JSON
│   ├── Package.swift               # Modelo de paquete (formula/cask)
│   ├── Tap.swift                   # Modelo de tap
│   ├── Service.swift               # Modelo de servicio
│   └── Profile.swift               # Modelo de perfil
├── Services/
│   ├── BrewService.swift           # Interfaz con brew CLI (scan, install, etc.)
│   ├── GitHubService.swift         # API GitHub: crear repo, commit, push
│   ├── SnapshotService.swift       # Generación y lectura de snapshots JSON
│   ├── DiffService.swift           # Comparación entre dos snapshots
│   └── KeychainService.swift       # Almacenamiento seguro del token
├── Utilities/
│   ├── ShellExecutor.swift         # Wrapper para Process (ejecutar brew/git)
│   ├── JSONEncoder+Pretty.swift    # Encoder JSON con formato legible
│   └── VersionHelper.swift         # Parseo de versiones de brew
└── Resources/
    └── Assets.xcassets/
```

### Modelo de datos (JSON)

```json
{
  "version": 1,
  "createdAt": "2026-09-15T12:00:00Z",
  "hostname": "MacBook-Pro-de-Raul",
  "macOS": "15.7",
  "arch": "arm64",
  "homebrew": "7.0.0",
  "formulae": [
    {
      "name": "git",
      "version": "2.47.0",
      "tap": null,
      "pinned": false,
      "kegOnly": false,
      "installedOnRequest": true
    },
    {
      "name": "python@3.13",
      "version": "3.13.7",
      "tap": null,
      "pinned": true,
      "kegOnly": false,
      "installedOnRequest": true
    }
  ],
  "casks": [
    {
      "name": "visual-studio-code",
      "version": "1.93.0",
      "tap": null,
      "autoUpdate": true
    }
  ],
  "taps": [
    {
      "name": "hashicorp/tap",
      "remote": "https://github.com/hashicorp/homebrew-tap",
      "trusted": true
    }
  ],
  "services": [
    {
      "name": "postgresql@16",
      "status": "started",
      "restart": true
    }
  ],
  "formulaeCount": 67,
  "casksCount": 23,
  "totalDiskUsage": "4.2 GB"
}
```

---

## Features

### Fase 1 — MVP

#### 1. Snapshot (Exportar)
- Botón **"Create Snapshot"**
- Ejecuta internamente:
  - `brew list --formulae --versions` → parsear nombre + versión
  - `brew list --casks --versions` → parsear nombre + versión
  - `brew tap` → lista de taps
  - `brew tap-info --json` → remote URL, trusted status
  - `brew services list --json` → estado de servicios
  - `brew pin` → paquetes congelados
  - `brew --prefix` → info del sistema
- Genera el JSON con toda la metadata
- Muestra preview del JSON en la app antes de subir

#### 2. GitHub Integration
- Botón **"Create Private Repo"**
  - Usa GitHub API (`POST /user/repos`) para crear repositorio privado
  - Nombre: `brewsnap` (o configurable)
  - Almacena el token en Keychain
  - Primera vez: pedir token GitHub con permisos `repo`
  - Flujo:
    1. Pedir token al usuario (con link a GitHub Settings > Tokens)
    2. Validar token con `GET /user`
    3. Crear repo con `POST /user/repos { "private": true }`
    4. Guardar repo name en UserDefaults

#### 3. Sync (Update automático)
- Botón **"Update"**
  - Genera nuevo snapshot automáticamente
  - Compara con el JSON anterior en el repo
  - Si hay cambios:
    1. `git add brewsnap.json`
    2. `git commit -m "snapshot: 67 formulae, 23 casks — $(date)"`
    3. `git push`
  - Si no hay cambios: muestra "Already up to date"
  - Todo sin intervención del usuario
  - Flujo técnico: clone/pull el repo en un directorio temporal, generar JSON, comparar, commit si hay diff, push

#### 4. Perfiles
- Guardar múltiples snapshots con nombre
- Ejemplo: `work.json`, `personal.json`, `dev.json`
- Cada perfil es un archivo JSON independiente en el repo
- Botón para cambiar de perfil activo

### Fase 2 — Importar

#### 5. Importar en nueva máquina
- Botón **"Import from repo"**
  - Descarga el JSON del repo
  - Muestra lista de paquetes a instalar con checkboxes
  - Opción de dry-run (ver qué instalaría sin instalar)
  - Instala en orden: taps → formulae → casks → servicios
  - Progreso en tiempo real (barra de progreso + log)
  - Al terminar: snapshot automático del estado actual

#### 6. Diff entre máquinas
- Botón **"Compare"**
  - Selecciona dos snapshots (o dos perfiles)
  - Muestra diferencias:
    - Paquetes solo en máquina A
    - Paquetes solo en máquina B
    - Paquetes con versiones diferentes
    - Taps diferentes
  - Vista tipo `git diff` con colores

### Fase 3 — Extras

#### 7. Menu bar
- Icono en la barra de menús
- Muestra estado: número de paquetes, última sync
- Click rápido: crear snapshot, abrir ventana principal
- Notificaciones: "Tu snapshot está desactualizado" (si detecta cambios)

#### 8. Historial
- Ver historial de commits del repo en la app
- Cada snapshot es un commit con mensaje descriptivo
- Botón para restaurar un snapshot anterior (checkout + import)
- Timeline visual de cambios

#### 9. Auto-snapshot
- Opcional: detectar cambios en brew automáticamente
- Ejemplo: después de cada `brew install` o `brew upgrade`
- Background service que vigila el estado de brew
- Preguntar antes de subir cambios

#### 10. Markdown del snapshot
- Generar un `SNAPSHOT.md` legible en el repo
- Tabla de paquetes con nombre, versión, tap, tamaño
- Historial de cambios con fechas
- Stats: total paquetes, espacio en disco, tendencia

---

## Flujo de usuario

### Primera vez
```
1. Abrir BrewSnap
2. Introducir token de GitHub (con link de ayuda)
3. Clic "Create Private Repo" → se crea brewsnap en GitHub
4. Clic "Create Snapshot" → escanea brew → genera JSON → sube al repo
5. Listo. La app queda en menu bar monitorizando
```

### Actualización diaria
```
1. Usuario instala/actualiza paquetes con brew normalmente
2. Clic "Update" en BrewSnap (o auto-snapshot si está activado)
3. La app detecta los cambios, genera JSON y sube al repo
4. Commit automático: "snapshot: 69 formulae (+2), 23 casks — 2026-09-15"
```

### Nueva máquina
```
1. Instalar BrewSnap desde DMG (release de github) o `brew install raulmoracode/tap/brewsnap`
2. Introducir token de GitHub (o usar el mismo si ya lo tienes)
3. Clic "Import from repo"
4. Seleccionar perfil (work/personal)
5. Ver lista de paquetes → clic "Install"
6. BrewSnap instala todo en orden con progreso visual
7. Snapshot automático del estado final
```

---

## Datos de brew necesarios

```bash
# Info del sistema
brew --prefix          # /opt/homebrew
brew --version         # Homebrew version
uname -m               # arm64 o x86_64
sw_vers -ProductVersion  # macOS version

# Formulae
brew list --formulae --versions    # nombre + versión
brew list --formulae               # solo nombres
brew outdated --formulae           # cuáles están desactualizados
brew pin                           # paquetes congelados
brew missing                       # dependencias rotas

# Casks
brew list --casks --versions       # nombre + versión
brew list --casks                  # solo nombres
brew outdated --casks              # cuáles están desactualizados

# Taps
brew tap                            # taps instalados
brew tap-info --json                # info detallada de cada tap

# Servicios
brew services list                  # estado de servicios

# Disc Usage
du -sh $(brew --cellar)             # espacio total
du -sh $(brew --prefix)/Caskroom   # espacio de casks
```

---

## GitHub API que usamos

```
POST /user/repos                    # Crear repo privado
GET  /user                          # Validar token
GET  /repos/{owner}/{repo}/contents/{path}  # Leer archivo del repo
PUT  /repos/{owner}/{repo}/contents/{path}  # Crear/actualizar archivo
GET  /repos/{owner}/{repo}/commits          # Historial de commits
DELETE /repos/{owner}/{repo}                # Eliminar repo (opcional)
```

Cada "sync" es un `PUT /contents/{path}` que crea un commit automático.

---

## Nombre y branding

- **Nombre**: BrewSnap
- **Tagline**: "Tu entorno Homebrew, sincronizado y protegido"
- **Icono**: Un grifo (faucet) con una flecha circular → representa "snap" del estado
- **Color**: Naranja brew (#FBB040) + azul oscuro (#1D3557)
- **Bundle ID**: `com.raulmorasanchez.BrewSnap`

---

## Requisitos mínimos

- macOS 15.0 (Sequoia) o superior
- Homebrew instalado
- Token de GitHub con permisos `repo` (privado)
- ~20 MB de espacio en disco

---

## Repositorios (importante para cualquier IA con contexto)

BrewSnap se distribuye con **2 repositorios separados**. Esto es una restricción de
Homebrew: el comando `brew install raulmoracode/tap/brewsnap` resuelve
obligatoriamente a `github.com/raulmoracode/homebrew-tap`
(ver `docs.brew.sh/Taps`: `brew tap <user>/<repo>` clona `homebrew-<repo>`).

1. **`raulmoracode/brewsnap`** — este repositorio. Todo el código de la app,
   releases (DMG) y esta documentación.
2. **`raulmoracode/homebrew-tap`** — repositorio mínimo que solo contiene
   `Casks/brewsnap.rb` (el cask que apunta al DMG del release).

No usar el tap oficial de Homebrew (`homebrew/cask`): exige apps firmadas y
notarizadas por Apple, lo que requiere el Apple Developer Program (99 $/año).
Este proyecto NO lo usa. En un tap personal esta exigencia no aplica, por lo que
el cask funciona sin Developer Program (aunque macOS mostrará una alerta de
Gatekeeper en el primer arranque: Clic derecho → Abrir).

### Automatización recomendada

Un workflow de GitHub Actions en este repo (disparado por un release) que:
1. Builda el DMG y lo sube como release asset.
2. Actualiza `Casks/brewsnap.rb` en `raulmoracode/homebrew-tap`.

---

## Build y distribución

```bash
# Desarrollo
open BrewSnap.xcodeproj
# Cmd+R para ejecutar

# Distribución (sin Apple Developer Program, distribución por código fuente)
# Opción 1: DMG desde Xcode → subir como release asset a raulmoracode/brewsnap
# Opción 2: brew install raulmoracode/tap/brewsnap (requiere el tap documentado arriba)
```

---

## Licencia

MIT — libre para usar, modificar y distribuir.
