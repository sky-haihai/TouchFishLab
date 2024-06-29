using System;
using UnityEngine;
using UnityEngine.Rendering;
using ComputeBuffer = UnityEngine.ComputeBuffer;

namespace OilPaint.Scripts {
    public class BillboardStrokesRenderer : MonoBehaviour {
        public Mesh mesh;
        public Material material;
        public MeshFilter baseMeshFilter;
        public MeshRenderer baseMeshRenderer;

        // material
        public float scale = 1;

        [Range(0, 1f)]
        public float rotationRandomness = 0.5f;

        [Range(0, 1f)]
        public float bumpiness = 0.2f;

        [Range(0, 1f)]
        public float alphaCutoff = 0.2f;

        public int layer;

        public bool renderInSceneCamera = true;
        public bool enableDebug = false;

        private Vector3 m_Dimension = Vector3.zero;
        private Vector3 m_CachedDimension = Vector3.zero;
        private float m_CachedRotationRandomness = 0;
        private Vector3 m_CachedBaseMeshScale = Vector3.zero;
        private float m_CachedBumpiness = 0;
        private float m_CachedAlphaCutoff = 0;


        private Material m_InstancedMaterial;
        private ComputeBuffer m_PositionBuffer;
        private ComputeBuffer m_NormalBuffer;
        private ComputeBuffer m_TangentBuffer;
        private ComputeBuffer m_ColorBuffer;

        private ComputeBuffer m_ArgsBuffer;
        private readonly uint[] m_Args = new uint[5] { 0, 0, 0, 0, 0 };
        private MaterialPropertyBlock m_PropertyBlock;
        private static readonly int PositionBuffer = Shader.PropertyToID("_PositionBuffer");
        private static readonly int NormalBuffer = Shader.PropertyToID("_NormalBuffer");
        private static readonly int TangentBuffer = Shader.PropertyToID("_TangentBuffer");
        private static readonly int Scale = Shader.PropertyToID("_Scale");
        private static readonly int RotationRandomness = Shader.PropertyToID("_RotationRandomness");
        private static readonly int BaseMeshScale = Shader.PropertyToID("_BaseMeshScale");
        private static readonly int HeightOffset = Shader.PropertyToID("_HeightOffset");
        private static readonly int AlphaCutoff = Shader.PropertyToID("_AlphaCutoff");
        private static readonly int ColorBuffer = Shader.PropertyToID("_ColorBuffer");

        private void OnValidate() {
            if (baseMeshFilter == null) baseMeshFilter = GetComponent<MeshFilter>();
            if (baseMeshRenderer == null) baseMeshRenderer = GetComponent<MeshRenderer>();
        }

        void Start() {
            if (m_PositionBuffer == null) m_PositionBuffer = new ComputeBuffer(baseMeshFilter.mesh.vertexCount, 3 * sizeof(float));
            if (m_NormalBuffer == null) m_NormalBuffer = new ComputeBuffer(baseMeshFilter.mesh.vertexCount, 3 * sizeof(float));
            if (m_TangentBuffer == null) m_TangentBuffer = new ComputeBuffer(baseMeshFilter.mesh.vertexCount, 4 * sizeof(float));
            if (m_ColorBuffer == null) m_ColorBuffer = new ComputeBuffer(baseMeshFilter.mesh.vertexCount, 4 * sizeof(float));

            if (m_ArgsBuffer == null) m_ArgsBuffer = new ComputeBuffer(1, m_Args.Length * sizeof(uint), ComputeBufferType.IndirectArguments);
            if (m_InstancedMaterial == null) m_InstancedMaterial = new Material(material);

            m_PropertyBlock = new MaterialPropertyBlock();
            UpdateBuffers();
            baseMeshRenderer.enabled = false;
        }

        private void OnEnable() {
            if (m_PositionBuffer == null) m_PositionBuffer = new ComputeBuffer(baseMeshFilter.mesh.vertexCount, 3 * sizeof(float));
            if (m_NormalBuffer == null) m_NormalBuffer = new ComputeBuffer(baseMeshFilter.mesh.vertexCount, 3 * sizeof(float));
            if (m_TangentBuffer == null) m_TangentBuffer = new ComputeBuffer(baseMeshFilter.mesh.vertexCount, 4 * sizeof(float));
            if (m_ColorBuffer == null) m_ColorBuffer = new ComputeBuffer(baseMeshFilter.mesh.vertexCount, 4 * sizeof(float));

            if (m_ArgsBuffer == null) m_ArgsBuffer = new ComputeBuffer(1, m_Args.Length * sizeof(uint), ComputeBufferType.IndirectArguments);
            if (m_InstancedMaterial == null) m_InstancedMaterial = new Material(material);
            baseMeshRenderer.enabled = false;
        }

        void Update() {
            m_Dimension = baseMeshRenderer.bounds.size;
            // Update starting position buffer
            if (m_CachedDimension != m_Dimension || Math.Abs(m_CachedRotationRandomness - rotationRandomness) > 0.01f ||
                (transform.localScale.magnitude - m_CachedBaseMeshScale.magnitude) > 0.01f || (m_CachedBumpiness - bumpiness) > 0.01f ||
                (m_CachedAlphaCutoff - alphaCutoff) > 0.01f) {
                UpdateBuffers();
            }

            // Render
            Graphics.DrawMeshInstancedIndirect(mesh, 0, m_InstancedMaterial, new Bounds(transform.position, m_Dimension), m_ArgsBuffer, 0, m_PropertyBlock,
                ShadowCastingMode.On, true, layer, renderInSceneCamera ? null : UnityEngine.Camera.main);
        }

        void UpdateBuffers() {
            if (mesh == null) {
                m_Args[0] = m_Args[1] = m_Args[2] = m_Args[3] = 0;
                m_PropertyBlock.Clear();
                Debug.LogWarning("You forgot to assign a mesh to BillboardStrokesRenderer");
                return;
            }


            m_Dimension = new Vector3(Mathf.Max(0, m_Dimension.x), Mathf.Max(0, m_Dimension.y), Mathf.Max(0, m_Dimension.z));

            m_PositionBuffer.SetData(baseMeshFilter.mesh.vertices);
            m_NormalBuffer.SetData(baseMeshFilter.mesh.normals);
            m_TangentBuffer.SetData(baseMeshFilter.mesh.tangents);
            m_ColorBuffer.SetData(baseMeshFilter.mesh.colors);
            m_InstancedMaterial.SetBuffer(PositionBuffer, m_PositionBuffer);
            m_InstancedMaterial.SetBuffer(NormalBuffer, m_NormalBuffer);
            m_InstancedMaterial.SetBuffer(TangentBuffer, m_TangentBuffer);
            m_InstancedMaterial.SetBuffer(ColorBuffer, m_ColorBuffer);

            m_PropertyBlock.SetFloat(Scale, scale);
            m_PropertyBlock.SetFloat(RotationRandomness, rotationRandomness);
            m_PropertyBlock.SetVector(BaseMeshScale, transform.localScale);
            m_PropertyBlock.SetFloat(HeightOffset, bumpiness);
            m_PropertyBlock.SetFloat(AlphaCutoff, alphaCutoff);

            // Args
            // 0 index count per instance,
            // 1 instance count,
            // 2 start index location,
            // 3 base vertex location,
            // 4 start instance location.
            m_Args[0] = (uint)mesh.GetIndexCount(0);
            m_Args[1] = (uint)baseMeshFilter.mesh.vertexCount;
            m_Args[2] = (uint)mesh.GetIndexStart(0);
            m_Args[3] = (uint)mesh.GetBaseVertex(0);

            m_ArgsBuffer.SetData(m_Args);

            m_CachedDimension = m_Dimension;
        }

        void OnDisable() {
            if (m_ArgsBuffer != null)
                m_ArgsBuffer.Release();
            m_ArgsBuffer = null;
            baseMeshRenderer.enabled = true;
        }

#if UNITY_EDITOR
        private void OnDrawGizmos() {
            //draw bounding box
            if (!enableDebug) {
                return;
            }

            Gizmos.color = Color.red;
            Gizmos.DrawWireCube(transform.position, m_Dimension);

            if (!Application.isPlaying) {
                return;
            }

            //draw vertex
            for (var i = 0; i < baseMeshFilter.mesh.vertices.Length; i++) {
                var vert = baseMeshFilter.mesh.vertices[i];
                //normal
                // Gizmos.color = Color.green;
                // Gizmos.DrawLine(transform.TransformPoint(vert), transform.TransformPoint(vert + baseMeshFilter.mesh.normals[i] * 0.05f));
                // //tangent
                // Gizmos.color = Color.red;
                // Gizmos.DrawLine(transform.TransformPoint(vert), transform.TransformPoint(vert + (Vector3)baseMeshFilter.mesh.tangents[i] * 0.05f));
                // //binormal
                // Gizmos.color = Color.blue;
                // Gizmos.DrawLine(transform.TransformPoint(vert),
                //     transform.TransformPoint(vert - Vector3.Cross(baseMeshFilter.mesh.normals[i], (Vector3)baseMeshFilter.mesh.tangents[i]) * 0.05f));
                var vertA = baseMeshFilter.mesh.colors[i].a;
                Gizmos.color = new Color(vertA, vertA, vertA);
                Gizmos.DrawSphere(transform.TransformPoint(vert), 0.01f);
            }
        }
#endif
    }
}