Shader "OilPaint/BrushStrokeInstancing" {
    Properties {
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
    }
    SubShader {
        Cull Off
        Zwrite On

        Tags {
            "RenderType"="Opaque"
            "Queue"="Geometry"
            "RenderPipeline"="UniversalRenderPipeline"
        }

        Pass {
            Name "BillboardForward"

            Tags {
                "LightMode" = "UniversalForward"
            }

            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex Vertex
            #pragma fragment Fragment
            #pragma target 4.5
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            UNITY_INSTANCING_BUFFER_START(Props)
                UNITY_DEFINE_INSTANCED_PROP(float, _Scale)
            UNITY_INSTANCING_BUFFER_END(Props)

            struct Attributes
            {
                float4 vertex : POSITION;
                float4 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS: TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            StructuredBuffer<float3> _PositionBuffer;
            StructuredBuffer<float3> _NormalBuffer;
            StructuredBuffer<float4> _TangentBuffer;

            float random(float2 p)
            {
                float2 K1 = float2(
                    23.14069263277926, // e^pi (Gelfond's constant)
                    2.665144142690225 // 2^sqrt(2) (Gelfondâ€“Schneider constant)
                );
                return frac(cos(dot(p, K1)) * 12345.6789);
            }

            Varyings Vertex(Attributes IN, uint instanceID : SV_InstanceID)
            {
                float3 meshPosWS = TransformObjectToWorld(float3(0, 0, 0));
                float3 strokePosOS = _PositionBuffer[instanceID].xyz;
                float3 strokeNormal = _NormalBuffer[instanceID].xyz;
                float3 strokeTangent = _TangentBuffer[instanceID].xyz;
                float3 vertexOffset = IN.vertex.xyz * float3(2, 1, 1);
                float3 binormal = -cross(strokeNormal, strokeTangent);
                binormal += (random(float2(strokeNormal.z, instanceID)) * 2 - 1) * 0.2 * strokeTangent;
                binormal = normalize(binormal);
                strokeTangent = cross(strokeNormal, binormal);

                float3 x = strokeTangent * vertexOffset.x;
                float3 y = strokeNormal * vertexOffset.y;
                float3 z = binormal * vertexOffset.z;
                vertexOffset = x + y + z + +random(float2(instanceID, vertexOffset.x)) * 0.1 * strokeNormal;

                Varyings o;
                o.positionHCS = TransformWorldToHClip(meshPosWS + strokePosOS + vertexOffset * _Scale);
                o.uv = IN.uv.xy;
                o.normalWS = normalize(TransformObjectToWorldNormal(strokeNormal));;
                return o;
            }

            float4 Fragment(Varyings IN) : SV_Target
            {
                float4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
                clip(albedo.r - 0.1);
                Light mainLight = GetMainLight();
                float ndotl = dot(IN.normalWS, mainLight.direction);
                // ndotl = ndotl * 0.5 + 0.5;
                albedo.rgb = lerp(float3(1, 1, 1), float3(0.3, 0.3, 0.3), 1 - ndotl);

                float4 output = albedo;

                return output;
            }
            ENDHLSL
        }
    }
}