#version 330 core

layout(location = 0) out vec4 color;

in vec2 v_TexCoord;
in vec3 v_SurfaceNormal;
in vec3 v_TangentToLightSource[MAX_LIGHTS];
in vec3 v_TangentToCamera;
in float v_Visibility;


uniform sampler2D u_Texture;

uniform bool u_HasSpecularMap;
uniform sampler2D u_SpecularMap;
uniform float u_ShineDistanceDamper;
uniform float u_Reflectivity;

uniform sampler2D u_NormalMap;

uniform float u_ParallaxMapAmplitude;
uniform sampler2D u_ParallaxMap;


uniform vec3 u_SkyColor;

uniform vec3 u_LightColor[MAX_LIGHTS];
uniform vec3 u_LightAttenuation[MAX_LIGHTS];
uniform int u_LightsUsed;

#define PI 3.1416

float CalculateDiffuse(in vec3 unitSurfaceNorm, in vec3 unitLightVec);
float CalculateSpecular(in vec3 unitSurfaceNorm, in vec3 unitLightVec, in vec3 unitVecToCamera, in vec2 mappedTexCoords);
vec2 CalculateParallaxTextureCoords();

void main(void)
{
	vec2 mappedTexCoords = clamp(CalculateParallaxTextureCoords(), 0.0, 1.0);

	vec4 texColor = texture(u_Texture, mappedTexCoords);
	if (texColor.a < 0.7)
		discard;

	vec3 unitSurfaceNorm = texture(u_NormalMap, mappedTexCoords).rgb;
	unitSurfaceNorm = normalize(unitSurfaceNorm * 2.0 - 1.0);

	vec3 unitVecToCamera = normalize(v_TangentToCamera);

	vec3 diffuse = vec3(0);
	vec3 specular = vec3(0);
	
	for (int i = 0; i < u_LightsUsed; i++)
	{
		float lightDistance = length(v_TangentToLightSource[i]);
		vec3 unitLightVec = v_TangentToLightSource[i] / lightDistance;

		float attenuation =  1.0 / (lightDistance * lightDistance * u_LightAttenuation[i].z + lightDistance * u_LightAttenuation[i].y + u_LightAttenuation[i].x);

		diffuse += CalculateDiffuse(unitSurfaceNorm, unitLightVec) * attenuation * u_LightColor[i];
		if (u_Reflectivity != 0)
			specular += CalculateSpecular(unitSurfaceNorm, unitLightVec, unitVecToCamera, mappedTexCoords) * attenuation * u_LightColor[i];
	}
	
	diffuse = max(diffuse, 0.2);

	color =	vec4(diffuse, 1) * texColor + vec4(specular, 1);
	color = mix(vec4(u_SkyColor.xyz, 1.0), color, v_Visibility);
}

vec2 CalculateParallaxTextureCoords()
{
	float height = texture(u_ParallaxMap, v_TexCoord).r;
	vec3 viewDir = normalize(v_TangentToCamera);

	const float minLayers = 8.0;
	const float maxLayers = 32.0;
	float numLayers = mix(maxLayers, minLayers, abs(dot(vec3(0.0, 0.0, 1.0), viewDir)));  
    // calculate the size of each layer
    float layerDepth = 1.0 / numLayers;
    // depth of current layer
    float currentLayerDepth = 0.0;
    // the amount to shift the texture coordinates per layer (from vector P)
    vec2 P = viewDir.xy * u_ParallaxMapAmplitude; 
    vec2 deltaTexCoords = P / numLayers;

    // get initial values
	vec2  currentTexCoords = v_TexCoord;
	float currentDepthMapValue = texture(u_ParallaxMap, currentTexCoords).r;
	  
	while(currentLayerDepth < currentDepthMapValue)
	{
	    // shift texture coordinates along direction of P
	    currentTexCoords -= deltaTexCoords;
	    // get depthmap value at current texture coordinates
	    currentDepthMapValue = texture(u_ParallaxMap, currentTexCoords).r;  
	    // get depth of next layer
	    currentLayerDepth += layerDepth;  
	}

	// get texture coordinates before collision (reverse operations)
	vec2 prevTexCoords = currentTexCoords + deltaTexCoords;

	// get depth after and before collision for linear interpolation
	float afterDepth  = currentDepthMapValue - currentLayerDepth;
	float beforeDepth = texture(u_ParallaxMap, prevTexCoords).r - currentLayerDepth + layerDepth;
	 
	// interpolation of texture coordinates
	float weight = afterDepth / (afterDepth - beforeDepth);
	vec2 finalTexCoords = prevTexCoords * weight + currentTexCoords * (1.0 - weight);

	return finalTexCoords;
}

float CalculateDiffuse(in vec3 unitSurfaceNorm, in vec3 unitLightVec)
{
	return max(dot(unitSurfaceNorm, unitLightVec), 0);
}

float CalculateSpecular(in vec3 unitSurfaceNorm, in vec3 unitLightVec, in vec3 unitVecToCamera, in vec2 mappedTexCoords)
{
	float specularDot = max(dot(reflect(-unitLightVec, unitSurfaceNorm), unitVecToCamera), 0.5);
	float actualSpecular = pow(specularDot, u_ShineDistanceDamper) * u_Reflectivity;

	//If there is specular map data, multiply the specular value by the map's red component (shininess amplitude)
	if (u_HasSpecularMap)
		actualSpecular *= texture(u_SpecularMap, mappedTexCoords).r;

	return actualSpecular;
}