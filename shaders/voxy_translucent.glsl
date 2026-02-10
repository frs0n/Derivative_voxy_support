#include "/lib/Head/Common.inc"

layout(location = 0) out vec3 colortex7Out;
layout(location = 1) out vec4 reflectionData;
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
    vec4 albedo = parameters.sampledColour * parameters.tinting;
    vec3 normal = voxy_face_normal(parameters.face);

    uint materialIDs = max(parameters.customId - 10000u, 0u);
    materialIDs = max(materialIDs, 16u);

    colortex7Out.xy = parameters.lightMap;
    colortex7Out.xy = clamp(
        colortex7Out.xy + (voxy_dither() - 0.5) * rcp(255.0),
        vec2(0.0),
        vec2(1.0)
    );
    colortex7Out.z = (float(materialIDs) + 0.1) * rcp(255.0);

    colortex3Out.xy = EncodeNormal(normal);
    colortex3Out.z = PackUnorm2x8(albedo.rg);
    colortex3Out.w = PackUnorm2x8(albedo.ba);

    reflectionData = vec4(0.0, 0.0, 0.0, 1.0);
}
