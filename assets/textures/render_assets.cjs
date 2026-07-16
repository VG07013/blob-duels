const path = require("node:path");
const sharp = require("sharp");

const root = path.resolve(__dirname, "../..");
const assets = [
  ["assets/textures/asphalt.svg", "assets/textures/asphalt.png", 256, 256],
  ["assets/textures/concrete.svg", "assets/textures/concrete.png", 256, 256],
  ["assets/textures/windows_grid.svg", "assets/textures/windows_grid.png", 256, 256],
  ["assets/textures/billboard_blob_league.svg", "assets/textures/billboard_blob_league.png", 1024, 512],
  ["assets/textures/billboard_fling_city.svg", "assets/textures/billboard_fling_city.png", 1024, 512],
  ["assets/ui/crosshair.svg", "assets/ui/crosshair.png", 128, 128],
  ["assets/ui/host.svg", "assets/ui/host.png", 64, 64],
  ["assets/ui/join.svg", "assets/ui/join.png", 64, 64],
  ["assets/ui/settings.svg", "assets/ui/settings.png", 64, 64],
  ["assets/ui/resume.svg", "assets/ui/resume.png", 64, 64],
];

async function render() {
  for (const [source, output, width, height] of assets) {
    await sharp(path.join(root, source), { density: 192 })
      .resize(width, height, { fit: "fill" })
      .png()
      .toFile(path.join(root, `${output}.next`));
    const fs = require("node:fs");
    fs.renameSync(path.join(root, `${output}.next`), path.join(root, output));
    process.stdout.write(`rendered ${output}\n`);
  }
}

render().catch((error) => {
  process.stderr.write(`${error.stack || error}\n`);
  process.exitCode = 1;
});
