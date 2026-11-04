//
//  LiquidGlass.metal
//  Auto Widget
//
//  Created by Jinyu Zhang on 2026/11/4.
//

#include <metal_stdlib>
using namespace metal;

// 💡 必须加上 [[ stitchable ]]，并使用 half4 / float2 标准签名
[[ stitchable ]] half4 liquidGlassShader(
    float2 position,               // 当前像素的二维坐标
    half4 color,                   // 当前像素的原始颜色
    float time,                    // 传入的时间（可选，用于动画）
    float4 bounds                  // 传入的视图边界 (x, y, width, height)
) {
    // 如果文字或像素本身是透明的，直接跳过，保持透明
    if (color.a <= 0.01) {
        return color;
    }
    
    half4 glassColor = color;
    
    // 获取当前视图的高度（防止写死 100.0）
    float height = bounds.w > 0.0 ? bounds.w : 100.0;
    
    // 💡 修复了原本漏掉的减号：模拟顶部高光渐变
    float highlightFactor = 1.0 - (position.y / height);
    
    // 在像素原色基础上叠加一层晶莹的顶部白光/高光
    glassColor.rgb += half3(0.35) * max(0.0, highlightFactor);
    
    return glassColor;
}
