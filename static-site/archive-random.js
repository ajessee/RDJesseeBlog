(function exposeArchiveRandom(root, factory) {
  const randomTools = factory();
  if (typeof module === 'object' && module.exports) module.exports = randomTools;
  else root.StaticArchiveRandom = randomTools;
}(globalThis, () => {
  const shuffle = (items, random = Math.random) => {
    const result = [...items];
    for (let i = result.length - 1; i > 0; i--) {
      const j = Math.floor(random() * (i + 1));
      [result[i], result[j]] = [result[j], result[i]];
    }
    return result;
  };

  const selectRandom = (items, limit, random = Math.random) => shuffle(items, random).slice(0, limit);
  return { shuffle, selectRandom };
}));
