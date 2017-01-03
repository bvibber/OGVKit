// inspired by https://github.com/mbebenita/Broadway/blob/master/Player/canvas.js

precision mediump float;
uniform sampler2D uTextureY;
uniform sampler2D uTextureCb;
uniform sampler2D uTextureCr;
uniform mat4 uConversionMatrix;
uniform mat3 uColorMatrixInverse;
uniform mat3 uColorMatrixOut;
varying vec2 vTexPosition;

float gammaFromBT709(float val) {
    if (val < 0.081) {
        return val / 4.5;
    } else {
        return pow((val + 0.099) / 1.099, 1.0 / 0.45);
    }
}

float gammaToSRGB(float val) {
    if (val <= 0.0031308) {
        return 12.92 * val;
    } else {
        return (1.0 + 0.055) * pow(val, 1.0 / 2.4) - 0.055;
    }
}

void main() {
    // Y, Cb, and Cr planes are uploaded as LUMINANCE textures.
    float fY = texture2D(uTextureY, vTexPosition).x;
    float fCb = texture2D(uTextureCb, vTexPosition).x;
    float fCr = texture2D(uTextureCr, vTexPosition).x;

    // Now assemble that into a YUV vector and convert that to RGB!
    vec4 vRGB = vec4(fY, fCb, fCr, 1) * uConversionMatrix;
    vec3 vLinearRGB = vec3(gammaFromBT709(vRGB.r),
                           gammaFromBT709(vRGB.g),
                           gammaFromBT709(vRGB.b));
    
    // Now turn *that* into CIE XYZ
    vec3 vXYZ = vLinearRGB * uColorMatrixInverse;
    
    // And convert that CIE XYZ into sRGB
    vec3 vLinearRGBout = vXYZ * uColorMatrixOut;
    gl_FragColor = vec4(gammaToSRGB(vLinearRGBout.r),
                        gammaToSRGB(vLinearRGBout.g),
                        gammaToSRGB(vLinearRGBout.b),
                        1);
}
