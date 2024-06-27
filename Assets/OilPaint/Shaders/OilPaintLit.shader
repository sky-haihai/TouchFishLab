Shader "TFLab/OilPaintLit" {
    Properties {
        [MainTexture] _MainTex ("Albedo Texture", 2D) = "white" {}
        _AlphaClipThreshold("_Cutoff Threshold",Range(0,1)) = 0.5
        _NormalTex ("Normal Texture", 2D) = "bump" {}
        _NormalStrength ("Normal Strength", Range(0, 2)) = 1
        _MainLightRampTex ("Main Light Ramp Texture", 2D) = "white" {}
        _AddLightRampTex ("Additional Light Ramp Texture", 2D) = "white" {}
        _MainLightInfluence ("Main Light Influence", Range(0, 1)) = 1
        _AddLightsInfluence ("Additional Light Influence", Range(0, 5)) = 1
        [Toggle]_CastShadows ("Cast Shadows", Float) = 1
        _ShadowColor ("Shadow Color", Color) = (0.2,0.2,0.2,0)
    }
    SubShader {
        Tags {
            "RenderType"="Opaque"
            "Queue"="Geometry"
            "RenderPipeline"="UniversalRenderPipeline"
        }

        Pass {
            Name "UniversalForward"
            Tags {
                "LightMode" = "UniversalForwardOnly"
            }

            // Render State
            Cull Back
            ZWrite On

            HLSLPROGRAM
            #pragma vertex ComputeVertex
            #pragma fragment ComputeFragment

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE

            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
            #pragma multi_compile_local_fragment _ _SILHOUETTE_ON
            #pragma multi_compile_local_fragment _ _ANTIOCCLUSION_ON

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float3 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float4 uv0 : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float2 uv0 : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float4 tangentWS : TEXCOORD3;
                float4 screenPos : TEXCOORD4;
            };

            //Properties
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _MainTex_TexelSize;
                float4 _NormalTex_TexelSize;
                float4 _MainLightRampTex_TexelSize;
                float4 _AddLightRampTex_TexelSize;
                float _AlphaClipThreshold;
                float _NormalStrength;
                float _MainLightInfluence;
                float _AddLightsInfluence;
                float4 _ShadowColor;
            CBUFFER_END

            // Textures and Samplers
            SamplerState sampler_linear_clamp;
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            TEXTURE2D(_NormalTex);
            SAMPLER(sampler_NormalTex);

            TEXTURE2D(_MainLightRampTex);
            SAMPLER(sampler_MainLightRampTex);

            TEXTURE2D(_AddLightRampTex);
            SAMPLER(sampler_AddLightRampTex);

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);


            float NDotL(float3 normalWS, half3 lightDirectionWS)
            {
                return dot(normalWS, lightDirectionWS);
            }

            float3 GetRelection(float3 positionWS, float3 normalWS)
            {
                float3 viewDirectionWS = normalize(GetWorldSpaceViewDir(positionWS));
                return reflect(-viewDirectionWS, normalWS);
            }

            float3 GetNormalWS(Texture2D normalTexTS, sampler normalTexSampler, float3 normalWS, float4 tangentWS, float2 uv, float normalStrength)
            {
                float3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(normalTexTS, normalTexSampler, uv));
                normalTS = normalize(float3(normalTS.x * normalStrength, normalTS.y * normalStrength, normalTS.z));
                float3x3 tangentToWorld = CreateTangentToWorld(normalWS, tangentWS.xyz, tangentWS.w);
                float3 result = normalize(TransformTangentToWorld(normalTS, tangentToWorld));
                return result;
            }

            float GetLuminance(float3 color)
            {
                return 0.333 * color.r + 0.333 * color.g + 0.333 * color.b;
            }

            void GetAdditionalLightsInfo(float3 positionWS, float lightColorInfluence, out float shadowMask, out float3 lightColor)
            {
                float shadow = 0;
                float3 color = 0;
                for (int lightIndex = 0; lightIndex < GetAdditionalLightsCount(); lightIndex++)
                {
                    Light light = GetAdditionalLight(lightIndex, positionWS, 1.0);
                    float3 lightC = light.color * clamp(light.distanceAttenuation * lightColorInfluence, 0, 1);
                    color += lightC;

                    float lightIntensity = GetLuminance(light.color);
                    float shadowAtten = light.shadowAttenuation * light.distanceAttenuation * lightIntensity;
                    shadow += shadowAtten;
                }

                shadowMask = clamp(shadow, 0, 1);
                lightColor = color;
            }


            float4 ComputeToonSurface(float4 albedo, float4 shadowColor, float3 normalWS, float3 vertexPosWS, float mainLightInfluence, float additionalLightInfluence,
                                      Texture2D colorRampTex,
                                      sampler colorRampTexSampler, Texture2D addColorRampTex, sampler addColorRampTexSampler)
            {
                //main light color
                float4 shadowCoord = TransformWorldToShadowCoord(vertexPosWS);
                Light mainLight = GetMainLight(shadowCoord);
                float mainLightVdotL = dot(mainLight.direction, GetRelection(vertexPosWS, normalWS));
                mainLightVdotL = saturate(mainLightVdotL);
                float mainLightNdotL = NDotL(normalWS, mainLight.direction);
                // mainLightVdotL = mainLightVdotL * 0.5 + 0.5;
                // mainLightVdotL=pow(mainLightVdotL, 2);
                float mainShadowAttenuation = mainLight.shadowAttenuation * mainLightNdotL;
                mainShadowAttenuation = SAMPLE_TEXTURE2D(colorRampTex, colorRampTexSampler, float2(mainShadowAttenuation, 0)).r;
                float3 mainLightColor = mainLight.color * mainShadowAttenuation;
                mainLightColor = lerp(mainLightColor, mainLight.color * shadowColor.rgb, 1 - mainShadowAttenuation);

                //additional light color
                float3 additionalLightColor = 0;
                for (int lightIndex = 0; lightIndex < GetAdditionalLightsCount(); lightIndex++)
                {
                    Light light = GetAdditionalLight(lightIndex, vertexPosWS, 1.0);
                    float addShadowAttenuation = light.shadowAttenuation * light.distanceAttenuation * GetLuminance(light.color);
                    addShadowAttenuation = SAMPLE_TEXTURE2D(addColorRampTex, addColorRampTexSampler, float2(saturate(addShadowAttenuation), 0)).r;
                    additionalLightColor += light.color * addShadowAttenuation;
                }

                //surface color
                float3 lightColor = mainLightColor * mainLightInfluence + additionalLightColor * additionalLightInfluence + 0.03;
                float4 result = albedo * float4(lightColor, 1);

                return result;
            }


            Varyings ComputeVertex(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.uv0 = TRANSFORM_TEX(IN.uv0.xy, _MainTex);
                OUT.normalWS = normalize(TransformObjectToWorldNormal(IN.normalOS));
                VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                OUT.tangentWS = float4(normalInputs.tangentWS, IN.tangentOS.w);
                OUT.screenPos = ComputeScreenPos(OUT.positionHCS);
                return OUT;
            }

            float4 ComputeFragment(Varyings IN) : SV_Target
            {
                float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv0.xy).rgba;
                clip(color.a - _AlphaClipThreshold);
                float3 normalWS = GetNormalWS(_NormalTex, sampler_NormalTex, IN.normalWS, IN.tangentWS, IN.uv0.xy, _NormalStrength);

                float4 result = ComputeToonSurface(color, _ShadowColor, normalWS, IN.positionWS, _MainLightInfluence, _AddLightsInfluence,
                                                   _MainLightRampTex, sampler_MainLightRampTex, _AddLightRampTex, sampler_AddLightRampTex);

                // float3 viewDir = normalize(GetWorldSpaceViewDir(IN.positionWS));
                // float3 forward = mul((float3x3)unity_CameraToWorld, float3(0,0,1));
                // viewDir = normalize(viewDir - forward);
                // // return float4(forward+viewDir,1);
                // // return float4(viewDir,1);
                //
                // float2 uv = IN.uv0;
                // uv = uv * 2 - 1;
                // // result.rgb=float3(uv,1);
                //
                // float3 sphuv = normalize(float3(uv, 1));
                // float theta = atan2(viewDir.y, viewDir.x);
                // float phi = acos(viewDir.z);
                // float2 sphericalUV = float2(theta / (2.0 * PI), phi / PI);
                // return float4(sphericalUV, 0, 1);

                return result;
            }
            ENDHLSL
        }

        Pass {
            Name "DepthOnly"

            Tags {
                "LightMode"="UniversalForwardOnly"
                "Queue"="Geometry+100"
            }

            ZWrite On
            ColorMask 0
            Cull Back

            HLSLPROGRAM
            #pragma vertex ComputeVertex
            #pragma fragment ComputeFragment
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _MainTex_TexelSize;
                float4 _NormalTex_TexelSize;
                float4 _MainLightRampTex_TexelSize;
                float4 _AddLightRampTex_TexelSize;
                float _AlphaClipThreshold;
                float _NormalStrength;
                float _MainLightInfluence;
                float _AddLightsInfluence;
                float4 _ShadowColor;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            struct Attributes
            {
                float3 positionOS : POSITION;
                float4 uv0 : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv0 : TEXCOORD1;
            };

            Varyings ComputeVertex(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                // OUT.uv0 = TRANSFORM_TEX(IN.uv0.xy, _MainTex);
                OUT.uv0 = IN.uv0.xy;
                return OUT;
            }

            float4 ComputeFragment(Varyings IN) : SV_Target
            {
                float a = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv0).a;
                clip(a - _AlphaClipThreshold);
                return 0;
            }
            ENDHLSL
        }
        Pass {
            Name "ShadowCaster"
            Tags {
                "LightMode" = "ShadowCaster"
            }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Off

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local_fragment _CASTSHADOWS_ON

            // -------------------------------------
            // Universal Pipeline keywords

            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            // Shadow Casting Light geometric parameters. These variables are used when applying the shadow Normal Bias and are set by UnityEngine.Rendering.Universal.ShadowUtils.SetupShadowCasterConstantBuffer in com.unity.render-pipelines.universal/Runtime/ShadowUtils.cs
            // For Directional lights, _LightDirection is used when applying shadow Normal Bias.
            // For Spot lights and Point lights, _LightPosition is used to compute the actual light direction because it is different at each shadow caster geometry vertex.
            float3 _LightDirection;
            float3 _LightPosition;

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _MainTex_TexelSize;
                float4 _NormalTex_TexelSize;
                float4 _MainLightRampTex_TexelSize;
                float4 _AddLightRampTex_TexelSize;
                float _AlphaClipThreshold;
                float _NormalStrength;
                float _MainLightInfluence;
                float _AddLightsInfluence;
                float4 _ShadowColor;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 texcoord : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float2 uv : TEXCOORD0;
                float4 positionCS : SV_POSITION;
            };

            float4 GetShadowPositionHClip(Attributes input)
            {
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

                #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                float3 lightDirectionWS = normalize(_LightPosition - positionWS);
                #else
                float3 lightDirectionWS = _LightDirection;
                #endif

                float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));

                #if UNITY_REVERSED_Z
                positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #else
                positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #endif

                return positionCS;
            }

            Varyings ShadowPassVertex(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);

                output.uv = input.texcoord;
                output.positionCS = GetShadowPositionHClip(input);
                return output;
            }

            half4 ShadowPassFragment(Varyings input) : SV_TARGET
            {
                #ifndef _CASTSHADOWS_ON
                discard;
                #endif
                float a = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv).a;
                clip(a - _AlphaClipThreshold);
                return 0;
            }
            ENDHLSL
        }
    }
}