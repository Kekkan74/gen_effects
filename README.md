# ⚡ GenEffects (`OmniVFX Studio`)

Generador visual open-source de **Efectos Visuales (VFX), Shaders Procedurales, Partículas 2D/3D, Spritesheets Pixel-Art y Efectos de Sonido (SFX)**, diseñado bajo **Arquitectura Hexagonal y Microkernel** para exportar de forma nativa a **Godot Engine 4** y **Unreal Engine 5**.

---

## 🚀 Inicio Rápido en 1 Clic (¡Para todo el equipo!)

GenEffects está pensado para que cualquier compañero pueda clonar el repositorio y usarlo **al instante sin instalar nada**:

### En Windows:
1. Clona el repositorio:
   ```bash
   git clone https://github.com/Kekkan74/gen_effects.git
   cd gen_effects
   ```
2. Haz doble clic en **`GenEffects.exe`** (o en `Iniciar_GenEffects.bat` / `run.bat`).
   - El ejecutable abre la aplicación directamente. Si es la primera vez tras clonar y no detecta el runtime portable en `bin\`, te preguntará si deseas descargarlo y lo configurará automáticamente en ~5 segundos para empezar a trabajar al instante.

### En Linux / macOS:
```bash
git clone https://github.com/Kekkan74/gen_effects.git
cd gen_effects
chmod +x launch.sh
./launch.sh
```

---

## ✨ Biblioteca de Plantillas y Guía de Nodos en 3 Pasos

Para que cualquier persona pueda empezar sin tener que aprender gráficos por nodos desde cero:

### 1. Galería de Plantillas Listas (1 Clic)
Pulsa el botón **`✨ Plantillas`** en la barra superior o en el catálogo para cargar cualquiera de los 6 efectos preconfigurados:
- 🔥 **Explosión Solar Arcana:** Fuego esférico, turbulencia de Voronoi y sonido de detonación.
- ⚡ **Rayo Láser de Plasma:** Haz sci-fi de alta velocidad, partículas direccionales y disparo láser.
- 💚 **Aura Sagrada de Curación:** Espiral ascendente verde/oro y sonido de powerup.
- 🌀 **Vórtice Oscuro del Vacío:** Singularidad que absorbe partículas con sonido arcano.
- ⚔️ **Chispas de Impacto Metálico:** Ráfaga cónica ultrarrápida y golpe de metal.
- 💨 **Columna de Humo y Cenizas:** Nubes lentas con dithering pixel-art retro.

### 2. La Fórmula de 3 Pasos para Crear Nodos
Pulsa **`❓ Guía Nodos`** para ver el diagrama visual interactivo:
1. **Paso 1 (Forma & Color):** Conecta nodos Cyan (`SDFShape`, `Voronoi`, `Perlin`, `ColorRamp`) para definir el aspecto visual.
2. **Paso 2 (Física & Movimiento):** Conecta la textura al `ParticleEmitter` (Púrpura) y añade fuerzas como `ParticleForceField`.
3. **Paso 3 (Sonido & Salida):** Conecta el emisor y el nodo `SFXSynth` (Rosa) al `EffectOutput` (Dorado) para exportar a Godot o Unreal.

### 3. Importar y Guardar Archivos `.omnivfx`
- **`📂 Importar...`**: Abre cualquier archivo `.omnivfx` del disco y carga su grafo completo.
- **`💾 Guardar...`**: Guarda tu diseño actual en formato `.omnivfx` para compartirlo con tu equipo o subirlo a Git.

---

## 🎯 Flujo de Exportación Multi-Motor Sencillo

GenEffects cuenta con un **Exportador Visual Integrado** (`ExportDialog`) para exportar a tus motores favoritos en 2 clics:

### 📦 1. Exportar a Godot Engine 4
1. En la barra superior, haz clic en **"📦 Exportar Godot 4..."**.
2. Selecciona la carpeta de destino (puedes apuntar directamente a la carpeta `res://` de tu proyecto de Godot o usar la ruta por defecto `./exports/`).
3. Pulsa **"⚡ EXPORTAR EFECTO AHORA"** y luego **"📂 Abrir Carpeta en Explorador"**.
4. **¿Cómo usarlo en Godot?**
   - Arrastra la carpeta generada dentro del panel *FileSystem* de tu proyecto de Godot.
   - Encontrarás:
     - `NombreEfecto.tscn`: Escena lista con partículas (`GPUParticles3D` o `GPUParticles2D`) y nodo de audio configurado.
     - `NombreEfecto.gdshader`: Shader visual compilado en **GLSL nativo de Godot 4**.
     - `NombreEfecto_sfx.wav`: Efecto de sonido sintetizado en PCM 16-bit RIFF.
     - `LEEME_INSTRUCCIONES_GODOT.txt`: Guía con código GDScript listo para instanciar en tu juego (`preload(...).instantiate()`).

### 🚀 2. Exportar a Unreal Engine 5
1. En la barra superior, haz clic en **"🚀 Exportar Unreal 5..."**.
2. Pulsa **"⚡ EXPORTAR EFECTO AHORA"** y luego **"📂 Abrir Carpeta en Explorador"**.
3. **¿Cómo usarlo en Unreal Engine 5?**
   - Copia la carpeta generada en la carpeta `Content/` de tu proyecto Unreal.
   - Encontrarás:
     - `NombreEfecto.niagara.json`: Especificación de parámetros del emisor Niagara (velocidades, curvas, spawn rate).
     - `NombreEfecto.hlsl`: Expresión HLSL matemática pura lista para pegar en un nodo `Custom` del Material Graph o Niagara.
     - `import_NombreEfecto_ue5.py`: Script de Python para automatizar la importación en la consola de comandos de UE5 (`py "import_NombreEfecto_ue5.py"`).
     - `NombreEfecto_sfx.wav`: Archivo de audio listo para arrastrar al *Content Browser* (UE5 crea el `SoundWave` automáticamente).
     - `LEEME_INSTRUCCIONES_UNREAL5.txt`: Instrucciones completas paso a paso.

### 🖼️ 3. Exportar Spritesheet 2D (Atlas Pixel-Art)
1. En la barra superior, haz clic en **"🖼️ Exportar Spritesheet 2D..."**.
2. Genera:
   - `NombreEfecto_sheet.png`: Textura empaquetada con todos los fotogramas del efecto visual.
   - `NombreEfecto.frames.json`: Metadatos con rectángulos UV, coordenadas `(x, y, w, h)` y temporización en milisegundos.
   - `NombreEfecto_sfx.wav`: Audio sincronizado.
   - `LEEME_INSTRUCCIONES_SPRITESHEET.txt`: Guía para importar en `AnimatedSprite2D` (Godot) o `Paper2D Flipbook` (Unreal Engine).

---

## 🌟 Los 4 Pilares de Inspiración

1. **Effekseer (Partículas 2D/3D & Integración Multi-Motor):** Emisores jerárquicos, atractores vectoriales, vórtices, curvas de vida y filosofía de exportación limpia hacia motores externos.
2. **Material Maker (Grafo de Nodos Procedurales):** Generación no destructiva basada en `GraphEdit` de ruidos (Voronoi, Perlin, FBM), figuras SDF y rampas de color compiladas a un árbol intermedio (`ShaderIR`) que compila a **GLSL y HLSL simultáneamente**.
3. **Pixelorama (Pixel-Art & Spritesheet Baker):** Pase de renderizado y cuantización con paletas retro (PICO-8, GameBoy, Arcane Fire), dithering ordenado Bayer 4x4, contornos procedurales y empaquetado automático de atlas de animación.
4. **rfxgen (Síntesis Procedural de SFX):** Generador de audio 100% sintetizado por software con osciladores (Square, Saw, Sine, Triangle, Noise), envolventes ADSR, moduladores de frecuencia, vibrato, filtros paso bajo/alto y codificador WAV PCM 16-bit nativo.

---

## 🏛️ Arquitectura Hexagonal y Microkernel

```
                    ┌─────────────────────────────────────────┐
                    │          UI LAYER (ADAPTERS)            │
                    │  OmniVFXGraphEdit • LivePreviewViewport │
                    │  ReflectionInspector • UnifiedTimeline  │
                    │  ExportDialog (Modal Multi-Motor)       │
                    └───────────────────▲─────────────────────┘
                                        │
                                        │ Ports & Events
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                       HEXAGONAL CORE MICROKERNEL                            │
│                                                                             │
│   EventBus ◄──► ServiceRegistry ◄──► DAGGraph (Kahn Sort + Cycle Detect)    │
│   CommandManager (Undo/Redo Coalescing) ◄──► OmniVFXDocument / Serializer   │
└──────────────▲────────────────────▲────────────────────▲────────────────────┘
               │                    │                    │
   ┌───────────┴──────────┐   ┌─────┴────────────┐ ┌─────┴──────────┐
   │ PROCEDURAL SHADERS   │   │ PARTICLE PHYSICS │ │ SFX SYNTH      │
   │ SDF, Voronoi, Perlin │   │ 2D/3D Simulator  │ │ Waveform, ADSR │
   │ Transpiler GLSL/HLSL │   │ Forces & Curves  │ │ 16-bit WAV     │
   └──────────────────────┘   └──────────────────┘ └────────────────┘
               ▲
               │
   ┌───────────┴──────────┐
   │ PIXEL-ART BAKER      │
   │ Palettes & Dithering │
   │ Spritesheet Atlas 2D │
   └──────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          EXPORTER PLUGINS                                   │
│  • GodotExporterPlugin       -> Escena .tscn + .gdshader + .wav             │
│  • UnrealExporterPlugin      -> Niagara .json + .hlsl + python .py + .wav   │
│  • SpritesheetExporterPlugin -> Atlas .png + .frames.json + .wav            │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 🧪 Pruebas Automatizadas y Calidad de Código

El repositorio cuenta con una suite completa de **49 pruebas unitarias y de integración** sin interfaz requerida (Godot Headless), cubriendo todos los subsistemas:

```bash
# Ejecutar todas las suites de prueba:
bin/godot.exe --headless --path . -s tests/test_core_kernel.gd
bin/godot.exe --headless --path . -s tests/test_phase2_modules.gd
bin/godot.exe --headless --path . -s tests/test_phase3_modules.gd
bin/godot.exe --headless --path . -s tests/test_phase4_exporters.gd
bin/godot.exe --headless --path . -s tests/test_export_dialog.gd
```

Resultados: **49 tests ejecutados, 0 fallidos**.

---

## 📦 Releases y CI/CD

El repositorio incluye un flujo de integración y despliegue continuo en `.github/workflows/release.yml`. Cada versión etiquetada (`git tag v1.0.0`) genera y sube automáticamente a GitHub Releases los ejecutables independientes:
- `GenEffects_Windows_x64.zip`
- `GenEffects_Linux_x64.zip`

---

## 📄 Licencia

Código abierto bajo licencia MIT. Desarrollado con pasión para la comunidad de desarrolladores de Godot y Unreal Engine.
