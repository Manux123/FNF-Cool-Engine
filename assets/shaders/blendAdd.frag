#pragma header

// ─────────────────────────────────────────────────────────────────────────────
//  blendAdd.frag  —  Photoshop-style ADD (Linear Dodge) blend
//
//  Suma el color del sprite con un color base (uBlendColor) y satura en 1.0.
//  Resultado = clamp(sprite_rgb + blend_rgb, 0, 1)  (siempre más claro o igual)
//
//  PARÁMETROS:
//    uBlendColor  → vec4 RGBA del color que se suma    (default: negro → sin efecto)
//    uStrength    → intensidad del efecto [0.0–1.0]    (default: 1.0)
//
//  USO HScript:
//    ShaderManager.applyShader(mySprite, "blendAdd");
//    ShaderManager.setShaderParam("blendAdd", "uBlendColor", [0.3, 0.1, 0.5, 1.0]);
//    ShaderManager.setShaderParam("blendAdd", "uStrength",   [0.7]);
// ─────────────────────────────────────────────────────────────────────────────

uniform vec4  uBlendColor;
uniform float uStrength;

void main()
{
    vec4 src = flixel_texture2D(bitmap, openfl_TextureCoordv);

    // Fallback a negro (sin efecto) si no fue seteado
    vec4 blend = (uBlendColor.r == 0.0 && uBlendColor.g == 0.0
                  && uBlendColor.b == 0.0 && uBlendColor.a == 0.0)
                 ? vec4(0.0, 0.0, 0.0, 1.0)
                 : uBlendColor;

    // Fórmula Add: resultado = saturate(src + blend)
    vec4 added = clamp(src + blend, 0.0, 1.0);

    float str = (uStrength == 0.0) ? 1.0 : uStrength;
    vec4 result = mix(src, added, str);

    result.a = src.a;
    gl_FragColor = result;
}
