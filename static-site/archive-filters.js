(function exposeArchiveFilters(root, factory) {
  const filters = factory();
  if (typeof module === 'object' && module.exports) module.exports = filters;
  else root.StaticArchiveFilters = filters;
}(globalThis, () => {
  const matchesStory = (story, query, filters) => {
    const term = query.trim().toLowerCase();
    let matches = !term || story.search.includes(term);
    for (const { key, value } of filters) {
      if (!matches || !value) continue;
      if (key === 'tag') matches = story.tags.split('|').includes(value.toLowerCase());
      else {
        const dataKey = key === 'has_recordings' ? 'hasRecordings' : key === 'has_comments' ? 'hasComments' : key;
        matches = (story[dataKey] || '').toLowerCase() === value.toLowerCase();
      }
    }
    return matches;
  };

  return { matchesStory };
}));
