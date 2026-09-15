# Buenas prácticas de Swift para código limpio (listo para IA)

Checklist para escribir Swift claro y ordenado antes de pasárselo a una IA.

## 1. Estructura y organización

- [ ] Un tipo por archivo (o pocos, si están muy relacionados)
- [ ] Nombre de archivo igual que el tipo principal (`UserProfileView.swift`, no `Screen2.swift`)
- [ ] Separación por capas: Models, Views, ViewModels, Services, Utils
- [ ] Uso de `// MARK: -` para agrupar secciones en archivos largos

## 2. Nombres claros

- [ ] Nombres descriptivos y completos (`fetchUserProfile()`, no `fetch()` o `f1()`)
- [ ] Convenciones estándar: `camelCase` para variables/funciones, `PascalCase` para tipos
- [ ] Sin abreviaturas ambiguas (excepto estándar como `id`, `url`)
- [ ] Booleanos que se leen como pregunta: `isLoading`, `hasError`, `canSubmit`

## 3. Funciones y tipos pequeños

- [ ] Funciones cortas, una sola responsabilidad
- [ ] Si una función necesita comentarios para "secciones" internas, dividirla
- [ ] Evitar funciones con muchos parámetros (usar structs de configuración)
- [ ] Preferir `struct` sobre `class` cuando no se necesite herencia ni identidad de referencia

## 4. Tipado y seguridad

- [ ] Evitar `Any`, `AnyObject` y forzar unwraps (`!`)
- [ ] Usar `guard let` / `if let` en vez de `!`
- [ ] Enums con valores asociados en vez de strings mágicos o flags booleanos combinados
- [ ] Evitar `as!`; usar `as?` con manejo de fallo

## 5. Manejo de errores

- [ ] Usar `throws` / `Result` en vez de silenciar errores o devolver `nil` sin contexto
- [ ] Definir tipos de error propios (`enum NetworkError: Error`) en vez de `NSError` genérico

## 6. Comentarios y documentación

- [ ] Comentar el **por qué**, no el qué
- [ ] Usar `///` para documentar funciones públicas o complejas
- [ ] Comentario breve al inicio del archivo explicando su propósito general

## 7. Consistencia

- [ ] Un solo estilo de formato (indentación, llaves, espacios)
- [ ] Usar **SwiftLint** o **swift-format** para automatizar el estilo
- [ ] Orden consistente: propiedades → inicializadores → métodos públicos → métodos privados

## 8. Dependencias explícitas

- [ ] Evitar singletons y estado global escondido (`UserDefaults.standard` disperso)
- [ ] Inyectar dependencias en el `init`

## 9. Antes de pasarlo a una IA

- [ ] Eliminar código muerto (funciones sin usar, comentarios viejos, `// TODO` obsoletos)
- [ ] Quitar datos sensibles: API keys, tokens, URLs internas, nombres de clientes reales
- [ ] Pasar solo el fragmento relevante + contexto de tipos usados (protocolos, structs relacionados) si el proyecto es grande
- [ ] Indicar versión de Swift y target (iOS/macOS, SwiftUI/UIKit)
