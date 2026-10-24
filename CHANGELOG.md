# Changelog

## 2.5.0
- 💿 **New orb style “Record”**: a vinyl record that spins with the music (33 rpm) and stops on pause, a tone arm that swings onto the record and away, and the cover of the current song or video on the label (`mpris:artUrl`) – spinning, tone arm and cover can be switched off one by one
- 🔁 **One orb for all styles**: switching the orb on or off, its look, colour and play/pause now apply to every style at once (only the size stays per style)
- ✨ Light in the middle never gets cut off at the edge of the visualizer
- 🎬 GitHub: new README with demo video, animated record-orb preview and orb overview
- 🌍 All new texts in 10 languages

## 2.4.1
- 🎵 Effects react to the music again: the recording stream is no longer marked passive / no-reconnect (WirePlumber could leave it unlinked), `parec` is tried first again
- 🎵 Stronger music reaction in all Lines & Light styles – width, wobble, line thickness and speed follow volume and bass
- ⏯️ Desktop orb: own click target above the desktop layer – clicking pauses and resumes music and video (MPRIS)
- 🔮 Only the new orb with play/pause symbol – on by default (play/pause on) for double helix, laser fan and light strings
- 〰️ Without the orb the lines run through the middle without a gap (laser fan, light strings, colour streams, double helix)
- ✨ New option “Light in the middle” for all Lines & Light styles – breathes with the music (on by default)
- 🖼️ Style previews show the orb only when it is switched on in the settings
- ℹ️ About picture: colour streams flowing into the logo, which lies on top as the orb

## 2.4.0
- 🔒 Audio helper accepts requests only with a random per-session token (`X-SeaQ-Token`, handed over in the environment) and a matching `Host` header – protects against web pages and DNS rebinding
- 🔒 Never sends anything to a foreign program on its port: an older helper is identified (`/hello` + `/proc` check, same user) and stopped by signal; otherwise the widget moves to the next port
- 🛡️ Audio repair: unmutes only muted streams, raises only volumes at 0 % (to 100 %); WirePlumber's memory is only cleaned after confirmation; “Don't report again” list
- 🖼️ Taskbar logo is a switch in *About* (removes its desktop file and KWin rule when turned off)
- 🍃 Less work in silence: fewer requests and no redraws of still pictures – unchanged while music plays
- 🧯 Starting `pw-record` / `parec` / `cava` can no longer crash the helper
- 🔮 Orb: own colour, play/pause switch and a clearly visible play/pause symbol (always / on hover / never) for every style with an orb
- ℹ️ About page: new picture with the app icon and macOS colour waves, PayPal and Buy-me-a-coffee buttons, author SeaQ

## 2.3.2
- 🖼️ The settings windows show the SeaQ SoundWave logo in the task manager (a KWin window rule assigns them their own desktop file)
- ⏯️ Pop-up card: clearly visible round play/pause button in the accent colour of the KDE theme

## 2.3.1
- 🎨 New app icon (widget list, settings editor)
- 🪟 Settings editor explicitly uses the KDE window decoration

## 2.3.0
- 🛡️ **Audio protection:** SoundWave's recording stream is no longer stored, restored or moved by PipeWire/WirePlumber (`state.restore-props=false`, `state.restore-target=false`, `node.passive=true`, `node.dont-reconnect=true`), so it can't leave other apps muted
- 🛡️ The widget checks every 30 s for apps that are muted or at 0 % (playing or remembered by WirePlumber) and shows a KDE notification with a **Repair** button – or repairs automatically (Audio → Audio protection)
- 🎙️ PipeWire's own recorder (`pw-record`) is now preferred over `parec`
- 🌊 Quick settings: live “Colour waves” banner in macOS colours on a Ventura-dark background, button in the accent colour of your KDE theme

## 2.2.0
- 🌍 Translations: English (default), German, French, Spanish, Italian, Dutch, Hindi, Simplified Chinese, Japanese, Korean
- ↔️ Free positioning: resize on **all four edges and all four corners**
- 🪟 The settings editor is now a normal KDE window (KDE title bar and borders, resizable everywhere)
- 📏 Default gap to the panel: 1 px
- 🧹 All texts and code comments in English

## 2.1.0
- 🃏 Pop-up card on right click on the visualizer (click an empty spot to close it); with the card switched off a right click opens the menu
- 🌊 “Colour waves” is the default style
- 🟪 Background plate: square bottom corners for styles that stand on the edge, rounded all around for floating styles, adjustable radius
- ↩️ Reset buttons on every page and a factory reset

## 2.0.0
- Renamed to **SeaQ SoundWave**
- 14 new styles (lines & light, round, macOS group), orb with play/pause (MPRIS)
- Placement: widget, panel, fixed position, free (global shortcut)
- New settings editor, colour collection and gradient editor
