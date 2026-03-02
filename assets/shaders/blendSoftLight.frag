#pragma header

// ─────────────────────────────────────────────────────────────────────────────
//  blendSoftLight.frag  —  Photoshop-style SOFT LIGHT blend
//
//  Más suave que Overlay — oscurece/aclara según blend,
//  sin clips tan duros. Ideal para iluminación difusa sobre personajes.
//
//    si blend ≤ 0.5 → src - (1-2*blend)*src*(1-src)
//    si blend > 0.5 → src + (2*blend-1)*(D-src)
//      donde D = sqrt(src) si src ≥ 0.25, sino ((16*src-12)*src+4)*src
//
//  PARÁMETROS:
//    uBlendColor  → vec4 RGBA  (default: gris 50% → neutro)
//    uStrength    → [0.0–1.0]  (default: 1.0)
// ─────────────────────────────────────────────────────────────────────────────

uniform vec4  uBlendColor;
uniform float uStrength;

float softLightChannel(float src, float blend)
{
    if (blend <= 0.5)
    {
        return src - (1.0 - 2.0 * blend) * src * (1.0 - src);
    }
    else
    {
        float D;
        if (src >= 0.25)
            D = sqrt(src);
        else
            D = ((16.0 * src - 12.0) * src + 4.0) * src;

        return src + (2.0 * blend - 1.0) * (D - src);
    }
}

void main()
{
    vec4 src   = flixel_texture2D(bitmap, openfl_TextureCoordv);
    vec4 blend = (uBlendColor.a == 0.0)
        ? vec4(0.5, 0.5, 0.5, 1.0)
        : uBlendColor;

    vec4 result = vec4(
        softLightChannel(src.r, blend.r),
        softLightChannel(src.g, blend.g),
        softLightChannel(src.b, blend.b),
        src.a
    );

    float str   = (uStrength == 0.0) ? 1.0 : uStrength;
    result.rgb  = mix(src.rgb, result.rgb, str);
    result.a    = src.a;

    gl_FragColor = result;
}
