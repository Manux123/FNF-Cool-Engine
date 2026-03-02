#pragma header

// ─────────────────────────────────────────────────────────────────────────────
//  blendOverlay.frag  —  Photoshop-style OVERLAY blend
//
//  Overlay combina Multiply y Screen según la luminosidad del blend:
//    si blend < 0.5 → Multiply (oscurece)
//    si blend ≥ 0.5 → Screen   (aclara)
//  Aumenta contraste y satura sin clips bruscos.
//
//  PARÁMETROS:
//    uBlendColor  → vec4 RGBA del color overlay    (default: gris 50% → sin efecto)
//    uStrength    → intensidad [0.0–1.0]           (default: 1.0)
//
//  USO HScript:
//    ShaderManager.applyShader(mySprite, "blendOverlay");
//    ShaderManager.setShaderParam("blendOverlay", "uBlendColor", [1.0, 0.5, 0.0, 1.0]);
// ─────────────────────────────────────────────────────────────────────────────

uniform vec4  uBlendColor;
uniform float uStrength;

float overlayChannel(float src, float blend)
{
    return (blend < 0.5)
        ? 2.0 * src * blend
        : 1.0 - 2.0 * (1.0 - src) * (1.0 - blend);
}

void main()
{
    vec4 src   = flixel_texture2D(bitmap, openfl_TextureCoordv);
    // Default: gris 50% (overlay neutro — sin cambio visible)
    vec4 blend = (uBlendColor.a == 0.0)
        ? vec4(0.5, 0.5, 0.5, 1.0)
        : uBlendColor;

    vec4 overlayed = vec4(
        overlayChannel(src.r, blend.r),
        overlayChannel(src.g, blend.g),
        overlayChannel(src.b, blend.b),
        src.a
    );

    float str   = (uStrength == 0.0) ? 1.0 : uStrength;
    vec4 result = mix(src, overlayed, str);
    result.a    = src.a;

    gl_FragColor = result;
}
