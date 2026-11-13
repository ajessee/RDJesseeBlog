import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
import { escapeHtml, plainText } from './html-text.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const require = createRequire(import.meta.url);
const { matchesStory } = require('../static-site/archive-filters.js');
const { selectRandom, shuffle } = require('../static-site/archive-random.js');
const quoteStarts = [
  'I notice that people are rushing around',
  'At that time I also had night dreams',
  'As the darkness gradually dissipated',
  'From our balcony we could watch the sun creep up',
  'The late October sun in a sky unadulterated',
  'The world has a ghostly appearance'
];

const fixture = (overrides = {}) => ({
  schema_version: 1,
  unresolved_media_url_count: 0,
  unmapped_media_reference_count: 0,
  stories: [{
    id: 1,
    title: 'Entity & Formatting Check',
    content_html: `<p>A&nbsp;B &amp; C &lt; D &#8217; E</p>${quoteStarts.map((quote) => `<p>${quote}</p>`).join('')}`,
    year_written: 2012,
    decade: 4,
    location: 'Kentucky',
    genre: 'Non-Fiction',
    category: null,
    life_stage: null,
    tags: ['family'],
    picture: { url: 'https://media.example.test/story.jpg' },
    recording_ids: [21],
    video_ids: [],
    comment_ids: [31]
  }],
  pictures: [{
    id: 11,
    caption_html: 'Family &amp; dog',
    photographer_name: 'Family',
    image: { url: 'https://media.example.test/picture.jpg' },
    comment_ids: []
  }],
  recordings: [{
    id: 21,
    caption_html: 'Story reading',
    audio: { url: 'https://media.example.test/story.m4a', filename: 'story.m4a' },
    recordable_type: 'User',
    created_at: '2026-01-01T00:00:00Z'
  }],
  comments: [{
    id: 31,
    commentable_type: 'Story',
    author_name: 'Family member',
    content_html: '<p>A memory &amp; note</p>'
  }],
  tags: [{ id: 41, name: 'family', story_ids: [1] }],
  ...overrides
});

const runBuild = async (data, outputPath) => {
  const tempDir = await mkdtemp(path.join(os.tmpdir(), 'rdjessee-static-test-'));
  const inputPath = path.join(tempDir, 'export.json');
  await writeFile(inputPath, JSON.stringify(data));
  const result = spawnSync(process.execPath, ['script/build-static-site.mjs'], {
    cwd: root,
    encoding: 'utf8',
    env: { ...process.env, STATIC_ARCHIVE_EXPORT: inputPath, STATIC_ARCHIVE_OUTPUT: outputPath }
  });
  return { result, tempDir };
};

test('plainText decodes entities and removes markup before excerpt escaping', () => {
  const text = plainText('<p>A&nbsp;B &amp; C &lt; D &#8217; E</p><p>Second&nbsp;line</p>');
  assert.equal(text, 'A B & C < D ’ E Second line');
  assert.equal(escapeHtml(text), 'A B &amp; C &lt; D ’ E Second line');
});

test('story filters combine text, metadata, exact tags, audio, and comments', () => {
  const story = {
    search: 'a day at granny family vacation',
    year: '2012',
    decade: '4',
    location: 'Lima, Ohio',
    genre: 'Non-Fiction',
    tags: 'family|vacation',
    hasRecordings: 'true',
    hasComments: 'false'
  };
  assert.equal(matchesStory(story, 'GRANNY', []), true);
  assert.equal(matchesStory(story, '', [{ key: 'tag', value: 'family' }]), true);
  assert.equal(matchesStory(story, '', [{ key: 'tag', value: 'fam' }]), false);
  assert.equal(matchesStory(story, 'granny', [{ key: 'year', value: '2012' }, { key: 'has_recordings', value: 'true' }]), true);
  assert.equal(matchesStory(story, 'granny', [{ key: 'year', value: '2011' }]), false);
  assert.equal(matchesStory(story, '', [{ key: 'has_comments', value: 'true' }]), false);
});

test('random story selection is uniform-shuffle based, unique, and order-randomized', () => {
  const items = ['Acadia', 'Advice', 'Award', 'Beach'];
  const randomValues = [0, 0, 0];
  const shuffled = shuffle(items, () => randomValues.shift() ?? 0);
  assert.deepEqual(shuffled, ['Advice', 'Award', 'Beach', 'Acadia']);
  assert.deepEqual(selectRandom(items, 3, () => 0), ['Advice', 'Award', 'Beach']);
  assert.equal(new Set(selectRandom(items, 3, () => 0)).size, 3);
});

test('static build emits readable story previews and core routes from synthetic data', async (t) => {
  const tempDir = await mkdtemp(path.join(os.tmpdir(), 'rdjessee-static-output-'));
  const outputPath = path.join(tempDir, 'site');
  t.after(() => rm(tempDir, { recursive: true, force: true }));

  const { result, tempDir: fixtureDir } = await runBuild(fixture(), outputPath);
  t.after(() => rm(fixtureDir, { recursive: true, force: true }));
  assert.equal(result.status, 0, result.stderr || result.stdout);

  const stories = await readFile(path.join(outputPath, 'stories.html'), 'utf8');
  const story = await readFile(path.join(outputPath, 'stories/1.html'), 'utf8');
  const home = await readFile(path.join(outputPath, 'index.html'), 'utf8');
  const randomRuntime = await readFile(path.join(outputPath, 'archive-random.js'), 'utf8');
  const quotes = JSON.parse(await readFile(path.join(outputPath, 'home-quotes.json'), 'utf8'));
  const redirects = await readFile(path.join(outputPath, '_redirects'), 'utf8');

  assert.match(stories, /A B &amp; C &lt; D ’ E/);
  assert.doesNotMatch(stories, /&amp;nbsp;|&nbsp;/i);
  assert.match(stories, /data-search="[^\"]*a b &amp; c &lt; d/);
  assert.match(story, /<p class="archive-byline">Ralph Donald Jessee<\/p>/);
  assert.match(story, /<div class="archive-prose"><p>A&nbsp;B &amp; C &lt; D &#8217; E<\/p>/);
  assert.match(story, /id="audio"/);
  assert.match(story, /id="comments"/);
  assert.match(home, /href="\/pictures\/11"/);
  assert.match(home, /id="stories"[\s\S]*?data-random-list="3"/);
  assert.doesNotMatch(home, /data-random-feature/);
  assert.match(randomRuntime, /selectRandom/);
  assert.equal(quotes.length, 6);
  assert.equal(quotes[0].pauseMs, 1000);
  assert.equal(quotes[0].pauseAfter, quotes[0].text.indexOf('\n\n'));
  assert.ok(quotes.slice(1).every((quote) => quote.pauseMs === null && quote.pauseAfter === null));
  assert.match(redirects, /\/about \/#intro 301/);
  assert.doesNotMatch(stories, /href="\/about"/);
});

test('static build fails closed when media references are unresolved', async (t) => {
  const tempDir = await mkdtemp(path.join(os.tmpdir(), 'rdjessee-static-output-'));
  t.after(() => rm(tempDir, { recursive: true, force: true }));
  const { result, tempDir: fixtureDir } = await runBuild(fixture({ unresolved_media_url_count: 1 }), path.join(tempDir, 'site'));
  t.after(() => rm(fixtureDir, { recursive: true, force: true }));
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /embedded Rails Active Storage URL/);
});
