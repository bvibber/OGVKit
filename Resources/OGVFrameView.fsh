// inspired by https://github.com/mbebenita/Broadway/blob/master/Player/canvas.js

precision mediump float;
uniform sampler2D uTextureY;
uniform sampler2D uTextureCb;
uniform sampler2D uTextureCr;
varying vec2 vTexPosition;

void main() {
   // Y, Cb, and Cr planes are uploaded as LUMINANCE textures.
   vec4 vY = texture2D(uTextureY, vTexPosition);
   vec4 vCb = texture2D(uTextureCb, vTexPosition);
   vec4 vCr = texture2D(uTextureCr, vTexPosition);

   // Now assemble that into a YUV vector, and premultipy the Y...
   vec3 YUV = vec3(
     vY.x * 1.1643828125,
     vCb.x,
     vCr.x
   );
   // And convert that to RGB!
   gl_FragColor = vec4(
     YUV.x + 1.59602734375 * YUV.z - 0.87078515625,
     YUV.x - 0.39176171875 * YUV.y - 0.81296875 * YUV.z + 0.52959375,
     YUV.x + 2.017234375   * YUV.y - 1.081390625,
     1
   );
}
