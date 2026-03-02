#pragma header

// ─────────────────────────────────────────────────────────────────────────────
//  evilSchoolWarp.frag
//  Distorsión de onda estilo "escuela del mal" — efecto de deformación
//  sinusoidal en X e Y con ruido de baja frecuencia para sensación orgánica.
//
//  PARÁMETROS (todos opcionales, tienen valores por defecto):
//    uTime        → tiempo acumulado (actualizar cada frame desde HScript)
//    uWaveX       → amplitud de la onda horizontal  (default 0.006)
//    uWaveY       → amplitud de la onda vertical    (default 0.004)
//    uFreqX       → frecuencia de la onda en X      (default 8.0)
//    uFreqY       → frecuencia de la onda en Y      (default 6.0)
//    uSpeedX      → velocidad de la onda en X       (default 1.2)
//    uSpeedY      → velocidad de la onda en Y       (default 0.9)
//    uRipple      → intensidad del "ripple" diagonal (default 0.003)
//    uVignette    → oscurece bordes (0.0=off, 1.0=full, default 0.5)
//
//  USO desde HScript (stage o módulo):
//    ShaderManager.applyShader(mySprite, "evilSchoolWarp");
//    ShaderManager.setShaderParam("evilSchoolWarp", "uTime", [0.0]);
//    // En update:
//    ShaderManager.setShaderParam("evilSchoolWarp", "uTime", [acumulado]);
//
//  USO desde stage JSON (customProperties):
//    "shader": "evilSchoolWarp"
//    (el tiempo no se actualiza automáticamente — usar HScript para animarlo)
// ─────────────────────────────────────────────────────────────────────────────

uniform float uTime;

// Amplitud de deformación (en UV, ~0.001–0.015 es un rango razonable)
uniform float uWaveX;     // desplazamiento horizontal por onda vertical
uniform float uWaveY;     // desplazamiento vertical por onda horizontal

// Frecuencia espacial de las ondas
uniform float uFreqX;     // cuántas ondas caben verticalmente
uniform float uFreqY;     // cuántas ondas caben horizontalmente

// Velocidad de animación
uniform float uSpeedX;
uniform float uSpeedY;

// Ripple diagonal (mezcla X+Y para el efecto "líquido")
uniform float uRipple;

// Viñeta de bordes oscuros
uniform float uVignette;

// ── Fallback de defaults usando el truco OpenGL 2.0 ──────────────────────────
// En GLSL ES 1.00 no existe "default uniform value" nativamente,
// pero podemos usar un helper que devuelve el parámetro si fue seteado
// o el default si es 0.0 (ausente). Usamos abs() para que 0.0 real
// nunca colisione con los defaults.

float def(float val, float fallback) {
    // Si el valor nunca fue seteado llega como 0.0; devolvemos el fallback.
    // Para poder pasar 0.0 explícito, el caller puede pasar 0.0001.
    return (val == 0.0) ? fallback : val;
}

void main()
{
    vec2 uv = openfl_TextureCoordv;

    // Leer parámetros con fallback
    float wX    = def(uWaveX,   0.006);
    float wY    = def(uWaveY,   0.004);
    float fX    = def(uFreqX,   8.0);
    float fY    = def(uFreqY,   6.0);
    float sX    = def(uSpeedX,  1.2);
    float sY    = def(uSpeedY,  0.9);
    float rip   = def(uRipple,  0.003);
    float vig   = def(uVignette, 0.5);

    float t = uTime;

    // ── Onda principal ───────────────────────────────────────────────────────
    // Desplazamiento en X basado en la posición vertical (onda horizontal)
    float offX = sin(uv.y * fX + t * sX) * wX;
    // Desplazamiento en Y basado en la posición horizontal
    float offY = sin(uv.x * fY + t * sY) * wY;

    // ── Ripple diagonal (segunda frecuencia, ligeramente desfasada) ──────────
    float offX2 = sin(uv.y * fX * 0.5 + uv.x * 3.0 + t * sX * 0.7) * rip;
    float offY2 = sin(uv.x * fY * 0.5 + uv.y * 2.5 + t * sY * 0.8) * rip;

    // ── Efecto de "respiración" — escala suave desde el centro ───────────────
    vec2 center = vec2(0.5, 0.5);
    float breathe = sin(t * 0.4) * 0.003;
    vec2 uvWarped = uv + vec2(offX + offX2, offY + offY2);
    uvWarped = center + (uvWarped - center) * (1.0 + breathe);

    // ── Muestrear textura deformada ──────────────────────────────────────────
    // Clamp para evitar samplear fuera del sprite (devolvería negro/transparente)
    uvWarped = clamp(uvWarped, 0.0, 1.0);
    vec4 color = flixel_texture2D(bitmap, uvWarped);

    // ── Viñeta ───────────────────────────────────────────────────────────────
    if (vig > 0.0) {
        vec2 vd = uv - center;
        float vignette = 1.0 - dot(vd, vd) * vig * 2.5;
        color.rgb *= clamp(vignette, 0.0, 1.0);
    }

    gl_FragColor = color;
}