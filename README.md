<div align="center">
  <img src="website/assets/blob-duels-game-icon.svg" width="112" alt="Blob Duels icon">

  # Blob Duels

  **Bounce. Fling. Ricochet. Outplay your rival.**

  [![Download for macOS](https://img.shields.io/badge/Download-macOS-2ee7ff?style=for-the-badge&logo=apple&logoColor=091326)](https://github.com/vg07013/blob-duels/releases/latest/download/Blob-Duels-macOS.zip)
  [![Visit the website](https://img.shields.io/badge/Visit-Website-ff4777?style=for-the-badge&logo=githubpages&logoColor=white)](https://vg07013.github.io/blob-duels/)
</div>

Blob Duels is a physics-first 1v1 arena game where movement is a weapon. Charge a fling, bank shots off the scenery, chain abilities, and turn the arena itself against your opponent.

![Blob Duels gameplay](website/assets/screenshots/current-hero.png)

## What is in the arena?

- Fast local-feeling online duels and an offline practice mode.
- Five arenas with boost pads, bumpers, laser gates, wind zones, moving platforms, and dangerous drops.
- A movement-and-aim combat system built around momentum, ricochets, and creative angles.
- Abilities including Blink, Dash, Rail Shot, Gravity Pulse, and Bounce Mine.
- Unlockable blob colors, faces, trails, and effects.

## Download and play

[**Download the latest macOS build →**](https://github.com/vg07013/blob-duels/releases/latest/download/Blob-Duels-macOS.zip)

The current public alpha is a Universal macOS build for Apple Silicon and Intel Macs. This early build is ad-hoc signed but not Developer ID signed or notarized: after unzipping it, right-click `Blob Duels.app`, choose **Open**, and confirm the first launch. You can verify the archive against the `SHA256SUMS.txt` file attached to the latest release before opening it. In the game, choose **Practice Offline**, **Host Game**, or **Join Game**.

Current macOS ZIP SHA-256: `865eadadf5455bd67d83ae1bcd6083b8bea47546ed1626a56d21f9651309542f`

### Controls

| Action | Control |
| --- | --- |
| Move | `W` `A` `S` `D` |
| Brake | Hold `Left Shift` |
| Aim / shoot | Mouse / left click |
| Charge fling | Right click |
| Bounce | Space |
| Use ability | `E` |
| Toggle camera | Tab |

Direct online matches are an unauthenticated, trusted-friends-only alpha feature and use UDP port `7359`. Do not share your public IP broadly. A host playing outside their local network may need to allow the game through their firewall or forward that port, which exposes the game service to the internet until the rule is removed.

## Development

Blob Duels is built with Godot 4.7. Open `project.godot` in Godot and run the main scene to work on the game locally. The landing page lives in `website/` and is deployed to GitHub Pages on every push to `main`.

```bash
node --test website/tests/landing-page.test.mjs
```

The game is still in active development, so balance, maps, networking, and presentation may change between alpha builds.

## Credits

Environment assets include CC0 packs by [Kenney](https://kenney.nl/). Individual asset licenses are included beside their source files.
