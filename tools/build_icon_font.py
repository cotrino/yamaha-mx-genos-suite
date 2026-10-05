#!/usr/bin/env python3
"""Build the Yamaha MX icon font, its Lua mapping, and the credits file.

Requires fontTools (pip install fonttools). Icons come from Material Design Icons (Apache 2.0)
and game-icons.net (CC BY 3.0); see data/ICON_CREDITS.txt for the generated attribution.
"""

from __future__ import annotations

import argparse
import tempfile
import urllib.request
from pathlib import Path
from xml.etree import ElementTree as ET

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.svgLib.path import parse_path
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent.parent
PKG = ROOT / "Scripts" / "Yamaha_MX_Genos_Suite"
MDI_VERSION = "v7.4.47"
MDI_BASE = f"https://raw.githubusercontent.com/Templarian/MaterialDesign-Webfont/{MDI_VERSION}/"
GI_BASE = "https://raw.githubusercontent.com/game-icons/icons/master/"
APACHE_URL = "https://www.apache.org/licenses/LICENSE-2.0.txt"
UPM = 512
ASCENT, DESCENT = 448, -64
FIRST_CODEPOINT = 0xE000

# short name -> (icon source, hover name). "mdi:" = Material Design Icons, "gi:" = game-icons.net.
VOICE = {
    "APno": ("gi:caro-asercion/grand-piano", "Acoustic Pianos"),
    "Vintg": ("mdi:piano", "Vintage Electric Pianos"),
    "Modrn": ("mdi:piano", "Modern Pianos"),
    "Layer": ("mdi:layers-triple", "Layered Pianos"),
    "Combo": ("gi:delapouite/musical-keyboard", "Combo Keys"),
    "EP": ("gi:delapouite/musical-keyboard", "Electric Pianos"),
    "FM": ("mdi:cosine-wave", "FM Electric Pianos"),
    "Clavi": ("gi:delapouite/piano-keys", "Clavinets and Harpsichords"),
    "TnWhl": ("mdi:tune-vertical", "Tonewheel Organs"),
    "Pipe": ("gi:caro-asercion/pipe-organ", "Pipe Organs and Accordions"),
    "ABass": ("gi:delapouite/guitar-bass-head", "Acoustic Basses"),
    "EBass": ("gi:delapouite/guitar-bass-head", "Electric Basses"),
    "SynBs": ("mdi:square-wave", "Synth Basses"),
    "A.Gtr": ("mdi:guitar-acoustic", "Acoustic Guitars"),
    "E.Cln": ("mdi:guitar-electric", "Clean Electric Guitars"),
    "E.Dst": ("mdi:lightning-bolt", "Distortion Guitars"),
    "Pluk": ("gi:delapouite/banjo", "Plucked Strings"),
    "Bowed": ("gi:zajkonur/violin", "Bowed Strings"),
    "Ensem": ("mdi:violin", "String Ensembles"),
    "Pizz": ("gi:delapouite/harp", "Pizzicato Strings and Harp"),
    "Solo": ("mdi:account-music", "Solo Instruments"),
    "Orche": ("gi:caro-asercion/french-horn", "Orchestral Brass"),
    "BrsEn": ("mdi:trumpet", "Brass Ensembles"),
    "Sax": ("mdi:saxophone", "Saxophones"),
    "RPipe": ("gi:caro-asercion/clarinet", "Reed Pipes"),
    "WWind": ("gi:delapouite/ocarina", "Woodwinds"),
    "Flute": ("gi:delapouite/flute", "Flutes"),
    "Blown": ("gi:delapouite/bagpipes", "Ethnic Blown Instruments"),
    "Bell": ("mdi:bell", "Bells and Music Boxes"),
    "SynBl": ("mdi:bell-ring", "Synth Bells"),
    "Malet": ("gi:delapouite/xylophone", "Mallet Instruments"),
    "PDrum": ("gi:delapouite/drum", "Pitched Percussion"),
    "Struk": ("gi:delapouite/gong", "Struck Percussion"),
    "Perc": ("gi:delapouite/tambourine", "Percussion Kits"),
    "Drums": ("gi:caro-asercion/drum-kit", "Drum Kits"),
    "Choir": ("mdi:account-voice", "Choirs and Vocals"),
    "Synth": ("mdi:triangle-wave", "Synth Ensembles"),
    "Analg": ("mdi:sawtooth-wave", "Analog Synths"),
    "Digtl": ("mdi:waveform", "Digital Synths"),
    "Dance": ("mdi:boombox", "Dance Synths"),
    "H Hop": ("mdi:microphone-variant", "Hip Hop"),
    "Fade": ("mdi:gradient-horizontal", "Fading Pads"),
    "Hook": ("mdi:hook", "Synth Hooks"),
    "Hit": ("mdi:flash", "Hits and Stabs"),
    "Arp": ("mdi:stairs-up", "Arpeggio Synths"),
    "Move": ("mdi:waves", "Moving Pads"),
    "Sweep": ("mdi:radar", "Sweep Pads"),
    "Brite": ("mdi:star-four-points", "Bright Pads"),
    "Warm": ("mdi:weather-sunny", "Warm Pads"),
    "Ambie": ("mdi:weather-fog", "Ambient Pads"),
    "Natur": ("mdi:leaf", "Nature Sounds"),
    "SciFi": ("mdi:alien", "Sci-Fi Effects"),
}

ARP = {
    "ApKb": ("mdi:piano", "Acoustic Piano and Keyboard"),
    "Org": ("gi:caro-asercion/pipe-organ", "Organ"),
    "Guit": ("mdi:guitar-acoustic", "Guitar"),
    "Bass": ("gi:delapouite/guitar-bass-head", "Bass"),
    "Str": ("mdi:violin", "Strings"),
    "Brs": ("mdi:trumpet", "Brass"),
    "RdPp": ("mdi:saxophone", "Reed and Pipe"),
    "Lead": ("mdi:sawtooth-wave", "Synth Lead"),
    "PdMe": ("mdi:waves", "Pad and Melodic"),
    "CrPc": ("mdi:bell", "Chromatic Percussion"),
    "DrPc": ("gi:caro-asercion/drum-kit", "Drum and Percussion"),
    "Seq": ("mdi:stairs-up", "Sequence"),
    "Chd": ("mdi:music-clef-treble", "Chord"),
    "Hybr": ("mdi:creation", "Hybrid"),
    "Ctrl": ("mdi:tune", "Controller Effects"),
}

GI_AUTHORS = {"caro-asercion": "Caro Asercion", "delapouite": "Delapouite", "zajkonur": "Zajkonur"}


def fetch(url: str, cache: Path) -> bytes:
    target = cache / url.replace("://", "_").replace("/", "_")
    if not target.exists():
        request = urllib.request.Request(url, headers={"User-Agent": "yamaha-mx-genos-suite"})
        target.write_bytes(urllib.request.urlopen(request).read())
    return target.read_bytes()


def mdi_codepoints(cache: Path) -> dict[str, int]:
    import re

    css = fetch(MDI_BASE + "css/materialdesignicons.css", cache).decode("utf-8")
    pairs = re.findall(r'\.mdi-([a-z0-9-]+)::before\s*\{\s*content:\s*"\\([0-9A-Fa-f]+)"', css)
    return {name: int(code, 16) for name, code in pairs}


def mdi_glyph(font: TTFont, cmap: dict, codepoints: dict[str, int], name: str):
    scale = UPM / font["head"].unitsPerEm
    pen = TTGlyphPen(None)
    font.getGlyphSet()[cmap[codepoints[name]]].draw(TransformPen(pen, (scale, 0, 0, scale, 0, 0)))
    return pen.glyph()


def game_icon_glyph(svg: bytes):
    root = ET.fromstring(svg)
    pen = TTGlyphPen(None)
    flip = TransformPen(pen, (1, 0, 0, -1, 0, UPM + DESCENT))
    drawn = False
    for element in root.iter():
        if element.tag.rsplit("}", 1)[-1] != "path":
            continue
        path = element.get("d", "").strip()
        if not path or path.replace(" ", "") == "M0 0h512v512H0z".replace(" ", ""):
            continue
        parse_path(path, Cu2QuPen(flip, max_err=1.0))
        drawn = True
    if not drawn:
        raise ValueError("SVG has no drawable path")
    return pen.glyph()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", default=str(Path(tempfile.gettempdir()) / "yamaha_icon_cache"))
    args = parser.parse_args()
    cache = Path(args.cache)
    cache.mkdir(parents=True, exist_ok=True)

    sources = list(dict.fromkeys(src for src, _ in [*VOICE.values(), *ARP.values()]))
    codepoint_of = {src: FIRST_CODEPOINT + index for index, src in enumerate(sources)}

    codepoints = mdi_codepoints(cache)
    mdi_font = TTFont(__import__("io").BytesIO(fetch(MDI_BASE + "fonts/materialdesignicons-webfont.ttf", cache)))
    mdi_cmap = mdi_font.getBestCmap()
    hhea = mdi_font["hhea"]
    print(f"MDI upm={mdi_font['head'].unitsPerEm} ascent={hhea.ascent} descent={hhea.descent}")

    glyphs = {".notdef": TTGlyphPen(None).glyph()}
    cmap_out = {}
    for src, codepoint in codepoint_of.items():
        kind, name = src.split(":", 1)
        glyph_name = "icon_%04X" % codepoint
        if kind == "mdi":
            glyphs[glyph_name] = mdi_glyph(mdi_font, mdi_cmap, codepoints, name)
        else:
            glyphs[glyph_name] = game_icon_glyph(fetch(f"{GI_BASE}{name}.svg", cache))
        cmap_out[codepoint] = glyph_name

    builder = FontBuilder(UPM, isTTF=True)
    builder.setupGlyphOrder(list(glyphs))
    builder.setupCharacterMap(cmap_out)
    builder.setupGlyf(glyphs)
    metrics = {}
    for name, glyph in glyphs.items():
        glyph.recalcBounds(None)
        metrics[name] = (UPM, getattr(glyph, "xMin", 0) if glyph.numberOfContours else 0)
    builder.setupHorizontalMetrics(metrics)
    builder.setupHorizontalHeader(ascent=ASCENT, descent=DESCENT)
    builder.setupNameTable({"familyName": "Yamaha MX Icons", "styleName": "Regular"})
    builder.setupOS2(sTypoAscender=ASCENT, sTypoDescender=DESCENT, usWinAscent=ASCENT, usWinDescent=-DESCENT)
    builder.setupPost()
    font_path = PKG / "data" / "YamahaMXIcons.ttf"
    builder.save(str(font_path))
    print(f"wrote {font_path} ({font_path.stat().st_size} bytes, {len(cmap_out)} glyphs)")

    def lua_table(entries: dict) -> str:
        rows = []
        for short, (src, long_name) in entries.items():
            glyph = "\\u{%04X}" % codepoint_of[src]
            rows.append(f'  ["{short}"] = {{ glyph = "{glyph}", name = "{long_name}" }},')
        return "\n".join(rows)

    lua = (
        "-- @noindex\n"
        "-- Generated by tools/build_icon_font.py; do not edit.\n"
        "local Icons = {}\n\n"
        'Icons.font_file = "data/YamahaMXIcons.ttf"\n\n'
        f"Icons.voice = {{\n{lua_table(VOICE)}\n}}\n\n"
        f"Icons.arp = {{\n{lua_table(ARP)}\n}}\n\n"
        "return Icons\n"
    )
    (PKG / "lib" / "icons.lua").write_text(lua, encoding="utf-8", newline="\n")

    used_gi = sorted(src[3:] for src in sources if src.startswith("gi:"))
    credits = [
        "Icon credits for data/YamahaMXIcons.ttf",
        "",
        "The icons were converted into font glyphs (resized and recolored by the font format) by tools/build_icon_font.py.",
        "",
        f"Material Design Icons {MDI_VERSION} by Pictogrammers, https://pictogrammers.com/library/mdi/",
        "  License: Apache License 2.0 (see LICENSE-Apache-2.0.txt).",
        "",
        "game-icons.net, https://game-icons.net, licensed under Creative Commons Attribution 3.0",
        "(https://creativecommons.org/licenses/by/3.0/). Icons made by the following authors:",
    ]
    for entry in used_gi:
        author, icon = entry.split("/", 1)
        credits.append(f"  {icon} by {GI_AUTHORS[author]}")
    (PKG / "data" / "ICON_CREDITS.txt").write_text("\n".join(credits) + "\n", encoding="utf-8", newline="\n")
    (PKG / "data" / "LICENSE-Apache-2.0.txt").write_bytes(fetch(APACHE_URL, cache))
    print("wrote lib/icons.lua, data/ICON_CREDITS.txt, data/LICENSE-Apache-2.0.txt")


if __name__ == "__main__":
    main()
