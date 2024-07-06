Shader "URP/Toon/Hair/S_Hair01"
{
    Properties
    {
    	// ------------------------------------- Base
        [Header(Base)][Space(6)]
        _BaseMap ("Hair Map", 2D) = "white" {}
        _BaseCol ("Hair Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _Hue ("Hue", Range(0.0, 1.0)) = 0.0
       // ------------------------------------- Specular
       [Header(Specular)][Space(6)]
    	_SpecCol ("Specular Color", Color) = (1.0, 1.0, 1.0, 1.0)
    	_SpecInt ("Specular Intensity (Parent)", Range(0.0, 1.0)) = 1.0
    	_SpecInt1 ("Specular Intensity1 (Main)", Range(0.0, 1.0)) = 0.7
    	_SpecInt2 ("Specular Intensity2 (Second)", Range(0.0, 1.0)) = 1.0
    	_Gloss1 ("Gloss 1 (Main)", Range(0.0, 1.0)) = 0.5
    	_Gloss2 ("Gloss 2 (Second)", Range(0.0, 1.0)) = 1.0
        _Shift1 ("Shift Intensity1", Float) = 0.8
        _Shift2 ("Shift Intensity2", Float) = 1.5
        [Space(6)]
        _ShiftMap ("Shift Noise Map", 2D) = "white" {}
        [Toggle] _UseCustomNoise ("Custom Noise: If not use, click 'ON'; If use, click 'OFF'", Float) = 1.0
        _NoiseHighFreq ("Noise High Freq", Float) = 800.0
        _NoiseLowFreq ("Noise Low Freq", Float) = 100.0
        _NoiseHighAmp ("Noise High Amp", Float) = 0.1
        _NoiseLowAmp ("Noise Low Amp", Float) = 0.3
        // ------------------------------------- Normal
    	[Header(Normal)][Space(6)]
        _BumpScale("Normal Scale", Float) = 1.0
        [NoScaleOffset] _BumpMap("Normal Map", 2D) = "bump" {}
        // ------------------------------------- Gradient
        [Header(Gradient)][Space(6)]
    	[Toggle] _EnableGradient ("Gradient: If use Gradient, click 'ON'; If not use, click 'OFF'Gradient", Float) = 1.0
    	_GradientInt ("Gradient Intensity", Range(0.0, 1.0)) = 1.0
    	_TopColor ("Top Color", Color) = (1.0, 0.7, 0.7, 1.0)
        _DownColor ("Down Color", Color) = (1.0, 0.5, 0.7, 1.0)
        // ------------------------------------- Rim 	
    	[Header(Rim)][Space(6)]
    	_RimColor ("Rim Color", Color) = (1.0, 0.6, 0.7, 1.0)
        _RimPower ("Rim Power", Float) = 4.0        
        // ------------------------------------- Other
        [Header(Other)][Space(6)]
    	_Cutoff  ("Alpha Cutoff",  Range(0.0, 1.0)) = 0.5
    	[Toggle] _EnableShadow ("Receive Shadow: If Receive Shadow, click 'ON'; If not use, click 'OFF'", Float) = 1.0
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode ("Cull Mode", Float) = 2
    }
    // ------------------------------------- SubShader
    SubShader
    {
    // ------------------------------------- Tags         
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "TransparentCutout"
            "Queue" = "AlphaTest"
        }
    // ------------------------------------- Includes
    HLSLINCLUDE        
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    ENDHLSL
// ------------------------------------- Forward Pass
        Pass
        {
            Name "FORWARD"
            Tags { "LightMode" = "UniversalForward" } 
            // ------------------------------------- Render State Commands
            Cull [_CullMode]
            Blend Off
            // ------------------------------------- HLSLPROGRAM
    HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 2.0
            // ------------------------------------- Material Keywords
            #pragma shader_feature _USECUSTOMNOISE_ON
			#pragma shader_feature _ENABLEGRADIENT_ON
			#pragma shader_feature _ENABLESHADOW_ON
            // -------------------------------------  Universal Pipeline keywords
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
	        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
	        #pragma multi_compile _ _SHADOWS_SOFT
            // ------------------------------------- Unity defined keywords
            #pragma multi_compile_fog
            //-------------------------------------- GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            // ------------------------------------- Properties Stages
            CBUFFER_START(UnityPerMaterial)
            //Base
			uniform float _Hue;
			uniform float4 _BaseCol;
			uniform float4 _BaseMap_ST;
			//Specular
			uniform half4 _SpecCol;
			uniform float _SpecInt;
			uniform float _SpecInt1;
			uniform float _SpecInt2;
			uniform float _Gloss1;
			uniform float _Gloss2;
			uniform float _Shift1;
			uniform float _Shift2;
			uniform float4 _ShiftMap_ST;
			uniform float _NoiseHighFreq;
			uniform float _NoiseLowFreq;
			uniform float _NoiseHighAmp;
			uniform float _NoiseLowAmp;
			//Normal
			uniform float _BumpScale;
            //Gradient
			uniform float _GradientInt;
			uniform half4 _TopColor;
			uniform half4 _DownColor;
			//Rim
			uniform half4 _RimColor;
			uniform float _RimPower;
			//Other
			uniform float _Cutoff;
            CBUFFER_END
            TEXTURE2D(_BaseMap);	SAMPLER(sampler_BaseMap);
			TEXTURE2D(_ShiftMap);	SAMPLER(sampler_ShiftMap);
			TEXTURE2D(_BumpMap);	SAMPLER(sampler_BumpMap);
    // ------------------------------------- Attributes
            struct Attributes
            {
                float4 positionOS : POSITION;
            	float3 normalOS : NORMAL;
            	float4 tangentOS : TANGENT;
            	float2 texcoord   : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
    // ------------------------------------- Varyings
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
            	float3 normalWS : TEXCOORD1;
            	float4 tangentWS : TEXCOORD2;
            	float fogFactor: TEXCOORD3;
            	float4 uv : TEXCOORD4;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };
    // ------------------------------------- Pre Noise
            // ------------------------------------- GenerateRandomNoise
			float GenerateRandomNoise(float2 uv)
			{
			    return frac(sin(dot(uv, float2(12.9898, 78.233)))*43758.5453); //噪声生成算法公式
			}
            // ------------------------------------- ValueNoise
			float InterpolateForNoise (float a, float b, float t)
			{
			    return (1.0-t)*a + (t*b); //SimpleNoise 插值公式
			}
			float ValueNoise(float2 uv) //SimpleNoise 计算公式
			{
			    float2 i = floor(uv);
			    float2 f = frac(uv);

			    uv = abs(frac(uv) - 0.5);
			    float2 c0 = i + float2(0.0, 0.0);
			    float2 c1 = i + float2(1.0, 0.0);
			    float2 c2 = i + float2(0.0, 1.0);
			    float2 c3 = i + float2(1.0, 1.0);
			    float r0 = GenerateRandomNoise(c0);
			    float r1 = GenerateRandomNoise(c1);
			    float r2 = GenerateRandomNoise(c2);
			    float r3 = GenerateRandomNoise(c3);
				
				f = f * f * (3.0 - 2.0 * f);

			    float topmix = InterpolateForNoise(r0, r1, f.x);
			    float botmix = InterpolateForNoise(r2, r3, f.x);
			    float wholemix = InterpolateForNoise(topmix , botmix , f.y);
				
			    return wholemix;
			}
            // ------------------------------------- SimpleNoise
			float SimpleNoise(float2 UV, float Scale)
			{
			    float t = 0.0;

			    float freq = pow(2.0, float(0));
			    float amp = pow(0.5, float(3-0));
			    t += ValueNoise(float2(UV.x*Scale/freq, UV.y*Scale/freq))*amp;

			    freq = pow(2.0, float(1));
			    amp = pow(0.5, float(3-1));
			    t += ValueNoise(float2(UV.x*Scale/freq, UV.y*Scale/freq))*amp;

			    freq = pow(2.0, float(2));
			    amp = pow(0.5, float(3-2));
			    t += ValueNoise(float2(UV.x*Scale/freq, UV.y*Scale/freq))*amp;
			    
			    return t;
			}
            // ------------------------------------- Hue
			float3 Unity_Hue_Radians_float(float3 In, float Offset)
			{
			    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
			    float4 P = lerp(float4(In.bg, K.wz), float4(In.gb, K.xy), step(In.b, In.g));
			    float4 Q = lerp(float4(P.xyw, In.r), float4(In.r, P.yzx), step(P.x, In.r));
			    float D = Q.x - min(Q.w, Q.y);
			    float E = 1e-10;
			    float3 hsv = float3(abs(Q.z + (Q.w - Q.y)/(6.0 * D + E)), D / (Q.x + E), Q.x);

			    float hue = hsv.x + Offset;
			    hsv.x = (hue < 0)
			            ? hue + 1
			            : (hue > 1)
			                ? hue - 1
			                : hue;

			    // HSV to RGB
			    float4 K2 = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
			    float3 P2 = abs(frac(hsv.xxx + K2.xyz) * 6.0 - K2.www);
				
			    return hsv.z * lerp(K2.xxx, saturate(P2 - K2.xxx), hsv.y);
			}
    // ------------------------------------- Vertex Shader
            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;
				
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
				// ------------------------------------- VertexPosition
                VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = positionInputs.positionCS;
                output.positionWS = positionInputs.positionWS;
            	// ------------------------------------- VertexNormal
            	VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                output.normalWS = normalInputs.normalWS;
                output.tangentWS = half4(normalInputs.tangentWS.xyz, input.tangentOS.w * GetOddNegativeScale());
            	// ------------------------------------- Fog
            	output.fogFactor = ComputeFogFactor(input.positionOS.z);
            	// ------------------------------------- UV
                output.uv.xy = TRANSFORM_TEX(input.texcoord, _BaseMap);
				#if _USECUSTOMNOISE_ON //If Not Use,
					output.uv.zw = input.texcoord;
				#else
				    output.uv.zw = TRANSFORM_TEX(input.texcoord, _ShiftMap);
				#endif
				
                return output;
            }
    // ------------------------------------- Fragment Shader
            float4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
            // ------------------------------------- Dirlighting
            	// Normal
			    float3 bitangent = input.tangentWS.w * cross(input.normalWS.xyz, input.tangentWS.xyz);
                half3x3 TBN = half3x3(input.tangentWS.xyz, bitangent.xyz, input.normalWS.xyz);
				float3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv.xy), _BumpScale);
				half3 normalWS = normalize(TransformTangentToWorld(normalTS, TBN));
				// ------------------------------------- MainLightShadow
                float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                Light mainLight = GetMainLight(shadowCoord);
                float3 mainlightColor = mainLight.color;
                float3 mainlightDir = normalize(mainLight.direction);
				#if _ENABLESHADOW_ON
					float mainlightShadow = mainLight.distanceAttenuation * mainLight.shadowAttenuation;
				#else
					float mainlightShadow = 1;
				#endif
				// ------------------------------------- DirSpecular
				half3 viewDirWS = normalize(_WorldSpaceCameraPos.xyz - input.positionWS);
				half3 halfDirWS = normalize(viewDirWS + mainlightDir);
            	float blinnPhong = saturate(dot(normalWS, halfDirWS));
            	float fresnel = pow(1.0 - saturate(dot(normalWS, viewDirWS)), _RimPower);
            	// ------------------------------------- Diffuse
				float lambert = saturate(dot(normalWS, mainlightDir));
				float halfLambert = lambert * 0.5 + 0.5;
				// BaseColor & Gradient
				float3 rampColor = float3(1.0, 1.0, 1.0);
				#if _ENABLEGRADIENT_ON
					float3 topColor =  lerp(1.0, _TopColor.rgb, _TopColor.a * _GradientInt);
					float3 downColor =  lerp(1.0, _DownColor.rgb, _DownColor.a * _GradientInt);
					rampColor = lerp(downColor, topColor, input.uv.y);
				#endif
				
				float4 var_BaseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv.xy);
				float3 baseColor =  var_BaseMap.rgb * _BaseCol.rgb * rampColor;
				// ------------------------------------- Dirlighting
				float3 diffuse = baseColor * lambert;
            // ------------------------------------- Envlighting
				// ------------------------------------- EnvSpecular
            	// Disturb Noise
				#if _USECUSTOMNOISE_ON // 手动扰动Noise // ‘* 2 - 1’ 为了让高光发生位移，原理同之前消散Shader的波形重映射
					float noiseHigh = (SimpleNoise(input.uv.zz, _NoiseHighFreq) * 2.0 - 1.0) * _NoiseHighAmp;
					float noiseLow = (SimpleNoise(input.uv.zz, _NoiseLowFreq) * 2.0 - 1.0) * _NoiseLowAmp;
					float shiftNoise = noiseHigh + noiseLow;
				#else
					float shiftNoise = SAMPLE_TEXTURE2D(_ShiftMap, sampler_ShiftMap, input.uv.zw).r;
				#endif
            	// --- Anisotropy
				// Shift
				float shift1 = shiftNoise - _Shift1;
				float shift2 = shiftNoise - _Shift2;
				float3 bitangentWS1 = normalize(bitangent + shift1 * normalWS);
				float3 bitangentWS2 = normalize(bitangent + shift2 * normalWS);
				// Anisotropy Specular 1
				float dotTH1 = dot(bitangentWS1, halfDirWS);
				float sinTH1 = sqrt(1.0 - dotTH1 * dotTH1);
				float attenDir1 = smoothstep(-1, 0, dotTH1);
				float specular1 = attenDir1 * pow(sinTH1, _Gloss1 * 256.0 + 0.1) * _SpecInt1;
				// Anisotropy Specular 2
				float dotTH2 = dot(bitangentWS2, halfDirWS);
				float sinTH2 = sqrt(1.0 - dotTH2 * dotTH2);
				float attenDir2 = smoothstep(-1, 0, dotTH2);
				float specular2 = attenDir2 * pow(sinTH2, _Gloss2 * 256.0 + 0.1) * _SpecInt2;
            	// --- End Anisotropy
				// Specular Blend
				float3 specular = (specular1 + specular2 * baseColor) * _SpecInt * _SpecCol;
				specular *= saturate(diffuse * 2); // 增强漫反射对镜面反射的影响。
				// Rim
                half3 rimLight = _RimColor.a * _RimColor.rgb * fresnel;
				// ------------------------------------- EnvDiffuse
				float3 ambient = SampleSH(input.normalWS);
            	// ------------------------------------- Final Blend
				// Per Hue
				diffuse = Unity_Hue_Radians_float(diffuse, _Hue);
				specular = Unity_Hue_Radians_float(specular, _Hue);
				rimLight = Unity_Hue_Radians_float(rimLight, _Hue);
				// FinalRGB
				half3 color = (diffuse + specular) * mainlightColor * mainlightShadow
							+ ambient * baseColor
							+ rimLight;
				// Alpha
                half alpha = var_BaseMap.a * _BaseCol.a;
				clip(alpha - _Cutoff);
				// ------------------------------------- Fog
                half fogFactor = ComputeFogFactor(input.positionCS.z * input.positionCS.w);
                color = MixFog(color, fogFactor);
            	
                return float4(color, alpha);
            }
    ENDHLSL
        }
// ------------------------------------- Shadow Pass
        Pass
        {
            Name "ShadowCaster"
            Tags
            { "LightMode" = "ShadowCaster" }
            // ------------------------------------- Render State Commands
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull [_CullMode]
            // ------------------------------------- HLSLPROGRAM
    HLSLPROGRAM
            #pragma target 2.0
            // ------------------------------------- Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            //-------------------------------------- GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            // ------------------------------------- Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            // ------------------------------------- Shader Stages
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            // ------------------------------------- Includes
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
    ENDHLSL
        }
    }
}
