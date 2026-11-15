import { cp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { escapeHtml, plainText } from './html-text.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const inputPath = path.resolve(root, process.env.STATIC_ARCHIVE_EXPORT || 'tmp/static-archive/export-cloudfront.json');
const outputPath = path.resolve(root, process.env.STATIC_ARCHIVE_OUTPUT || 'dist/static-site');
const ga4MeasurementId = process.env.GA4_MEASUREMENT_ID?.trim() || '';

if (ga4MeasurementId && !/^G-[A-Z0-9]+$/i.test(ga4MeasurementId)) {
  throw new Error('GA4_MEASUREMENT_ID must be a Google Analytics 4 web stream ID (G-...).');
}

const googleAnalyticsTag = ga4MeasurementId ? `  <!-- Google tag (gtag.js) -->
  <script async src="https://www.googletagmanager.com/gtag/js?id=${ga4MeasurementId}"></script>
  <script>
    window.dataLayer = window.dataLayer || [];
    function gtag(){dataLayer.push(arguments);}
    gtag('js', new Date());
    gtag('config', '${ga4MeasurementId}');
  </script>` : '';

const slug = (value = '') => String(value).toLowerCase()
  .normalize('NFKD').replace(/[\u0300-\u036f]/g, '')
  .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '') || 'tag';

const media = (item, kind, label = '') => {
  if (!item?.url) return '';
  const url = escapeHtml(item.url);
  if (kind === 'audio') return `<audio controls preload="none" src="${url}">${escapeHtml(label || item.filename || 'Audio recording')}</audio>`;
  return `<img loading="lazy" src="${url}" alt="${escapeHtml(label || item.filename || 'Archive photograph')}">`;
};

const layout = (title, body, active = '') => `<!doctype html>
<html lang="en">
<head>
${googleAnalyticsTag}
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <script>document.documentElement.classList.add('js');</script>
  <meta name="description" content="Stories and memories from the life of Ralph Donald Jessee.">
  <title>${escapeHtml(title)} | Ralph Donald Jessee</title>
  <link rel="icon" href="/favicon.ico">
  <link rel="stylesheet" href="/archive.css">
</head>
<body class="archive-page${title === 'Home' ? ' archive-home-page' : ''}">
  <header class="archive-header"><a class="archive-brand" href="/"><img src="/images/rdjesseeLogo.png" alt="Ralph Donald Jessee"></a>
    <nav aria-label="Main navigation">
      <a ${active === 'stories' ? 'aria-current="page"' : ''} href="/stories">Stories</a>
      <a ${active === 'pictures' ? 'aria-current="page"' : ''} href="/pictures">Pictures</a>
      <a ${active === 'recordings' ? 'aria-current="page"' : ''} href="/recordings">Recordings</a>
      <a ${active === 'tags' ? 'aria-current="page"' : ''} href="/tags">Tags</a>
    </nav>
  </header>
  <main class="archive-main">${body}</main>
  <footer class="archive-footer">A family archive preserving the writing and memories of Ralph “Don” Jessee.</footer>
  <script src="/archive-filters.js" defer></script>
  <script src="/archive-random.js" defer></script>
  <script src="/archive.js" defer></script>
</body>
</html>`;

const writePage = async (relativePath, title, body, active = '') => {
  const destination = path.join(outputPath, relativePath);
  await mkdir(path.dirname(destination), { recursive: true });
  await writeFile(destination, layout(title, body, active));
};

const input = JSON.parse(await readFile(inputPath, 'utf8'));
if (input.schema_version !== 1) throw new Error(`Unsupported export schema version: ${input.schema_version}`);
if (input.unresolved_media_url_count > 0) throw new Error(`Static build stopped: ${input.unresolved_media_url_count} embedded Rails Active Storage URL(s) need mapping.`);
if (input.unmapped_media_reference_count > 0) throw new Error(`Static build stopped: ${input.unmapped_media_reference_count} attached media item(s) need stable URLs.`);

await rm(outputPath, { recursive: true, force: true });
await mkdir(outputPath, { recursive: true });
await cp(path.join(root, 'static-site'), outputPath, { recursive: true });
await cp(path.join(root, 'app/assets/images'), path.join(outputPath, 'images'), { recursive: true });
await cp(path.join(root, 'app/assets/images/rdjessee_icon.ico'), path.join(outputPath, 'favicon.ico'));
await mkdir(path.join(outputPath, 'fonts'), { recursive: true });
await cp(path.join(root, 'app/assets/fonts'), path.join(outputPath, 'fonts'), { recursive: true });

const storiesById = new Map(input.stories.map((story) => [story.id, story]));
const commentsById = new Map(input.comments.map((comment) => [comment.id, comment]));
const picturesById = new Map(input.pictures.map((picture) => [picture.id, picture]));
const recordingsById = new Map(input.recordings.map((recording) => [recording.id, recording]));
const tagsByName = new Map(input.tags.map((tag) => [tag.name, tag]));

const storyCard = (story, { showListen = true } = {}) => { const text = plainText(story.content_html); const words = text.split(/\s+/).filter(Boolean).length; const minutes = Math.max(1, Math.ceil(words / 130)); return `<article class="archive-card" data-story data-search="${escapeHtml([story.title, text, story.tags.join(' '), story.location, story.genre].join(' ').toLowerCase())}" data-year="${escapeHtml(story.year_written || '')}" data-decade="${escapeHtml(story.decade || '')}" data-location="${escapeHtml(story.location || '')}" data-genre="${escapeHtml(story.genre || '')}" data-category="${escapeHtml(story.category || '')}" data-life-stage="${escapeHtml(story.life_stage || '')}" data-tags="${escapeHtml(story.tags.join('|').toLowerCase())}" data-has-recordings="${story.recording_ids.length > 0}" data-has-comments="${story.comment_ids.length > 0}">
  ${story.picture?.url ? `<a class="archive-card-image" href="/stories/${story.id}">${media(story.picture, 'image', story.title)}</a>` : ''}
  <div class="archive-card-content"><p class="archive-meta">${escapeHtml(story.year_written || 'Undated')}${story.location ? ` · ${escapeHtml(story.location)}` : ''} · ${minutes} min read</p>
  <h2><a href="/stories/${story.id}">${escapeHtml(story.title)}</a></h2><p>${escapeHtml(text.slice(0, 260))}…</p>
  <div class="archive-card-tags">${story.tags.slice(0, 5).map((name) => { const tag = tagsByName.get(name); return tag ? `<a class="archive-tag" href="/tags/${tag.id}">${escapeHtml(name)}</a>` : ''; }).join(' ')}</div>${(showListen && story.recording_ids.length) || story.comment_ids.length ? `<div class="archive-card-links">${showListen && story.recording_ids.length ? `<a href="/stories/${story.id}#audio">Listen</a>` : ''}${showListen && story.recording_ids.length && story.comment_ids.length ? ' · ' : ''}${story.comment_ids.length ? `<a href="/stories/${story.id}#comments">${story.comment_ids.length} comments</a>` : ''}</div>` : ''}</div></article>`; };

const filterSelect = (label, key, values) => `<label>${label}<select data-filter="${key}"><option value="">All ${label.toLowerCase()}</option>${[...new Set(values.filter(Boolean))].sort().map((value) => `<option value="${escapeHtml(value)}">${escapeHtml(value)}</option>`).join('')}</select></label>`;
const storyIndex = `<section class="archive-hero archive-story-index"><p class="archive-eyebrow">The writing archive</p><h1>Stories</h1><p>Browse Don’s stories by title, subject, place, or tag.</p>
  <label class="archive-search-label" for="archive-search">Search stories<input id="archive-search" type="search" placeholder="Search words, places, tags…" data-story-search></label>
  <div class="archive-filters">${filterSelect('Year','year',input.stories.map((s) => s.year_written))}${filterSelect('Decade','decade',input.stories.map((s) => s.decade))}${filterSelect('Location','location',input.stories.map((s) => s.location))}${filterSelect('Genre','genre',input.stories.map((s) => s.genre))}${filterSelect('Tag','tag',input.tags.map((t) => t.name))}<label class="archive-filter-check"><input type="checkbox" data-filter="has_recordings"> Has audio</label><label class="archive-filter-check"><input type="checkbox" data-filter="has_comments"> Has comments</label><button type="button" class="archive-clear-filters" data-clear-filters>Clear all filters</button></div>
  <p class="archive-results" data-search-count>${input.stories.length} stories</p></section>
  <section class="archive-grid" data-story-list>${input.stories.map(storyCard).join('\n')}</section>
  <p class="archive-empty" hidden data-search-empty>No stories match that search.</p>`;
await writePage('stories.html', 'Stories', storyIndex, 'stories');

for (const story of input.stories) {
  const recordings = story.recording_ids.map((id) => recordingsById.get(id)).filter(Boolean);
  const comments = story.comment_ids.map((id) => commentsById.get(id)).filter(Boolean);
  const tagLinks = story.tags.map((name) => {
    const tag = tagsByName.get(name);
    return tag ? `<a class="archive-tag" href="/tags/${tag.id}">${escapeHtml(name)}</a>` : '';
  }).join(' ');
  const storyBody = `<article class="archive-story"><p class="archive-meta">${escapeHtml(story.year_written || 'Undated')}</p>
    <h1>${escapeHtml(story.title)}</h1><p class="archive-byline">Ralph Donald Jessee</p><div class="archive-tags">${tagLinks}</div>
    ${media(story.picture, 'image', story.title)}
    ${recordings.map((recording) => `<section class="archive-media" id="audio"><h2>${escapeHtml(recording.caption_html.replace(/<[^>]*>/g, ' ') || 'Story reading')}</h2>${media(recording.audio, 'audio')}</section>`).join('')}
    <div class="archive-prose">${story.content_html}</div>
    ${comments.length ? `<section class="archive-comments" id="comments"><h2>Memories and comments</h2>${comments.map((comment) => `<article class="archive-comment"><h3>${escapeHtml(comment.author_name || 'Family member')}</h3><div>${comment.content_html}</div></article>`).join('')}</section>` : ''}
    </article>`;
  await writePage(`stories/${story.id}.html`, story.title, storyBody, 'stories');
}

const pictureCards = input.pictures.map((picture) => `<article class="archive-card">${picture.image?.url ? `<a class="archive-card-image" href="/pictures/${picture.id}">${media(picture.image, 'image', picture.caption_html.replace(/<[^>]*>/g, ' '))}</a>` : ''}<div class="archive-card-content"><h2><a href="/pictures/${picture.id}">${picture.caption_html || 'Photograph'}</a></h2><p class="archive-meta">${escapeHtml(picture.photographer_name || '')}</p></div></article>`).join('');
await writePage('pictures.html', 'Pictures', `<section class="archive-hero"><p class="archive-eyebrow">Family photographs</p><h1>Pictures</h1></section><section class="archive-grid">${pictureCards}</section>`, 'pictures');
for (const picture of input.pictures) {
  const comments = picture.comment_ids.map((id) => commentsById.get(id)).filter(Boolean);
  const body = `<article class="archive-story archive-picture-detail"><h1>${picture.caption_html || 'Photograph'}</h1><div class="archive-picture-viewer">${media(picture.image, 'image', picture.caption_html.replace(/<[^>]*>/g, ' '))}</div><p class="archive-meta">${escapeHtml(picture.photographer_name || '')}</p>${comments.map((comment) => `<article class="archive-comment"><h2>${escapeHtml(comment.author_name || 'Family member')}</h2><div>${comment.content_html}</div></article>`).join('')}</article>`;
  await writePage(`pictures/${picture.id}.html`, 'Picture', body, 'pictures');
}

const standaloneRecordings = input.recordings.filter((recording) => recording.recordable_type === 'User');
await writePage('recordings.html', 'Recordings', `<section class="archive-hero"><p class="archive-eyebrow">Voices and memories</p><h1>Recordings</h1></section><section class="archive-list">${standaloneRecordings.map((recording) => `<article class="archive-recording"><h2>${escapeHtml(recording.caption_html.replace(/<[^>]*>/g, ' ') || 'A family memory')}</h2>${media(recording.audio, 'audio')}<p class="archive-meta">${escapeHtml(recording.created_at || '')}</p></article>`).join('')}</section>`, 'recordings');

const tagItems = input.tags.map((tag) => {
  return `<li><a href="/tags/${tag.id}">${escapeHtml(tag.name)}</a><span>${tag.story_ids.length} stories</span></li>`;
}).join('');
await writePage('tags.html', 'Tags', `<section class="archive-hero"><p class="archive-eyebrow">Browse by subject</p><h1>Tags</h1></section><ul class="archive-tag-list">${tagItems}</ul>`, 'tags');
for (const tag of input.tags) {
  const linkedStories = tag.story_ids.map((id) => storiesById.get(id)).filter(Boolean);
  await writePage(`tags/${tag.id}.html`, tag.name, `<section class="archive-hero"><p class="archive-eyebrow">Stories tagged</p><h1>${escapeHtml(tag.name)}</h1></section><section class="archive-grid">${linkedStories.map(storyCard).join('')}</section>`, 'tags');
}

const guestbookComments = input.comments
  .filter((comment) => comment.commentable_type === 'User')
  .sort((a, b) => {
    const sameDay = a.created_at?.slice(0, 10) === '2017-05-17'
      && b.created_at?.slice(0, 10) === '2017-05-17';
    const bothFromDavid = a.author_name?.startsWith('David L.')
      && b.author_name?.startsWith('David L.');
    if (sameDay && bothFromDavid) {
      const aIsRequestedFirst = a.content_html.startsWith('I must extend');
      const bIsRequestedFirst = b.content_html.startsWith('I must extend');
      if (aIsRequestedFirst !== bIsRequestedFirst) return aIsRequestedFirst ? -1 : 1;
    }
    return Date.parse(a.created_at || 0) - Date.parse(b.created_at || 0);
  });
const formatCommentDate = (value) => {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? '' : new Intl.DateTimeFormat('en-US', {
    year: 'numeric', month: 'long', day: 'numeric', timeZone: 'UTC',
  }).format(date);
};
const guestbookAuthorName = (name) => name === 'David L.Jessee' ? 'David L. Jessee' : name;
const userRecordings = input.recordings.filter((recording) => recording.recordable_type === 'User');
const recordedStories = input.stories.filter((story) => story.recording_ids.length > 0);
const illustratedStories = input.stories.filter((story) => story.picture?.url);
const originalWelcomeJs = await readFile(path.join(root, 'app/assets/javascripts/welcome.js'), 'utf8');
const quoteSource = originalWelcomeJs.match(/var quotes = (\[[\s\S]*?\])\s*\n\s*\n/)?.[1];
if (!quoteSource) throw new Error('Could not find the original homepage quote selection.');
const originalQuotes = JSON.parse(quoteSource).map(([text]) => text);
const quoteStarts = [
  'I notice that people are rushing around',
  'At that time I also had night dreams',
  'As the darkness gradually dissipated',
  'From our balcony we could watch the sun creep up',
  'The late October sun in a sky unadulterated',
  'The world has a ghostly appearance'
];
const storyQuotes = originalQuotes.map((originalText, index) => {
  const pauseMarker = originalText.match(/\^(\d+) <br><br>/);
  const pauseIndex = pauseMarker ? originalText.indexOf(pauseMarker[0]) : -1;
  const text = originalText.replace(/\^\d+ <br><br>/, '\n\n');
  const story = input.stories.find((candidate) => candidate.content_html.includes(quoteStarts[index]));
  if (!story) throw new Error(`Could not match original hero passage ${index + 1} to a story.`);
  return {
    title: story.title,
    id: story.id,
    text,
    pauseAfter: pauseIndex < 0 ? null : text.indexOf('\n\n', pauseIndex),
    pauseMs: pauseMarker ? Number.parseInt(pauseMarker[1], 10) : null
  };
});
await writeFile(path.join(outputPath, 'home-quotes.json'), JSON.stringify(storyQuotes));
const bio = `Ralph “Don” Jessee (September 13, 1921 – April 3, 2016) was born in the mountains of southwestern Virginia. During the Great Depression his family moved to Kentucky. After two years at Lincoln Memorial University, he earned his engineering degree at the University of Kentucky. He was hired by Westinghouse and, after a stint in the army, returned to the Aviation Division at Lima, Ohio. He enjoyed designing control and protective devices and methods for aircraft electric power systems, and was granted 30 U.S. patents during his 49-year career. Meanwhile he took a wife and reared a family of four children. Late in life he moved to Louisiana to live with his daughter Catherine and her family. He enrolled in a life-writing class at Catherine’s insistence. Don wrote prodigiously for 10 years in spite of worsening macular degeneration, leaving a surprising legacy of stories, poems, and letters. They are archived here for your perusal and enjoyment.`;
const obituarySource = await readFile(path.join(root, 'app/views/welcome/_obit.html.erb'), 'utf8');
const obituarySection = obituarySource.match(/<section class="testimonials bg-gray"[^]*?<\/section>/)?.[0] || '';
const obituaryHtml = obituarySection
  .replace(/<%= image_tag\("([^"]+)", alt: "([^"]+)",[^%]*%>/g, '<img src="/images/$1" alt="$2">')
  .replace(/<!--[\s\S]*?-->/g, '');
const quotePanels = [
  ['book.jpg', 'It was painful to write about things, which had been embarrassing to me at the time they happened. But when I read what I had written, I realized it wasn’t about me, but about a little boy who lived a long time ago. Upon hearing my classmates read their stories I realized that their lives might not have been so different from mine. That gave me confidence to write my own stories.', 'From “Write? Me?” — R.D. Jessee'],
  ['blurred.jpg', 'Looking at old pictures I see things that are sort of familiar or perhaps ought to be. For instance here is one taken in the front or side yard of an old house. I see shades of gray in broad outline except for things that are familiar such as faces and certain shapes. I depend on the vision of others to identify for me other shapes.', 'From “Old Pictures” — R.D. Jessee'],
  ['microphone.jpg', 'If I could speak to the child I would simply encourage him to learn to love to read. The child never learned to read well, so he was a slow reader and reading always took too long. He needed practice reading some really interesting short stories.', 'From “Thoughts of Childhood” — R.D. Jessee']
];
const quotePanel = (index, align) => { const [image, quote, attribution] = quotePanels[index]; return `<aside class="archive-parallax archive-parallax-${index+1} archive-parallax-${align}" style="--parallax-image:url('/images/${image}')"><blockquote>“${escapeHtml(quote)}”</blockquote><p>— ${escapeHtml(attribution)}</p></aside>`; };
const pictureCard = (picture) => `<article class="archive-card" data-random-item>${picture.image?.url ? `<a class="archive-card-image" href="/pictures/${picture.id}">${media(picture.image, 'image', picture.caption_html.replace(/<[^>]*>/g, ' ') || 'Family photograph')}</a>` : ''}<div class="archive-card-content"><h3><a href="/pictures/${picture.id}">${picture.caption_html || 'Photograph'}</a></h3></div></article>`;
const audioCard = (recording) => `<article class="archive-recording" data-random-item><h3>${escapeHtml(recording.caption_html.replace(/<[^>]*>/g, ' ') || 'A family memory')}</h3>${media(recording.audio, 'audio')}</article>`;
const recordedStoryCard = (story) => {
  const recording = story.recording_ids.map((id) => recordingsById.get(id)).find(Boolean);
  const audio = recording ? `<div class="archive-inline-audio">${media(recording.audio, 'audio', recording.caption_html.replace(/<[^>]*>/g, ' ') || story.title)}</div>` : '';
  const card = storyCard(story, { showListen: false }).replace('</div></article>', `${audio}</div></article>`);
  return `<div class="archive-recording-story" data-random-item>${card}</div>`;
};
const randomizedList = (items, limit, render) => {
  const shuffled = [...items];
  for (let i = shuffled.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }
  const initial = new Set(shuffled.slice(0, limit).map((item) => item.id));
  return shuffled.map((item) => render(item).replace(/^(<(?:article|div)\b)/, `$1${initial.has(item.id) ? '' : ' hidden'}`)).join('');
};
const carousel = obituaryHtml.replace('<div class="testimonials-carousel">', '<div class="testimonials-carousel" data-obit-carousel>');
const homeBody = `<section class="archive-home-hero"><div class="archive-home-hero-inner"><h1><span class="archive-sr-only">Remembering Ralph “Don” Jessee</span><span data-random-quote aria-live="polite">Remembering Ralph “Don” Jessee</span></h1><img class="archive-home-signature" data-hero-reveal src="/images/rdjesseeLogo.png" alt="Ralph Donald Jessee"><a class="archive-scroll-book" data-hero-reveal href="#intro" aria-label="Scroll down to His Story"><svg viewBox="0 0 48 48" aria-hidden="true"><path d="M4 9c8-3 15-1 20 3v29c-5-4-12-6-20-3V9Zm40 0c-8-3-15-1-20 3v29c5-4 12-6 20-3V9Z"/><path d="M24 12v29"/></svg></a></div></section>
  <section class="archive-summary" id="intro"><img class="archive-summary-portrait" src="/images/donsmiles.jpg" alt="Ralph Donald Jessee smiling"><div class="archive-summary-copy"><p class="archive-eyebrow">His story</p><p>${escapeHtml(bio)}</p></div></section>
  ${quotePanel(0, 'left')}
  <section class="archive-home-section" id="stories"><p class="archive-eyebrow">From the collection</p><h2>Stories</h2><div class="archive-grid" data-random-list="3">${randomizedList(illustratedStories, 3, (story) => storyCard(story).replace('<article class="archive-card"', '<article class="archive-card" data-random-item'))}</div><p class="archive-section-link"><a class="archive-button" href="/stories">Browse and filter all stories</a></p></section>
  ${quotePanel(1, 'right')}
  <section class="archive-home-section archive-pictures-section" id="pictures"><p class="archive-eyebrow">Moments together</p><h2>Pictures</h2><div class="archive-grid" data-random-list="3">${randomizedList(input.pictures, 3, pictureCard)}</div><p class="archive-section-link"><a class="archive-button archive-button-secondary" href="/pictures">See all pictures</a></p></section>
  ${quotePanel(2, 'left')}
  <section class="archive-home-section archive-recordings-section" id="recordings"><p class="archive-eyebrow">Voices preserved</p><h2>Recordings</h2><div class="archive-recordings-columns"><div><h3>Audio recordings</h3><div class="archive-list" data-random-list="4">${randomizedList(userRecordings, 4, audioCard)}</div></div><div><h3>Stories with recorded readings</h3><div class="archive-list" data-random-list="3">${randomizedList(recordedStories, 3, recordedStoryCard)}</div></div></div><p class="archive-section-link"><a class="archive-button archive-button-secondary" href="/recordings">Browse all recordings</a></p></section>
  <section class="archive-home-section archive-obituary"><p class="archive-eyebrow">Remembering Don</p><h2>His life and legacy</h2>${carousel}</section>
  <section class="archive-home-section archive-home-guestbook"><p class="archive-eyebrow">Leave a memory</p><h2>Guestbook</h2><p>Thanks for stopping by! We’d love it if you could leave a comment or memory of Don to share with us.</p>${guestbookComments.map((comment) => {
    const date = formatCommentDate(comment.created_at);
    return `<article class="archive-comment archive-guestbook-card"><header><h3>${escapeHtml(guestbookAuthorName(comment.author_name) || 'Family member')}</h3>${date ? `<time datetime="${escapeHtml(comment.created_at)}">${escapeHtml(date)}</time>` : ''}</header><div>${comment.content_html}</div></article>`;
  }).join('') || '<p>Guestbook memories will appear here.</p>'}</section>`;
await writePage('index.html', 'Home', homeBody);

await writeFile(path.join(outputPath, '404.html'), layout('Page not found', '<section class="archive-hero"><h1>Page not found</h1><p>That address may have changed. Browse the <a href="/stories">story archive</a> or return <a href="/">home</a>.</p></section>'));
await writeFile(path.join(outputPath, 'robots.txt'), 'User-agent: *\nAllow: /\n');
await writeFile(path.join(outputPath, 'sitemap.xml'), `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n  ${['/', '/stories', ...input.stories.map((story) => `/stories/${story.id}`), '/pictures', ...input.pictures.map((picture) => `/pictures/${picture.id}`), '/recordings', '/tags', ...input.tags.map((tag) => `/tags/${tag.id}`)].map((url) => `<url><loc>https://ralphdonaldjessee.com${url}</loc></url>`).join('\n  ')}\n</urlset>\n`);
await writeFile(path.join(outputPath, '_redirects'), '/blog /stories 301\n/welcome / 301\n/about /#intro 301\n/tag_cloud /tags 301\n/videos /stories 301\n/videos/* /stories 301\n/stories/sort /stories 200\n/stories/search /stories 200\n');

console.log(`Built ${input.stories.length} stories, ${input.pictures.length} pictures, ${input.recordings.length} recordings, and ${input.tags.length} tag pages in ${path.relative(root, outputPath)}`);
