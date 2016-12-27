// inspired by https://github.com/mbebenita/Broadway/blob/master/Player/canvas.js

precision mediump float;
uniform sampler2D uTextureYCbCr;
varying vec2 vLumaPosition;
varying vec2 vChromaPosition;

void main() {
   // Y, Cb, and Cr planes are packed into a single texture.
   vec4 vYCbCr = texture2D(uTextureYCbCr, vLumaPosition);

   // Now assemble that into a YUV vector, and premultipy the Y...
   vec3 YUV = vec3(
     vYCbCr.g * 1.1643828125,
     vYCbCr.b,
     vYCbCr.r
   );
   // And convert that to RGB!
   gl_FragColor = vec4(
     YUV.x + 1.59602734375 * YUV.z - 0.87078515625,
     YUV.x - 0.39176171875 * YUV.y - 0.81296875 * YUV.z + 0.52959375,
     YUV.x + 2.017234375   * YUV.y - 1.081390625,
     1
   );
}
