export const escapeHtml = (value = '') => String(value).replace(/[&<>"']/g, (character) => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
})[character]);

export const plainText = (html = '') => String(html)
  .replace(/<br\s*\/?>/gi, ' ')
  .replace(/<\/(?:p|div|li|h[1-6]|blockquote)\s*>/gi, ' ')
  .replace(/<[^>]*>/g, ' ')
  .replace(/&nbsp;/gi, ' ')
  .replace(/&amp;/gi, '&')
  .replace(/&lt;/gi, '<')
  .replace(/&gt;/gi, '>')
  .replace(/&quot;/gi, '"')
  .replace(/&#39;|&apos;/gi, "'")
  .replace(/&#(\d+);|&#x([\da-f]+);/gi, (_, decimal, hexadecimal) => {
    const codePoint = Number.parseInt(decimal || hexadecimal, decimal ? 10 : 16);
    return Number.isFinite(codePoint) && codePoint <= 0x10ffff ? String.fromCodePoint(codePoint) : ' ';
  })
  .replace(/[\s\u00a0]+/g, ' ')
  .trim();
