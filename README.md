# ⚡ GenEffects (`OmniVFX Studio`)

Generador visual open-source de **Efectos Visuales (VFX), Texturas/Shaders Procedurales, Partículas 2D/3D, Spritesheets Pixel-Art y Efectos de Sonido (SFX)**, diseñado bajo **Arquitectura Hexagonal y Microkernel** para exportar de forma nativa a **Godot Engine** y **Unreal Engine**.

---

## 🌟 Los 4 Pilares de Inspiración

1. **Effekseer (Partículas 2D/3D & Integración Multi-Motor):** Emisores jerárquicos, atractores, curvas de vida y filosofía de exportación limpia hacia motores externos.
2. **Material Maker (Grafo de Nodos Procedurales):** Generación no destructiva basada en `GraphEdit` de ruidos (Voronoi, Perlin, FBM), figuras SDF y rampas de color compiladas a un árbol intermedio (`ShaderIR`).
3. **Pixelorama (Pixel-Art & Spritesheet Baker):** Pase de post-procesado opcional para pixelado en tiempo real, cuantización por paletas, contornos (*outlines*) y empaquetado de Atlas 2D (`.png` + `.json`).
4. **rfxgen (Síntesis Procedural de SFX):** Generador de audio integrado y sincronizado con la línea de tiempo del efecto visual (osciladores, envolventes ADSR, barridos de frecuencia, filtros y mutación aleatoria).

---

## 🏛️ Principios de Arquitectura (SOLID • Bajo Acoplamiento • Alta Cohesión)

- **Microkernel (`src/core/`):** Libre de dependencias hacia la interfaz gráfica o motores externos. Gestiona el grafo dirigido acíclico (`DAGGraph`), el contenedor de Inyección de Dependencias (`ServiceRegistry`), la pila transaccional de acciones (`CommandManager` con soporte de *Undo/Redo* y fusión de cambios continuos) y el bus de eventos tipado (`EventBus`).
- **Módulos de Dominio Aislados (`src/modules/`):** Cada motor (`tex_shader_gen`, `particle_sim`, `pixel_baker`, `sfx_synth`) implementa el puerto `IGeneratorNode` y expone metadatos declarativos (`PropertySchema`) para que el Inspector construya su UI por reflexión sin acoplarse a las clases concretas.
- **Formato Agnóstico `.omnivfx` y Exporters (`src/exporters/`):** El documento se serializa en un esquema JSON/binario intermedio independiente del motor. Los adaptadores `IExporterPlugin` traducen el documento a escenas de **Godot 4** (`.tscn`/`.gdshader`), especificaciones de **Unreal Engine 5** (*Niagara* / *HLSL*) o **Spritesheets 2D**.

---

## 📂 Estructura del Proyecto

```text
gen_effects/
├── project.godot
├── src/
│   ├── core/
│   │   ├── bus/             # EventBus y DomainEvent (Observer / Pub-Sub)
│   │   ├── commands/        # ICommand, CommandManager y comandos del grafo (Undo/Redo)
│   │   ├── dag/             # DAGGraph (detección de ciclos DFS y orden topológico)
│   │   ├── di/              # ServiceRegistry (Inyección de Dependencias y registro de plugins)
│   │   ├── model/           # PinTypes, PropertySchema y OmniVFXDocument
│   │   └── ports/           # IGeneratorNode e IExporterPlugin (Interfaces/Puertos)
│   ├── modules/             # Motores cohesivos (Shaders, Partículas, PixelBaker, SFX)
│   ├── exporters/           # Serializador .omnivfx y exportadores a Godot / Unreal / Atlas
│   └── ui/                  # Vistas desacopladas (GraphEdit, Viewport, Timeline, Inspector)
└── tests/
    └── test_core_kernel.gd  # Suite de pruebas unitarias del Microkernel Core
```
