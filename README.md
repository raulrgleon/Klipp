# Klipp

Gestor de historial de portapapeles para macOS, al estilo Win+V.

## Cómo correrlo

Esta máquina tiene Command Line Tools (Intel). El `Xcode.app` instalado es arm64 y no sirve acá.

```bash
./scripts/build.sh
open build/Klipp.app
```

Atajo por defecto: **⌘⇧V**. El ícono vive en la barra de menú, no en el Dock.

## Permiso que sí hay que conceder

En **Ajustes del Sistema → Privacidad y seguridad → Accesibilidad**, activá Klipp. Sin eso el panel y el historial funcionan, pero no puede simular ⌘V en la app anterior.

## Datos

Todo queda en `~/Library/Application Support/Klipp`. No hay red ni telemetría.
