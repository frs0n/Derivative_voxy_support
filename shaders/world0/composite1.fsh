#version 450 compatibility


#define IS_OVERWORLD

#include "/lib/Head/Common.inc"

layout(location = 0) out vec3 sceneData;

#ifdef BLOOMY_FOG
	layout(location = 1) out float fogTransmittance;
	/* DRAWBUFFERS:46 */
#else
	/* DRAWBUFFERS:4 */
#endif


in vec2 screenCoord;

flat in vec3 directIlluminance;
flat in vec3 skyIlluminance;

#include "/lib/Head/Uniforms.inc"
#include "/lib/Atmosphere/Atmosphere.glsl"

//----// STRUCTS //-------------------------------------------------------------------------------//

#include "/lib/Head/Mask.inc"
#include "/lib/Head/Material.inc"

//----// FUNCTIONS //-----------------------------------------------------------------------------//

#include "/lib/Head/Functions.inc"

#include "/lib/Surface/Refraction.glsl"

#include "/lib/Surface/ReflectionFilter.glsl"

#ifndef RAYTRACED_REFRACTION
	#include "/lib/Surface/ScreenSpaceReflections.glsl"
#endif

#include "/lib/Atmosphere/Fogs.glsl"

#include "/lib/Water/WaterFog.glsl"

#if defined VOXY && defined DISTANT_HORIZONS
vec4 VoxyWaterReflectionDH(in vec3 normal, in float skylight, in vec3 viewPos, in float depth) {
	const uint voxyRaytraceSamples = 16u;
	skylight = smoothstep(0.3, 0.8, skylight);
	vec3 viewDir = normalize(viewPos);

	vec3 rayDir = reflect(viewDir, normal);

	float NdotL = dot(normal, rayDir);
	if (NdotL < 1e-6) return vec4(0.0);

	float dither = InterleavedGradientNoiseTemporal(gl_FragCoord.xy);
	// Use the reconstructed DH depth for this pixel.
	// gl_FragCoord.z in composite pass is not the water surface depth and causes
	// unstable SSR hit results that change with camera rotation.
	vec3 screenPos = vec3(gl_FragCoord.xy * screenPixelSize, depth);

	float NdotV = max(1e-6, dot(normal, -viewDir));
	#ifdef RAYTRACED_REFRACTION
		bool hit = false;
	#else
		bool hit = ScreenSpaceRayTraceDH(viewPos, rayDir, dither, voxyRaytraceSamples, screenPos);
	#endif

	vec3 reflection = vec3(0.0);
	if (hit) {
		reflection = texelFetch(colortex4, ivec2(screenPos.xy), 0).rgb;
	} else if (skylight > 1e-3) {
		if (isEyeInWater == 0) {
			vec3 rayDirWorld = mat3(gbufferModelViewInverse) * rayDir;
			float NdotU = saturate((dot(normal, gbufferModelView[1].xyz) + 0.7) * 2.0) * 0.75 + 0.25;
			vec4 skyboxData = textureBicubic(colortex5, ProjectSky(rayDirWorld) + vec2(0.0, skyCaptureRes.y * screenPixelSize.y));
			reflection = skyboxData.rgb * skylight * NdotU;
		} else {
			reflection = vec3(0.05, 0.7, 1.0) * 0.25 * (timeNoon + timeMidnight * NIGHT_BRIGHTNESS);
		}
	}

	float specular;
	if (isEyeInWater == 1) {
		specular = FresnelDielectricN(NdotV, 1.0 / WATER_REFRACT_IOR);
	} else {
		specular = FresnelDielectricN(NdotV, WATER_REFRACT_IOR);
	}

	return clamp16F(vec4(reflection * specular, 1.0 - specular));
}
#endif


//----// MAIN //----------------------------------------------------------------------------------//
void main() {
	ivec2 texel 		= ivec2(gl_FragCoord.xy);

	vec4 gbuffer3 		= texelFetch(colortex3, texel, 0);
	vec4 albedoT 		= vec4(UnpackUnorm2x8(gbuffer3.z), UnpackUnorm2x8(gbuffer3.w));

	vec3 normal 		= DecodeNormal(gbuffer3.xy);

	int materialIDT 	= int(texelFetch(colortex7, texel, 0).z * 255.0);
	TranslucentMask materialMaskT = CalculateMasksT(materialIDT);

	float depthSoild 	= GetDepthSoild(texel);
	// depthSoild += 0.38 * step(depthSoild, 0.56);
	float depth 		= GetDepthFix(texel);

	vec3 viewPos 		= ScreenToViewSpace(vec3(screenCoord, depth));

	#if defined DISTANT_HORIZONS
		bool dhRange = depth >= 1.0;
		if (dhRange) {
			depth = GetDepthDH(texel);
			depthSoild = GetDepthSoildDH(texel);
			viewPos = ScreenToViewSpaceDH(vec3(screenCoord, depth));
		}
	#endif

	vec3 viewDir 		= normalize(viewPos);
	vec3 worldPos 		= mat3(gbufferModelViewInverse) * viewPos;
	vec3 worldDir 		= normalize(worldPos);
	worldPos 			+= gbufferModelViewInverse[3].xyz;

	#if defined VOXY && defined DISTANT_HORIZONS
		if (dhRange && materialMaskT.water) {
			vec3 minecraftPos = worldPos + cameraPosition;
			vec3 waveNormal = GetWavesNormal(minecraftPos.xz - minecraftPos.y);
			mat3 tbnMatrix = mat3(
				normalize(gbufferModelView[0].xyz),
				normalize(gbufferModelView[2].xyz),
				normalize(mat3(gbufferModelView) * vec3(0.0, 1.0, 0.0))
			);
			normal = normalize(tbnMatrix * waveNormal);
		}
	#endif

	if (depth < 1.0) {
		#ifdef RAYTRACED_REFRACTION
			#ifdef REFRACTIVE_DISPERSION
				vec2 refractCoord  	= CalculateRefractCoord(materialMaskT, normal, viewDir, viewPos, depth, 1.5);
				vec2 refractCoordR  = CalculateRefractCoord(materialMaskT, normal, viewDir, viewPos, depth, 1.45);
				vec2 refractCoordB  = CalculateRefractCoord(materialMaskT, normal, viewDir, viewPos, depth, 1.55);
				ivec2 refractTexel 	= ivec2(refractCoord * screenSize);
				ivec2 refractTexelR = ivec2(refractCoordR * screenSize);
				ivec2 refractTexelB = ivec2(refractCoordB * screenSize);

				sceneData.g 		= texelFetch(colortex4, refractTexel, 0).g;
				sceneData.r 		= texelFetch(colortex4, refractTexelR, 0).r;
				sceneData.b 		= texelFetch(colortex4, refractTexelB, 0).b;
			#else
				vec2 refractCoord  	= CalculateRefractCoord(materialMaskT, normal, viewDir, viewPos, depth, 1.5);
				ivec2 refractTexel 	= ivec2(refractCoord * screenSize);

				sceneData 			= texelFetch(colortex4, refractTexel, 0).rgb;
			#endif
		#else
			#if defined DISTANT_HORIZONS
				vec2 refractCoord;
				if (dhRange) refractCoord = CalculateRefractCoordDH(materialMaskT, normal, worldPos, viewPos, depthSoild, depth);
				else refractCoord = CalculateRefractCoord(materialMaskT, normal, worldPos, viewPos, depthSoild, depth);
			#else
				vec2 refractCoord = CalculateRefractCoord(materialMaskT, normal, worldPos, viewPos, depthSoild, depth);
			#endif

			ivec2 refractTexel 	= ivec2(refractCoord * screenSize);

			sceneData 			= texelFetch(colortex4, refractTexel, 0).rgb;
		#endif

		vec3 albedoRaw 		= texelFetch(colortex6, refractTexel, 0).rgb;
		vec3 albedo 		= SRGBtoLinear(albedoRaw);

		Material material 	= GetMaterialData(texelFetch(colortex0, refractTexel, 0).xy);

		if (materialMaskT.stainedGlass) TransparentAbsorption(sceneData, albedoT);
		if (materialMaskT.ice) sceneData *= sqr(albedoT.rgb);

		if (materialMaskT.translucent) {
			vec4 reflectionData = texelFetch(colortex2, texel, 0);

			#if defined VOXY && defined DISTANT_HORIZONS
				if (dhRange && materialMaskT.water) {
					reflectionData = VoxyWaterReflectionDH(normal, cube(texelFetch(colortex7, texel, 0).y), viewPos, depth);
				}
			#endif

			sceneData = sceneData * reflectionData.a + reflectionData.rgb;
		} else if (material.hasReflections) {
			vec4 reflectionData = texelFetch(colortex2, texel, 0);
			#ifdef REFLECTION_FILTER
				if (material.isRough) reflectionData.rgb = ReflectionFilter(texel, reflectionData, material.roughness, normal, viewDir, 1.0, RandNext2F() - 0.5).rgb;
			#endif
			sceneData += reflectionData.rgb * mix(vec3(1.0), albedo, material.isMetal);
		}
	} else {
		sceneData = texelFetch(colortex4, texel, 0).rgb;
	}

	// float fogDist = depthT >= 1.0 ? far : length(viewPos);
	float fogDist = length(viewPos);
	//float fogDist = length(ScreenToViewSpace(vec3(refractCoord, GetDepthFix(refractTexel))));

	if (isEyeInWater == 1) UnderwaterFog(sceneData, materialMaskT, fogDist);
	if (isEyeInWater == 0 && depth < 1.0) {
		#if defined DISTANT_HORIZONS
			#define far float(dhRenderDistance)
		#endif

		#ifdef LAND_ATMOSPHERIC_SCATTERING
			// https://github.com/zombye/spectrum
			const float airNumberDensity       = 2.5035422e25; // m^3
			const float ozoneConcentrationPeak = 4e-6; // unitless
			const float ozoneNumberDensity     = airNumberDensity * exp(-35e3 / 8e3) * (134.628 / 48.0) * ozoneConcentrationPeak; // m^3 | airNumberDensity ASL * approximate relative density at altitude of peak ozone concentration * peak ozone concentration
			const vec3  ozoneCrossSection      = vec3(4.51103766177301E-21, 3.2854797958699E-21, 1.96774621921165E-22) * 0.0001; // mul by 0.0001 to convert from cm^2 to m^2 | single-wavelength values.

			const vec3  rayleighColor = vec3(6.433377384678407e+24, 1.0873673940138444e+25, 2.4861429602679963e+25);
			const float rayleighK     = 9.993284137187039e-31; // Set for an earth-like atmosphere.

			// m^3 coefficients
			const vec3 atmosphere_coefficientRayleigh = rayleighK * rayleighColor;
			const vec3 atmosphere_coefficientOzone    = ozoneCrossSection * ozoneNumberDensity;
			const vec3 atmosphere_coefficientMie      = vec3(4e-6); // Should usually be >= 2e-6, depends heavily on conditions. Current value is just one that looks good.

			const vec3 baseAttenuationCoefficient = atmosphere_coefficientRayleigh + atmosphere_coefficientMie + atmosphere_coefficientOzone;
			const mat2x3 atmosphere_coefficientsScattering = mat2x3(atmosphere_coefficientRayleigh, atmosphere_coefficientMie * 0.9);

			float dist = fogDist * eyeSkylightFix * 20.0;

			vec3 opticalDepth = baseAttenuationCoefficient * dist;

			vec3 transmittance   = exp(-opticalDepth);
			vec3 visibleFraction = min(oneMinus(transmittance) / opticalDepth, 1.0);

			float LdotV = dot(worldLightVector, worldDir);

			vec3 scattering = atmosphere_coefficientsScattering * vec2(RayleighPhase(LdotV), HenyeyGreensteinPhase(LdotV, mie_phase_g)) * directIlluminance;
			scattering += atmosphere_coefficientsScattering * vec2(0.25 * rPI) * skyIlluminance;
			scattering *= dist * visibleFraction;

			sceneData = sceneData * transmittance + scattering * 20.0 * oneMinus(wetness * 0.6);
		#elif !defined BORDER_FOG
			float density = eyeSkylightFix * 0.4 * (1.0 + wetness);
			float transmittance = fastExp(-fogDist / far * density);

			sceneData *= transmittance;
			sceneData += skyIlluminance * oneMinus(wetness * 0.8) * oneMinus(transmittance);
		#endif

		#ifdef BORDER_FOG
			float density = 1.0 - exp2(-sqr(pow4(length(worldPos.xz) * eyeSkylightFix / far)) * BORDER_FOG_FALLOFF);

			density *= oneMinus(saturate(worldDir.y * 3.0));

			vec3 skyRadiance = textureBicubic(colortex5, ProjectSky(worldDir)).rgb;
			sceneData = mix(sceneData, skyRadiance, density);
		#endif
	}

	#if defined VOLUMETRIC_FOG || defined VOLUMETRIC_LIGHT || defined UW_VOLUMETRIC_LIGHT
		#if defined DISTANT_HORIZONS
			vec4 VFData;
			if (dhRange) VFData = SpatialUpscaleDH(colortex1, gl_FragCoord.xy, GetDepthLinearDH(depth));
			else VFData = SpatialUpscale(colortex1, gl_FragCoord.xy, GetDepthLinear(depth));
		#else
			vec4 VFData = SpatialUpscale(colortex1, gl_FragCoord.xy, GetDepthLinear(depth));
		#endif

		sceneData *= VFData.a;
		sceneData += VFData.rgb;

		#ifdef BLOOMY_FOG
			fogTransmittance = VFData.a;
			#if FOG_TYPE == 3
				fogTransmittance = fogTransmittance * 0.3 + 0.7;
			#endif
		#endif
	#elif defined BLOOMY_FOG
		fogTransmittance = 1.0;
	#endif

	CommonFog(sceneData, fogDist);

	#ifdef BLOOMY_FOG
		float fogDensity = wetness * eyeSkylightFix * 2e-3;

		if (isEyeInWater == 1) fogDensity = 0.06 * WATER_FOG_DENSITY;
		if (isEyeInWater > 1) fogDensity = 1.0;

		fogTransmittance = min(fastExp(-fogDensity * fogDist), fogTransmittance);
	#endif

	#if DEBUG_NORMAL == 0
		sceneData = clamp16F(sceneData);
	#elif DEBUG_NORMAL == 1
		sceneData = normal;
	#else
		sceneData = mat3(gbufferModelViewInverse) * normal;
	#endif
}
