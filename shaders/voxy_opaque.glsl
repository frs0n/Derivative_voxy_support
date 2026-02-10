#include "/lib/Head/Common.inc"

layout(location = 0) out vec3 albedoData;
layout(location = 1) out vec4 colortex7Out;
layout(location = 2) out vec4 colortex3Out;

vec3 voxy_face_normal(uint face) {
    return vec3(
               uint((face >> 1) == 2),
               uint((face >> 1) == 0),
               uint((face >> 1) == 1)
           ) *
        (float(int(face) & 1) * 2.0 - 1.0);
}

float voxy_dither() {
    return fract(
        52.9829189 *
        fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y)
    );
}

void voxy_emitFragment(VoxyFragmentParameters parameters) {
    vec3 albedo = parameters.sampledColour.rgb * parameters.tinting.rgb;
    vec3 normal = voxy_face_normal(parameters.face);
    normal = normalize(mat3(gbufferModelView) * normal);

    uint materialIDs = parameters.customId;
    if (materialIDs >= 10000u) {
        materialIDs -= 10000u;
    }
    materialIDs = min(materialIDs, 255u);

    if (materialIDs > 0u) {
        materialIDs = max(materialIDs, 6u);
    }

    vec4 specularData = vec4(0.0);

#if TEXTURE_FORMAT == 0
    if (materialIDs == 6u) specularData.b = 0.45;
    if (materialIDs == 7u || materialIDs == 10u) specularData.b = 0.7;
#elif SUBSERFACE_SCATTERING_MODE < 2
    if (materialIDs == 6u) specularData.a = 0.45;
    if (materialIDs == 7u || materialIDs == 10u) specularData.a = 0.7;
#endif

#ifdef WHITE_WORLD
    albedo = vec3(1.0);
#endif

    albedoData = albedo;

    colortex7Out.xy = parameters.lightMap;
    colortex7Out.xy = clamp(
        colortex7Out.xy + (voxy_dither() - 0.5) * rcp(255.0),
        vec2(0.0),
        vec2(1.0)
    );
    colortex7Out.z = (float(materialIDs) + 0.1) * rcp(255.0);
    colortex7Out.w = 0.0;

    colortex3Out.xy = EncodeNormal(normal);
    colortex3Out.z = PackUnorm2x8(specularData.rg);
    colortex3Out.w = PackUnorm2x8(specularData.ba);
}
