// Rich text stays in ordinary HTML columns; files use the dedicated upload fields.
document.addEventListener('trix-file-accept', function (event) { event.preventDefault(); });
