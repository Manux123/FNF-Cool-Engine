#pragma header

// ─────────────────────────────────────────────────────────────────────────────
//  blendMultiply.frag  —  Photoshop-style MULTIPLY blend
//
//  Multiplica el color del sprite con un color base (uBlendColor).
//  Resultado = sprite_rgb * blend_rgb   (siempre más oscuro o igual)
//
//  PARÁMETROS:
//    uBlendColor  → vec4 RGBA del color con que mezclar  (default: blanco → sin efecto)
//    uStrength    → intensidad del efecto [0.0–1.0]       (default: 1.0)
//
//  USO HScript:
//    ShaderManager.applyShader(mySprite, "blendMultiply");
//    ShaderManager.setShaderParam("blendMultiply", "uBlendColor", [r, g, b, a]);
//    ShaderManager.setShaderParam("blendMultiply", "uStrength",   [0.8]);
// ─────────────────────────────────────────────────────────────────────────────

uniform vec4  uBlendColor;  // color de mezcla en espacio lineal (0.0–1.0)
uniform float uStrength;    // 0.0 = sin efecto, 1.0 = efecto completo

void main()
{
    vec4 src = flixel_texture2D(bitmap, openfl_TextureCoordv);

    // Fallback a blanco (sin efecto) si uBlendColor no fue seteado
    vec4 blend = (uBlendColor.a == 0.0) ? vec4(1.0) : uBlendColor;

    // Fórmula Multiply: resultado = src * blend
    vec4 multiplied = src * blend;

    // Fuerza del efecto
    float str = (uStrength == 0.0) ? 1.0 : uStrength;
    vec4 result = mix(src, multiplied, str);

    // Preservar alpha original del sprite
    result.a = src.a;

    gl_FragColor = result;
}
