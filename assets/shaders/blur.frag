#pragma header

// Blur Effect Shader
// Aplica un desenfoque gaussiano simple al sprite

uniform float blurSize; // Tamaño del blur (ej: 0.002)
uniform float intensity; // Intensidad del blur (0.0 - 1.0)

void main()
{
    vec2 uv = openfl_TextureCoordv;
    vec4 sum = vec4(0.0);
    
    // Blur de 9 muestras (3x3 kernel)
    sum += texture2D(bitmap, uv + vec2(-blurSize, -blurSize)) * 0.05;
    sum += texture2D(bitmap, uv + vec2(0.0, -blurSize)) * 0.09;
    sum += texture2D(bitmap, uv + vec2(blurSize, -blurSize)) * 0.05;
    
    sum += texture2D(bitmap, uv + vec2(-blurSize, 0.0)) * 0.09;
    sum += texture2D(bitmap, uv) * 0.44;
    sum += texture2D(bitmap, uv + vec2(blurSize, 0.0)) * 0.09;
    
    sum += texture2D(bitmap, uv + vec2(-blurSize, blurSize)) * 0.05;
    sum += texture2D(bitmap, uv + vec2(0.0, blurSize)) * 0.09;
    sum += texture2D(bitmap, uv + vec2(blurSize, blurSize)) * 0.05;
    
    // Mezclar con la imagen original según la intensidad
    vec4 original = texture2D(bitmap, uv);
    gl_FragColor = mix(original, sum, intensity);
}
