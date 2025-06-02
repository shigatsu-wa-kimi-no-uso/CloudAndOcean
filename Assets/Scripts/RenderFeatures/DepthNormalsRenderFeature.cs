
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
 
 
public class DepthNormalsRenderFeature : ScriptableRendererFeature
{
 
 
    // 定义3个共有变量
    public class Settings
    {
        //public Shader shader; // 设置后处理shader
        public Material material; //后处理Material
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing; // 定义事件位置，放在了官方的后处理之前
    }
 
    // 初始化一个刚刚定义的Settings类
    public Settings settings = new Settings();
    // 初始化Pass
    DepthNormalsRenderPass _depthNormalsRenderPass;
    // 初始化纹理
    RenderTargetHandle depthNormalsTexture;
    // 材质
    Material depthNormalsMaterial;
 
    // 给pass传递变量，并加入渲染管线中
    public override void Create()
    {
        // 通过Built-it管线中的Shader创建材质，最重要的一步！
        depthNormalsMaterial = CoreUtils.CreateEngineMaterial("Hidden/Internal-DepthNormalsTexture");
        // 获取Pass（渲染队列，渲染对象，材质）
        _depthNormalsRenderPass = new DepthNormalsRenderPass(RenderQueueRange.opaque, -1, depthNormalsMaterial);
        // 设置渲染时机 = 预渲染通道后
        _depthNormalsRenderPass.renderPassEvent = RenderPassEvent.AfterRenderingPrePasses;
        // 设置纹理名
        depthNormalsTexture.Init("_CameraDepthNormalsTexture");
    }
 
    //这里你可以在渲染器中注入一个或多个渲染通道。
    //这个方法在设置渲染器时被调用。
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // 对Pass进行参数设置（当前渲染相机信息，深度法线纹理）
        _depthNormalsRenderPass.Setup(renderingData.cameraData.cameraTargetDescriptor, depthNormalsTexture);
        // 写入渲染管线队列
        renderer.EnqueuePass(_depthNormalsRenderPass);
    }
    
}
 
public class DepthNormalsRenderPass : ScriptableRenderPass
{
    int kDepthBufferBits = 32;                                   // 缓冲区大小
    private RenderTargetHandle Destination { get; set; }         // 深度法线纹理
 
    private Material DepthNormalsMaterial = null;                // 材质
 
    private FilteringSettings m_FilteringSettings;               // 筛选设置
 
    static readonly string m_ProfilerTag = "Depth Normal Pre Pass"; // 定义渲染Tag
 
    ShaderTagId m_ShaderTagId = new ShaderTagId("MyDepthOnly");    // 绘制标签，Shader需要声明这个标签的tag
 
    /// <summary>
    /// 构造函数Pass
    /// </summary>
    /// <param name="renderQueueRange"></param>
    /// <param name="layerMask"></param>
    /// <param name="material"></param>
    public DepthNormalsRenderPass(RenderQueueRange renderQueueRange, LayerMask layerMask, Material material)
    {
        m_FilteringSettings = new FilteringSettings(renderQueueRange, layerMask);
        DepthNormalsMaterial = material;
    }
 
    /// <summary>
    /// 参数设置
    /// </summary>
    /// <param name="baseDescriptor"></param>
    /// <param name="Destination"></param>
    public void Setup(RenderTextureDescriptor baseDescriptor, RenderTargetHandle Destination)
    {
        // 设置纹理
        this.Destination = Destination;
    }
 
    /// <summary>
    /// 配置渲染目标，可创建临时纹理
    /// </summary>
    /// <param name="cmd"></param>
    /// <param name="cameraTextureDescriptor"></param>
    public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
    {
        // 设置渲染目标信息
        RenderTextureDescriptor descriptor = cameraTextureDescriptor;
        descriptor.depthBufferBits = kDepthBufferBits;
        descriptor.colorFormat = RenderTextureFormat.ARGB32;
 
        // 创建一个临时的RT（储存深度法线纹理、目标信息和滤波模式）
        cmd.GetTemporaryRT(Destination.id, descriptor, FilterMode.Point);
        // 配置
        ConfigureTarget(Destination.Identifier());
        // 清楚，未渲染时配置为黑色
        ConfigureClear(ClearFlag.All, Color.black);
    }
 
    // 
    /// <summary>
    /// 后处理逻辑和渲染核心函数，相当于build-in 的OnRenderImage()
    /// 实现渲染逻辑
    /// </summary>
    /// <param name="context"></param>
    /// <param name="renderingData"></param>
    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        var cmd = CommandBufferPool.Get(m_ProfilerTag);     // 设置渲染标签
 
        using (new ProfilingSample(cmd, m_ProfilerTag))
        {
            // 执行命令缓存
            context.ExecuteCommandBuffer(cmd);
            // 清楚数据缓存
            cmd.Clear();
 
            // 相机的排序标志
            var sortFlags = renderingData.cameraData.defaultOpaqueSortFlags;
            // 创建绘制设置
            var drawSettings = CreateDrawingSettings(m_ShaderTagId, ref renderingData, sortFlags);
            // 设置对象数据
            drawSettings.perObjectData = PerObjectData.None;
            // 设置覆盖材质
            drawSettings.overrideMaterial = DepthNormalsMaterial;
 
            // 绘制渲染器
            context.DrawRenderers(renderingData.cullResults, ref drawSettings, ref m_FilteringSettings);
 
            // 设置全局纹理
            cmd.SetGlobalTexture("_CameraDepthNormalsTexture", Destination.id);
        }
        // 执行命令缓冲区
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }
 
        // 清除此呈现传递执行期间创建的任何已分配资源。
        public override void FrameCleanup(CommandBuffer cmd)
        {
            if (Destination != RenderTargetHandle.CameraTarget)
            {
                cmd.ReleaseTemporaryRT(Destination.id);
                Destination = RenderTargetHandle.CameraTarget;
            }
        }
}