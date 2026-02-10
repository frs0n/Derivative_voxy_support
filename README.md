# Derivative (Voxy 适配版)

本项目完成了对 Derivative 光影的 Voxy 模组原生适配。

### 主要工作：
* **Voxy 兼容性构建**：补齐了 Voxy 所需的 `voxy.json` 协议及 G-Buffer 注入代码。
* **水面渲染修复**：解决了远景水面全黑或完全透明的问题。通过修正深度分层映射、补全合成阶段的反射数据与厚度吸收模型，使远景水体效果与原版保持一致。
* **光照与法线修正**：修正了 Voxy 片元的法线空间转换，确保在不同视角下光影表现正确。

### 对比效果：
| 原版 (不适配 Voxy) | 修改版 (适配 Voxy) |
| :---: | :---: |
| ![原版](../原版-不适配Voxy.png) | ![修改版](../修改版-适配voxyx.png) |

### 特别鸣谢：
* qwertyuiop(moyongxin) - 技术指导
* GeForceLegend - 技术指导
* Yi-Meng - 宣发支持
* factorization - 宣发支持
