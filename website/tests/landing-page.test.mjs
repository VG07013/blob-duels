import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

const testDirectory = dirname(fileURLToPath(import.meta.url));
const websiteDirectory = resolve(testDirectory, "..");
const htmlPath = resolve(websiteDirectory, "index.html");
const cssPath = resolve(websiteDirectory, "styles.css");
const scriptPath = resolve(websiteDirectory, "app.js");

const loadPage = () => readFileSync(htmlPath, "utf8");
const loadStyles = () => readFileSync(cssPath, "utf8");

test("page exposes complete metadata and one clear product heading", () => {
  const html = loadPage();

  assert.match(html, /<title>[^<]*Blob Duels[^<]*<\/title>/i);
  assert.match(html, /<meta\s+name="description"\s+content="[^"]+"/i);
  assert.match(html, /<meta\s+name="viewport"/i);
  assert.equal((html.match(/<h1\b/gi) ?? []).length, 1);
  assert.match(html, /<h1\b[^>]*>[\s\S]*Blob Duels[\s\S]*<\/h1>/i);
  assert.match(html, /<header\b/i);
  assert.match(html, /<main\b/i);
  assert.match(html, /<footer\b/i);
});

test("GitHub and download calls to action point to the public vg07013 release", () => {
  const html = loadPage();
  const githubLink = html.match(/<a\b[^>]*href="(https:\/\/github\.com\/[^"]+)"[^>]*>[\s\S]*?GitHub[\s\S]*?<\/a>/i);

  const downloadUrl = "https://github.com/vg07013/blob-duels/releases/latest/download/Blob-Duels-macOS.zip";

  assert.ok(githubLink, "expected a visible GitHub link");
  assert.equal(githubLink[1], "https://github.com/vg07013/blob-duels");
  assert.match(githubLink[0], /target="_blank"/i);
  assert.match(githubLink[0], /rel="[^"]*noopener[^"]*"/i);
  assert.ok(html.includes(`href="${downloadUrl}"`), "expected a stable release download link");
  assert.match(html, />\s*Download for macOS\s*</i);
  assert.doesNotMatch(html, /href=""|href="#"|onclick=/i);
  assert.doesNotMatch(html, /download coming soon|future GitHub/i);
});

test("gallery uses real, descriptive, dimensioned game screenshots", () => {
  const html = loadPage();
  const imageTags = html.match(/<img\b[^>]*>/gi) ?? [];

  assert.ok(imageTags.length >= 4, "expected at least four game images");
  for (const tag of imageTags) {
    const source = tag.match(/src="([^"]+)"/i)?.[1];
    const alt = tag.match(/alt="([^"]+)"/i)?.[1];

    assert.ok(source, `missing src: ${tag}`);
    assert.ok(alt?.trim(), `missing descriptive alt: ${tag}`);
    assert.match(tag, /width="\d+"/i);
    assert.match(tag, /height="\d+"/i);
    assert.ok(existsSync(resolve(websiteDirectory, source)), `missing image file: ${source}`);
  }

  const galleryImages = imageTags.filter((tag) => /class="[^"]*gallery/i.test(tag));
  assert.ok(galleryImages.length >= 3);
  galleryImages.forEach((tag) => assert.match(tag, /loading="lazy"/i));
});

test("internal navigation targets existing sections", () => {
  const html = loadPage();
  const fragments = [...html.matchAll(/href="#([^"]+)"/gi)].map((match) => match[1]);

  assert.ok(fragments.length >= 2);
  fragments.forEach((fragment) => {
    assert.match(html, new RegExp(`id="${fragment}"`, "i"));
  });
});

test("styles preserve the game palette and accessibility essentials", () => {
  const css = loadStyles();

  ["--ink", "--cyan", "--red", "--text", "--muted"].forEach((token) => {
    assert.match(css, new RegExp(`${token}\\s*:`));
    assert.ok((css.match(new RegExp(`var\\(${token}\\)`, "g")) ?? []).length > 0);
  });
  assert.match(css, /:focus-visible/);
  assert.match(css, /@media\s*\([^)]*max-width/i);
  assert.match(css, /@media\s*\(prefers-reduced-motion:\s*reduce\)/i);
});

test("interactive blob arena is present and progressively enhanced", () => {
  const html = loadPage();

  assert.match(html, /<canvas\b[^>]*id="blob-playground"[^>]*role="button"[^>]*tabindex="0"/i);
  assert.match(html, /<script\b[^>]*type="module"[^>]*src="app\.js"/i);
  assert.ok(existsSync(scriptPath));
});

test("blob fling physics point toward the target at a bounded speed", async () => {
  const { flingVelocity, findNearestBlob } = await import("../app.js");
  const blobs = [
    { x: 10, y: 10 },
    { x: 70, y: 80 },
  ];

  assert.equal(findNearestBlob(blobs, 64, 75), blobs[1]);
  assert.deepEqual(flingVelocity({ x: 0, y: 0 }, { x: 3, y: 4 }, 15), { x: 9, y: 12 });
  assert.deepEqual(flingVelocity({ x: 2, y: 2 }, { x: 2, y: 2 }, 15), { x: 15, y: 0 });
});
