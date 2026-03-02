#pragma header

// ─────────────────────────────────────────────────────────────────────────────
//  blendColorize.frag  —  Colorize (tono HSV) al estilo Photoshop "Colorize"
//
//  Desatura el sprite y le aplica un tono de color uniforme,
//  preservando los valores de luminosidad (V en HSV).
//  Equivale a Hue/Saturation → Colorize en Photoshop.
//
//  PARÁMETROS:
//    uHue         → tono [0.0–360.0]         (default: 0.0  → rojo)
//    uSaturation  → saturación [0.0–1.0]     (default: 0.5)
//    uStrength    → mezcla con original [0–1] (default: 1.0)
//
//  USO HScript:
//    ShaderManager.applyShader(mySprite, "blendColorize");
//    ShaderManager.setShaderParam("blendColorize", "uHue",        [200.0]); // azul
//    ShaderManager.setShaderParam("blendColorize", "uSaturation", [0.7]);
// ─────────────────────────────────────────────────────────────────────────────

uniform float uHue;
uniform float uSaturation;
uniform float uStrength;

// Conversión HSV → RGB
vec3 hsv2rgb(float h, float s, float v)
{
    float c  = v * s;
    float h6 = mod(h / 60.0, 6.0);
    float x  = c * (1.0 - abs(mod(h6, 2.0) - 1.0));
    float m  = v - c;

    vec3 rgb;
    if      (h6 < 1.0) rgb = vec3(c, x, 0.0);
    else if (h6 < 2.0) rgb = vec3(x, c, 0.0);
    else if (h6 < 3.0) rgb = vec3(0.0, c, x);
    else if (h6 < 4.0) rgb = vec3(0.0, x, c);
    else if (h6 < 5.0) rgb = vec3(x, 0.0, c);
    else               rgb = vec3(c, 0.0, x);

    return rgb + m;
}

void main()
{
    vec4 src = flixel_texture2D(bitmap, openfl_TextureCoordv);

    // Luminosidad del pixel original (coeficientes Rec.709)
    float lum = dot(src.rgb, vec3(0.2126, 0.7152, 0.0722));

    float h   = (uHue == 0.0)        ? 0.0   : uHue;
    float sat = (uSaturation == 0.0) ? 0.5   : uSaturation;
    float str = (uStrength == 0.0)   ? 1.0   : uStrength;

    vec3 colorized = hsv2rgb(h, sat, lum);
    vec3 blended   = mix(src.rgb, colorized, str);

    gl_FragColor = vec4(blended, src.a);
}
