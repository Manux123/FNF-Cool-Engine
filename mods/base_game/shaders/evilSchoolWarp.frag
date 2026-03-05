#pragma header

uniform float uTime;
uniform float uWaveX;
uniform float uWaveY;
uniform float uFreqX;
uniform float uFreqY;
uniform float uSpeedX;
uniform float uSpeedY;
uniform float uRipple;
uniform float uVignette;

void main()
{
    vec2 uv = openfl_TextureCoordv;

    float wX  = uWaveX;
    float wY  = uWaveY;
    float fX  = uFreqX;
    float fY  = uFreqY;
    float sX  = uSpeedX;
    float sY  = uSpeedY;
    float rip = uRipple;
    float vig = uVignette;
    float t   = uTime;

    // Onda principal
    float offX = sin(uv.y * fX + t * sX) * wX;
    float offY = sin(uv.x * fY + t * sY) * wY;

    // Ripple diagonal
    float offX2 = sin(uv.y * fX * 0.5 + uv.x * 3.0 + t * sX * 0.7) * rip;
    float offY2 = sin(uv.x * fY * 0.5 + uv.y * 2.5 + t * sY * 0.8) * rip;

    // Respiración desde el centro
    vec2 center  = vec2(0.5, 0.5);
    float breathe = sin(t * 0.4) * 0.003;
    vec2 uvWarped = uv + vec2(offX + offX2, offY + offY2);
    uvWarped = center + (uvWarped - center) * (1.0 + breathe);

    // FIX: usar flixel_texture2D en lugar de texture2D directamente.
    // flixel_texture2D aplica openfl_Alphav (alpha del sprite) y los
    // transform de color de OpenFL.  Sin esto, el sprite ignora su propio
    // alpha y puede aparecer negro o incorrecto dependiendo del pipeline.
    vec4 color = flixel_texture2D(bitmap, uvWarped);

    // Viñeta
    if (vig > 0.0) {
        vec2 vd = uv - center;
        float vignette = 1.0 - dot(vd, vd) * vig * 2.5;
        // Sólo afectar rgb; el alpha ya lo gestiona flixel_texture2D
        color.rgb *= clamp(vignette, 0.0, 1.0);
    }

    gl_FragColor = color;
}
