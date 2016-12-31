attribute vec2 aPosition;
attribute vec2 aTexPosition;
varying vec2 vTexPosition;

void main() {
    gl_Position = vec4(aPosition, 0, 1);
    vTexPosition = aTexPosition;
}
