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
        public int subMeshIndex = 0;

        // material
        public float scale = 1;
        public int layer;
        public ShadowCastingMode castShadows = ShadowCastingMode.On;

        // instancing
        // public ComputeShader instantiateStrokeShader;

        public bool renderInSceneCamera = true;
        public bool enableDebug = false;

        private Vector3 m_Dimension = Vector3.zero;
        private Vector3 m_CachedDimension = Vector3.zero;

        private Material m_InstancedMaterial;
        private ComputeBuffer m_PositionBuffer;
        private ComputeBuffer m_NormalBuffer;
        private ComputeBuffer m_TangentBuffer;

        private ComputeBuffer m_ArgsBuffer;
        private readonly uint[] m_Args = new uint[5] { 0, 0, 0, 0, 0 };
        private MaterialPropertyBlock m_PropertyBlock;
        private static readonly int PositionBuffer = Shader.PropertyToID("_PositionBuffer");
        private static readonly int NormalBuffer = Shader.PropertyToID("_NormalBuffer");
        private static readonly int TangentBuffer = Shader.PropertyToID("_TangentBuffer");
        private static readonly int Scale = Shader.PropertyToID("_Scale");

        private struct StrokeData {
            public Vector3 position;
            public Vector3 normal;
            public Vector3 tangent;
        }

        private void OnValidate() {
            if (baseMeshFilter == null) baseMeshFilter = GetComponent<MeshFilter>();
            if (baseMeshRenderer == null) baseMeshRenderer = GetComponent<MeshRenderer>();
        }

        void Start() {
            if (m_PositionBuffer == null) m_PositionBuffer = new ComputeBuffer(baseMeshFilter.mesh.vertexCount, 3 * sizeof(float));
            if (m_NormalBuffer == null) m_NormalBuffer = new ComputeBuffer(baseMeshFilter.mesh.vertexCount, 3 * sizeof(float));
            if (m_TangentBuffer == null) m_TangentBuffer = new ComputeBuffer(baseMeshFilter.mesh.vertexCount, 4 * sizeof(float));
            if (m_ArgsBuffer == null) m_ArgsBuffer = new ComputeBuffer(1, m_Args.Length * sizeof(uint), ComputeBufferType.IndirectArguments);
            if (m_InstancedMaterial == null) m_InstancedMaterial = new Material(material);

            m_PropertyBlock = new MaterialPropertyBlock();
            UpdateBuffers();
        }

        private void OnEnable() {
            if (m_PositionBuffer == null) m_PositionBuffer = new ComputeBuffer(baseMeshFilter.mesh.vertexCount, 3 * sizeof(float));
            if (m_NormalBuffer == null) m_NormalBuffer = new ComputeBuffer(baseMeshFilter.mesh.vertexCount, 3 * sizeof(float));
            if (m_TangentBuffer == null) m_TangentBuffer = new ComputeBuffer(baseMeshFilter.mesh.vertexCount, 4 * sizeof(float));
            if (m_ArgsBuffer == null) m_ArgsBuffer = new ComputeBuffer(1, m_Args.Length * sizeof(uint), ComputeBufferType.IndirectArguments);
            if (m_InstancedMaterial == null) m_InstancedMaterial = new Material(material);
        }

        void Update() {
            m_Dimension = baseMeshRenderer.bounds.size;
            // Update starting position buffer
            // if (m_CachedDimension != m_Dimension) {
            UpdateBuffers();
            // }

            // Render
            Graphics.DrawMeshInstancedIndirect(mesh, subMeshIndex, m_InstancedMaterial, new Bounds(transform.position, m_Dimension), m_ArgsBuffer, 0, m_PropertyBlock,
                castShadows, true, layer, renderInSceneCamera ? null : UnityEngine.Camera.main);
        }

        void UpdateBuffers() {
            if (mesh == null) {
                m_Args[0] = m_Args[1] = m_Args[2] = m_Args[3] = 0;
                m_PropertyBlock.Clear();
                Debug.LogWarning("You forgot to assign a mesh to BrushStrokesRenderer");
                return;
            }

            // Ensure submesh index is in range
            subMeshIndex = Mathf.Clamp(subMeshIndex, 0, mesh.subMeshCount - 1);

            m_Dimension = new Vector3(Mathf.Max(0, m_Dimension.x), Mathf.Max(0, m_Dimension.y), Mathf.Max(0, m_Dimension.z));

            m_PositionBuffer.SetData(baseMeshFilter.mesh.vertices);
            m_NormalBuffer.SetData(baseMeshFilter.mesh.normals);
            m_TangentBuffer.SetData(baseMeshFilter.mesh.tangents);
            m_InstancedMaterial.SetBuffer(PositionBuffer, m_PositionBuffer);
            m_InstancedMaterial.SetBuffer(NormalBuffer, m_NormalBuffer);
            m_InstancedMaterial.SetBuffer(TangentBuffer, m_TangentBuffer);

            m_PropertyBlock.SetFloat(Scale, scale);

            // Args
            // 0 index count per instance,
            // 1 instance count,
            // 2 start index location,
            // 3 base vertex location,
            // 4 start instance location.
            m_Args[0] = (uint)mesh.GetIndexCount(subMeshIndex);
            m_Args[1] = (uint)baseMeshFilter.mesh.vertexCount;
            m_Args[2] = (uint)mesh.GetIndexStart(subMeshIndex);
            m_Args[3] = (uint)mesh.GetBaseVertex(subMeshIndex);

            m_ArgsBuffer.SetData(m_Args);

            m_CachedDimension = m_Dimension;
        }

        void OnDisable() {
            if (m_ArgsBuffer != null)
                m_ArgsBuffer.Release();
            m_ArgsBuffer = null;
        }

#if UNITY_EDITOR
        private void OnDrawGizmos() {
            //draw bounding box
            if (!enableDebug) {
                return;
            }
            Gizmos.color = Color.red;
            Gizmos.DrawWireCube(transform.position, m_Dimension);

            //draw vertex
            for (var i = 0; i < baseMeshFilter.mesh.vertices.Length; i++) {
                var vert = baseMeshFilter.mesh.vertices[i];
                Gizmos.color = Color.white;
                Gizmos.DrawSphere(transform.TransformPoint(vert), 0.01f);
                //normal
                Gizmos.color = Color.green;
                Gizmos.DrawLine(transform.TransformPoint(vert), transform.TransformPoint(vert + baseMeshFilter.mesh.normals[i] * 0.05f));
                //tangent
                Gizmos.color = Color.red;
                Gizmos.DrawLine(transform.TransformPoint(vert), transform.TransformPoint(vert + (Vector3)baseMeshFilter.mesh.tangents[i] * 0.05f));
                //binormal
                Gizmos.color = Color.blue;
                Gizmos.DrawLine(transform.TransformPoint(vert),
                    transform.TransformPoint(vert - Vector3.Cross(baseMeshFilter.mesh.normals[i], (Vector3)baseMeshFilter.mesh.tangents[i]) * 0.05f));
            }
        }
#endif
    }
}