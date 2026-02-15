#pragma header

// VHS/CRT Effect Shader
// Simula el efecto de una pantalla CRT vieja o cinta VHS

uniform float time;
uniform float distortion;    // Distorsión de líneas (ej: 3.0)
uniform float noiseIntensity; // Intensidad del ruido (ej: 0.1)
uniform float scanlineIntensity; // Intensidad de líneas de escaneo (ej: 0.2)

// Función de ruido
float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void main()
{
    vec2 uv = openfl_TextureCoordv;
    
    // 1. Distorsión horizontal (tape distortion)
    float distortionAmount = sin(uv.y * distortion + time * 2.0) * 0.005;
    uv.x += distortionAmount;
    
    // 2. Aberración cromática
    vec4 color;
    color.r = texture2D(bitmap, uv + vec2(0.002, 0.0)).r;
    color.g = texture2D(bitmap, uv).g;
    color.b = texture2D(bitmap, uv - vec2(0.002, 0.0)).b;
    color.a = texture2D(bitmap, uv).a;
    
    // 3. Líneas de escaneo (scanlines)
    float scanline = sin(uv.y * 800.0) * scanlineIntensity;
    color.rgb -= scanline;
    
    // 4. Ruido (noise)
    float noise = rand(uv + vec2(time, time)) * noiseIntensity;
    color.rgb += noise;
    
    // 5. Vignette (oscurecimiento en los bordes)
    vec2 center = uv - 0.5;
    float vignette = 1.0 - length(center) * 0.5;
    color.rgb *= vignette;
    
    // 6. Tracking lines (líneas horizontales que se mueven)
    float trackingLine = step(0.99, fract((uv.y + time * 0.1) * 20.0));
    color.rgb = mix(color.rgb, vec3(0.0), trackingLine * 0.5);
    
    gl_FragColor = color;
}
