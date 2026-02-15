#pragma header

// Pixelate Effect Shader
// Crea un efecto de pixelado/mosaic

uniform float pixelSize; // Tamaño del pixel (ej: 4.0 para 4x4 pixels)

void main()
{
    vec2 uv = openfl_TextureCoordv;
    
    // Obtener resolución de la textura
    vec2 texSize = vec2(textureSize(bitmap, 0));
    
    // Calcular tamaño del pixel en UV space
    vec2 pixelUVSize = vec2(pixelSize) / texSize;
    
    // Redondear las coordenadas UV al pixel más cercano
    vec2 pixelatedUV = floor(uv / pixelUVSize) * pixelUVSize;
    
    // Muestrear con las coordenadas pixeladas
    vec4 color = texture2D(bitmap, pixelatedUV);
    
    gl_FragColor = color;
}
