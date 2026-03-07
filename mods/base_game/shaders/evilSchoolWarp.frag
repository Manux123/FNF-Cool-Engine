#pragma header

uniform float uTime;

void main()
{
    vec2 uv = openfl_TextureCoordv;

    // Tiempo quantizado: salta ~8 veces por segundo
    float fps = 8.0;
    float t = floor(uTime * fps) / fps;

    vec2 sc = gl_FragCoord.xy / vec2(1280.0, 720.0);

    // Distorsion horizontal (ondas que viajan en Y)
    float offX  = sin(sc.y * 6.0 + t * 0.6)               * 0.007;
    float offX2 = sin(sc.y * 3.0 + sc.x * 2.5 + t * 0.4)  * 0.004;

    // Distorsion vertical (ondas que viajan en X) — nuevo eje Y
    float offY  = sin(sc.x * 5.0 + t * 0.5)               * 0.005;
    float offY2 = sin(sc.x * 2.5 + sc.y * 2.0 + t * 0.38) * 0.003;

    vec2 rawOffset = vec2(offX + offX2, offY + offY2);

    // Snap a pasos de 2px para mantener el look pixel art
    vec2 pixelStep = vec2(2.0 / 1280.0, 2.0 / 720.0);
    vec2 snappedOffset = floor(rawOffset / pixelStep) * pixelStep;

    vec2 uvWarped = uv + snappedOffset;

    gl_FragColor = flixel_texture2D(bitmap, uvWarped);
}
