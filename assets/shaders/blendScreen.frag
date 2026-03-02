#pragma header

// ─────────────────────────────────────────────────────────────────────────────
//  blendScreen.frag  —  Photoshop-style SCREEN blend
//
//  Screen = 1 - (1-src) * (1-blend)  →  siempre aclara, opuesto a Multiply.
//
//  PARÁMETROS:
//    uBlendColor  → vec4 RGBA del color de pantalla    (default: negro → sin efecto)
//    uStrength    → intensidad [0.0–1.0]               (default: 1.0)
//
//  USO HScript:
//    ShaderManager.applyShader(mySprite, "blendScreen");
//    ShaderManager.setShaderParam("blendScreen", "uBlendColor", [0.8, 0.8, 0.0, 1.0]);
// ─────────────────────────────────────────────────────────────────────────────

uniform vec4  uBlendColor;
uniform float uStrength;

void main()
{
    vec4 src   = flixel_texture2D(bitmap, openfl_TextureCoordv);
    vec4 blend = (uBlendColor.a == 0.0) ? vec4(0.0, 0.0, 0.0, 1.0) : uBlendColor;

    // Screen: 1 - (1-a)*(1-b)
    vec4 screened = vec4(1.0) - (vec4(1.0) - src) * (vec4(1.0) - blend);

    float str  = (uStrength == 0.0) ? 1.0 : uStrength;
    vec4 result = mix(src, screened, str);

    result.a = src.a;
    gl_FragColor = result;
}
