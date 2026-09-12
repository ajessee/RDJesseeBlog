require 'vips'

# Uploaded images are untrusted. Keep libvips' hardened JPEG, PNG, GIF, and WebP
# loaders available while disabling formats backed by less-hardened libraries.
Vips.block_untrusted(true)
