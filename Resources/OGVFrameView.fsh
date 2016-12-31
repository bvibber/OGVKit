// inspired by https://github.com/mbebenita/Broadway/blob/master/Player/canvas.js

precision mediump float;
uniform sampler2D uTextureY;
uniform sampler2D uTextureCb;
uniform sampler2D uTextureCr;
uniform mat4 uConversionMatrix;
varying vec2 vTexPosition;

void main() {
   // Y, Cb, and Cr planes are uploaded as LUMINANCE textures.
   float fY = texture2D(uTextureY, vTexPosition).x;
   float fCb = texture2D(uTextureCb, vTexPosition).x;
   float fCr = texture2D(uTextureCr, vTexPosition).x;

   // Now assemble that into a YUV vector and convert that to RGB!
   gl_FragColor = vec4(fY, fCb, fCr, 1) * uConversionMatrix;
}
