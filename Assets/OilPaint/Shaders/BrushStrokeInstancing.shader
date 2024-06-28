Shader "OilPaint/BrushStrokeInstancing" {
    Properties {
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _NormalTex ("Normal (RGB)", 2D) = "white" {}
        _YCount ("Row Count", Float) = 1
        _XCount ("Column Count", Float) = 1
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
                UNITY_DEFINE_INSTANCED_PROP(float, _RotationRandomness)
                UNITY_DEFINE_INSTANCED_PROP(float, _Scale)
                UNITY_DEFINE_INSTANCED_PROP(float3, _BaseMeshScale)
                UNITY_DEFINE_INSTANCED_PROP(float, _HeightOffset)
                UNITY_DEFINE_INSTANCED_PROP(float, _AlphaCutoff)
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

            TEXTURE2D(_NormalTex);
            SAMPLER(sampler_NormalTex);

            float _XCount;
            float _YCount;

            StructuredBuffer<float3> _PositionBuffer;
            StructuredBuffer<float3> _NormalBuffer;
            StructuredBuffer<float4> _TangentBuffer;

            float Random01(float seed)
            {
                seed = frac(sin(seed) * 43758.5453);
                return seed;
            }


            Varyings Vertex(Attributes IN, uint instanceID : SV_InstanceID)
            {
                float3 strokePosOS = _PositionBuffer[instanceID].xyz;
                float3 meshPosWS = TransformObjectToWorld(0);

                float3 strokeNormal = _NormalBuffer[instanceID].xyz;
                float3 strokeTangent = _TangentBuffer[instanceID].xyz;
                float3 vertexOffset = IN.vertex.xyz * float3(1.5, 1, 1);
                float3 binormal = -cross(strokeNormal, strokeTangent);
                binormal += (Random01(instanceID) * 2 - 1) * _RotationRandomness * strokeTangent;
                binormal = normalize(binormal);
                strokeTangent = cross(strokeNormal, binormal);

                float3 x = strokeTangent * vertexOffset.x;
                float3 y = strokeNormal * vertexOffset.y;
                float3 z = binormal * vertexOffset.z;
                vertexOffset = x + y + z + Random01(instanceID) * _HeightOffset * strokeNormal;

                Varyings o;
                o.positionHCS = TransformWorldToHClip(meshPosWS + strokePosOS * _BaseMeshScale + vertexOffset * _Scale);

                float uvX = IN.uv.x / _XCount + clamp(floor(Random01(instanceID) * _XCount), 0, _XCount - 1) / _XCount;
                float uvY = IN.uv.y / _YCount + clamp(floor(Random01(instanceID) * _YCount), 0, _YCount - 1) / _YCount;
                o.uv = float2(uvX, uvY);

                o.normalWS = normalize(TransformObjectToWorldNormal(strokeNormal));
                return o;
            }

            float4 Fragment(Varyings IN) : SV_Target
            {
                float4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
                float4 normal = SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, IN.uv);
                clip(albedo.r - _AlphaCutoff);
                Light mainLight = GetMainLight();
                float ndotl = dot(IN.normalWS, mainLight.direction);
                albedo.rgb = lerp(float3(1,1,1), float3(0.3, 0.3, 0.3), 1 - ndotl);

                float4 output = albedo;

                return output;
            }
            ENDHLSL
        }
    }
}