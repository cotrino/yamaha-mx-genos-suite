# Yamaha MX Genos-Style Arranger Suite

**Yamaha MX Genos-Style Arranger Suite** es un ecosistema modular para REAPER que transforma cualquier sintetizador de la serie **Yamaha MX (MX88 / MX61 / MX49)** en una estación de trabajo de arreglista en tiempo real estilo **Yamaha Genos 2 / Tyros**, integrado con un **Novation Launchpad Mini** y un **Korg NanoKey2**.

---

## 🚀 Características Principales

- **Inspector REAImGui (Dockable):** Panel de control dinámico que sigue automáticamente a la pista seleccionada en REAPER.
- **Audición Online con Acorde $Am$ Extendido:** Cada cambio de voz, arpegio o potenciómetro CC dispara automáticamente el acorde $Am^{11}$ ($A2, E3, A3, C4, E4, G4, B4$) para escuchar el sonido en tiempo real en el sintetizador.
- **Gestión Inteligente de la Línea de Tiempo:** Lee la configuración MIDI bajo el cursor de reproducción. El botón **`INSERTAR / REEMPLAZAR`** guarda o actualiza los mensajes de Banco, Programa, Arpegiador (CC89) y Efectos sin incluir eventos de notas.
- **Launchpad Mini (Controlador de Estilos estilo Genos 2):**
  - **Fila 1:** Memorias de Registro (*Scenes 1 - 8*).
  - **Fila 2:** Secciones de Estilo (`Intro A/B`, `Ending A/B`).
  - **Fila 3:** Variaciones Principales (`Main A`, `Main B`, `Main C`, `Main D`).
  - **Fila 4:** Transiciones (`Fill-In`, `Break`).
- **Korg NanoKey2 (Controlador de Pistas y Mezclador):**
  - **Teclas C1 a D#2:** Selección directa de los Canales MIDI 1 a 16.
  - **Teclas E2 / F2:** Mute y Solo de la pista activa.
  - **Teclas F#2 / G2:** Ajuste rápido de volumen ($-1\text{ dB} / +1\text{ dB}$).
- **Procesamiento a Bajo Nivel (Plugins JSFX):**
  - `Yamaha_MX_Control.jsfx`: Control de parámetros MIDI y SysEx por canal.
  - `Yamaha_MX_Chord_Detector.jsfx`: Analizador de acordes en tiempo real para la mano izquierda.
- **Herramientas de Estudio:** Botones dedicados para **"Freeze Track"** (renderizado de audio en tiempo real del hardware) y despliegue automático de carriles de automatización CC.

---

## 📦 Instalación vía ReaPack

1. Abre REAPER y navega a `Extensions > ReaPack > Import repositories...`.
2. Introduce la URL del archivo `index.xml` de tu repositorio:
   ```text
   [https://raw.githubusercontent.com/cotrino/yamaha-mx-genos-suite/main/index.xml](https://raw.githubusercontent.com/cotrino/yamaha-mx-genos-suite/main/index.xml)

```

3. Haz clic en **OK**, busca `Yamaha MX Genos Suite` en ReaPack e instálalo.

---

## 🎹 Configuración del Hardware

1. **Yamaha MX88 / MX61 / MX49:**
* En el teclado: `Utility > Job > Quick Setup > DAW Record`.
* Conecta el sintetizador al ordenador por cable USB.


2. **Novation Launchpad Mini & Korg NanoKey2:**
* Conéctalos a los puertos USB de tu ordenador.
* En REAPER (`Preferences > Audio > MIDI Devices`), habilita ambos controladores para recibir mensajes de control (`Enable input for control messages`).



---

## 📄 Licencia

Desarrollado por **José Cotrino** bajo licencia MIT.
