#pragma header

// Glitch Effect Shader
// Crea un efecto de glitch/distorsión digital

uniform float time;
uniform float intensity; // Intensidad del glitch (0.0 - 1.0)

// Función de ruido pseudo-aleatorio
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void main()
{
    vec2 uv = openfl_TextureCoordv;
    
    // Crear glitch horizontal basado en líneas
    float line = floor(uv.y * 20.0);
    float glitchRandom = random(vec2(line, floor(time * 10.0)));
    
    // Aplicar desplazamiento horizontal aleatorio
    if (glitchRandom > 1.0 - intensity) {
        float offset = (random(vec2(time, line)) - 0.5) * 0.15;
        uv.x += offset;
    }
    
    vec4 color = texture2D(bitmap, uv);
    
    // Distorsión de canales de color para efecto adicional
    if (glitchRandom > 1.0 - intensity * 0.5) {
        color.r = texture2D(bitmap, uv + vec2(0.02, 0.0)).r;
        color.b = texture2D(bitmap, uv - vec2(0.02, 0.0)).b;
    }
    
    // Agregar líneas de ruido ocasionales
    if (glitchRandom > 1.0 - intensity * 0.3) {
        float noise = random(vec2(uv.x, time));
        color.rgb = mix(color.rgb, vec3(noise), 0.3);
    }
    
    gl_FragColor = color;
}
