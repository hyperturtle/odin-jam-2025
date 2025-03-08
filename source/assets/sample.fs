#version 330

// Input vertex attributes (from vertex shader)
in vec3 vertexPos;
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;

out vec4 finalColor;

void main()
{
    // Texel color fetching from texture sampler
    vec4 texelColor0 = texture(texture0, fragTexCoord);
    texelColor0.b = 1.0;
    finalColor = texelColor0;
}