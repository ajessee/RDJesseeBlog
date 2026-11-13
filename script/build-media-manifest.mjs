import { chmod, mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const inputPath = path.resolve(root, process.env.STATIC_ARCHIVE_EXPORT || 'tmp/static-archive/export-cloudfront.json');
const inventoryPath = path.resolve(root, process.env.STATIC_S3_INVENTORY || 'tmp/static-archive/s3-inventory.json');
const outputPath = path.resolve(root, process.env.STATIC_MEDIA_MANIFEST || 'tmp/static-archive/media-manifest.json');

const archive = JSON.parse(await readFile(inputPath, 'utf8'));
const inventory = JSON.parse(await readFile(inventoryPath, 'utf8'));
const inventoryByKey = new Map(inventory.map((object) => [object.Key, object.Size]));
const references = [
  ...archive.stories.map((item) => item.picture),
  ...archive.pictures.map((item) => item.image),
  ...archive.recordings.map((item) => item.audio),
  ...archive.videos.map((item) => item.video)
].filter(Boolean);

const assetsByKey = new Map();
for (const reference of references) {
  if (!reference.url) throw new Error(`Unmapped media reference: ${reference.filename}`);
  const url = new URL(reference.url);
  const key = decodeURIComponent(url.pathname.replace(/^\//, ''));
  const inventorySize = inventoryByKey.get(key);
  if (inventorySize === undefined) throw new Error(`S3 inventory is missing ${key}`);
  if (inventorySize !== reference.byte_size) throw new Error(`Size mismatch for ${key}: DB=${reference.byte_size}, S3=${inventorySize}`);

  const current = assetsByKey.get(key);
  if (current && (current.size_bytes !== reference.byte_size || current.content_type !== reference.content_type)) {
    throw new Error(`Conflicting archive metadata for ${key}`);
  }
  assetsByKey.set(key, {
    key,
    filename: reference.filename,
    content_type: reference.content_type,
    size_bytes: reference.byte_size
  });
}

const assets = [...assetsByKey.values()].sort((a, b) => a.key.localeCompare(b.key));
const manifest = {
  generated_at: new Date().toISOString(),
  source: 'production archive export matched against S3 object inventory',
  object_count: assets.length,
  total_bytes: assets.reduce((sum, asset) => sum + asset.size_bytes, 0),
  assets
};

await mkdir(path.dirname(outputPath), { recursive: true, mode: 0o700 });
await writeFile(outputPath, `${JSON.stringify(manifest, null, 2)}\n`, { mode: 0o600 });
await chmod(outputPath, 0o600);
console.log(`Wrote ${assets.length} verified media objects (${manifest.total_bytes} bytes) to ${path.relative(root, outputPath)}`);
