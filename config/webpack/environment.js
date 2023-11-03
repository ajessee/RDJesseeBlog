const { environment } = require('@rails/webpacker')

const webpack = require('webpack')
environment.plugins.prepend('Provide',
  new webpack.ProvidePlugin({
    $: 'jquery/src/jquery',
    jQuery: 'jquery/src/jquery',
    Typed: ['typed.js/src/typed.js', 'default'],
    Popper: ['popper.js', 'default']
  })
)

environment.config.merge({
  output: {
    hashFunction: 'xxhash64'
  }
})

module.exports = environment
