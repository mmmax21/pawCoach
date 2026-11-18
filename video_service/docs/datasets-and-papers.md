# PawCoach 数据集与论文调研报告

> 面向「宠物行为训练 Agent」MVP 的公开数据与方法调研。
>
> 调研日期：2026-11
> 说明：本报告中的链接均经 HTTP 实际访问验证；规模数字来自数据集官方主页或论文摘要，
> 未能核实的已在条目内明确标注 **[未核实]**。

**图例**

| 标记 | 含义 |
|---|---|
| ✅ | 链接已验证可达，可下载/可申请 |
| 🟡 | 页面存活但需申请、签署协议或为 gated 仓库 |
| ⚠️ | 官方页当前不可达，附替代入口 |
| 💰 | 许可明确允许商业使用 |
| 🚫 | 许可明确禁止商业使用（仅研究） |
| ❓ | 许可未核实，使用前须查 LICENSE |

---

## 目录

- [0. 结论摘要](#0-结论摘要)
- [1. 问题拆解](#1-问题拆解为什么不能指望一个大模型看视频)
- [2. 数据集](#2-数据集)
  - [2.1 犬类行为与动作视频](#21-犬类行为与动作视频)
  - [2.2 狗的姿态与关键点](#22-狗的姿态与关键点)
  - [2.3 可穿戴传感器](#23-可穿戴传感器牵绳场景的隐藏最优解)
  - [2.4 动作质量评估 AQA](#24-动作质量评估aqa做得对不对的方法论来源)
  - [2.5 人侧信号：口令、手部、奖励](#25-人侧信号口令手部奖励动作)
  - [2.6 情绪、压力与面部信号](#26-情绪压力与面部信号)
- [3. 论文](#3-论文)
  - [3.1 核心范式（必读四篇）](#31-核心范式必读四篇)
  - [3.2 可执行反馈与教学过程](#32-可执行反馈与教学过程)
  - [3.3 动物姿态与行为识别](#33-动物姿态与行为识别)
  - [3.4 动作质量评估 AQA](#34-动作质量评估aqa)
  - [3.5 训练科学：行为学与学习机制](#35-训练科学行为学与学习机制)
- [4. 能力边界与数据缺口](#4-能力边界与数据缺口)
- [5. 建议](#5-建议)

---

## 0. 结论摘要

1. **这不是一个视觉问题，是三件难度不同的事。** ①状态测量（狗什么姿态、口令在第几秒、人做了什么）
   有成熟方案和公开数据；②质量判定（这一步做对了吗）方法论成熟但**没有训犬版标注数据**；
   ③处方生成（下次练什么）是纯语言任务，靠知识库不靠视觉。MVP 的难点只集中在②。

2. **不要让多模态大模型直接看视频下结论。** 依据 K9-Bench（NeurIPS 2026）实测：
   前沿 MLLM 在犬类视频上的零样本表现有限，难以对长时段内细微的姿态与互动线索做组合推理；
   加 CoT 提示收益有限，帧数从 64 加到 128 即饱和。正确架构是
   **视频 → 可测量的中间量 → LLM 基于数字生成反馈**。

3. **你的数据护城河在一个学术界没人碰的缺口上。** 不存在「训犬片段+正确性标注」，
   不存在「人-狗双主体 + 口令语音 + 奖励事件」的三重时间对齐数据，不存在纵向训练日志，
   也不存在中文口令/国内家庭场景数据。用户每天上传的视频 + 训犬师复核结论，
   正是在生产这份数据集。

4. **许可问题会直接影响商业模式。** 最贴场景的几个数据集（SyDog-Video、Mendeley Canine Emotions）
   **明确禁止商用**。可在商业产品中使用的只有少数（见 §2.3 的 CC BY 4.0 数据集）。
   详见 [§4.2](#42-许可红线会直接影响商业模式)。

5. **推荐的第一个场景是「等待 / Stay 持续时间」**，原因是它几乎不需要语义理解，
   可纯靠时间轴 + 姿态稳定性度量，且进步直接体现为一条时长曲线。
   见 [§5](#5-建议)。

---

## 1. 问题拆解：为什么不能指望一个大模型看视频

| 子问题 | 本质 | 可用资源 | 难度 |
|---|---|---|---|
| **① 状态测量**<br>狗在哪、什么姿态、人做了什么、口令在第几秒 | 检测 + 姿态估计 + 时序对齐 | 成熟。公开数据集 + 开源权重齐备 | 低 |
| **② 质量判定**<br>这一步做得对不对（时机、力度、顺序） | 动作质量评估（Action Quality Assessment, AQA） | 方法论成熟，但**无训犬版本标注数据** | 中（靠规则 + 自建） |
| **③ 处方生成**<br>下次练什么、怎么改 | LLM + 训练师 SOP 检索 | 纯语言任务，靠知识库不靠视觉 | 低 |

市面上的产品描述通常把这三件事揉成一句「分析动作」。拆开后会发现瓶颈只在②，
而②的解法不是更强的模型，是**更可靠的测量 + 更严的置信度管理**。

### 关键证据：K9-Bench 的实测结论

K9-Bench 是当前唯一针对家犬视频的多模态理解基准（907 视频 / 4,744 QA 对 / 5 类任务）。
其论文原文结论：

> frontier MLLMs exhibit limited zero-shot performance on canine-centric tasks …
> they still struggle with compositional reasoning over subtle posture and interaction cues
> spread over long horizons. […] generic chain-of-thought prompting provides only modest
> performance for such long-horizon reasoning.

补充实验结论：
- 输入音频仅带来小幅提升（在 Action Sequence 类任务上略明显）
- 帧数从 32 → 64 有小幅收益，64 → 128 迅速饱和
- Gemini-2.5 Pro (A+V) 在不同时长下较稳，其他模型超过 3–5 分钟即明显退化

**工程含义**：把 20–60 秒视频直接丢给 VLM 问「他做对了吗」，得到的是不可靠且不可解释的答案。
必须先降维成结构化测量值。

---

## 2. 数据集

### 2.1 犬类行为与动作视频

| 数据集 | 规模（官方口径） | 模态 | 许可 | 获取 |
|---|---|---|---|---|
| **K9-Bench** | 907 视频 / ≈4,744 QA 对 / 5 类任务（Posture / Action Sequence / Context / Cause-Effect / Interaction） | 视频 + 音频 + 文本 | 🟡 gated，需同意条款 | [HuggingFace `ogmen/K9Bench`](https://huggingface.co/datasets/ogmen/K9Bench) ・ [评测代码](https://github.com/ogmenrobotics/K9Bench-eval-code) ・ [项目页](https://ogmenrobotics.github.io/K9Bench) ・ [论文](https://arxiv.org/abs/2607.02680) |
| **Animal Kingdom** | >850 物种；30k 动作 clips / 140 动作类；50h 长视频用于时序定位；33k 帧 / 23 关键点 | RGB + 文本 | ❓ 研究用途，见仓库 LICENSE | [GitHub `sutdcv/Animal-Kingdom`](https://github.com/sutdcv/Animal-Kingdom) ・ [论文](https://arxiv.org/abs/2204.08129) |
| **MammalNet** | 173 类哺乳动物 / 18k+ 视频（539h）/ 12 种行为 + **时序定位** | RGB | ❓ 见仓库 LICENSE | [GitHub `Vision-CAIR/MammalNet`](https://github.com/Vision-CAIR/MammalNet) |
| **DECADE**（Who Let The Dogs Out） | 狗佩戴 GoPro + IMU 的第一视角行为数据 | 第一视角视频 + IMU | ❓ 见仓库 LICENSE | [GitHub `ehsanik/dogTorch`](https://github.com/ehsanik/dogTorch) ・ [论文 arXiv 1803.10827](https://arxiv.org/abs/1803.10827) |
| **Dog Clips**（Franzoni et al.） | 约 100 段视频，42 个动作/状态标签，单帧可多标 **[二手信息，未核实]** | RGB | ❓ | [论文 Springer NCA 2024](https://link.springer.com/article/10.1007/s00521-024-10042-3) |
| **CREMD** | 923 clips / 351 只狗，3 种呈现模式（无上下文无音频 / 有上下文无音频 / 全有） | 视频 + 音频 + 情境 | ❓ | [arXiv 2602.15349](https://arxiv.org/abs/2602.15349) ・ [HTML 全文](https://arxiv.org/html/2602.15349v1) |
| **ScatSpotter** | 手机拍摄的狗粪便图像 + 多边形标注 | 图像 | ❓ | [arXiv 2412.16473](https://arxiv.org/abs/2412.16473) |
| **MammAlps** | 阿尔卑斯野生哺乳动物多视角行为监测（Swiss Alps） | 视频 + 音频 | ❓ | [arXiv 2503.18223](https://arxiv.org/abs/2503.18223) |

**选型建议**
- **K9-Bench 用来定能力上限和做评测**，不是训练集。它的 5 类任务划分（尤其是
  Posture Analysis 和 Interaction Analysis）可直接映射到产品需求。
- **MammalNet 是唯一带事件级时序定位的大规模哺乳动物数据集**，
  其范式正是「从长视频里定位行为起止时间」，对应你的「口令发出后第几秒狗动了」。
- DECADE 是第一视角 + 穿戴，与手机第三人称拍摄差异大，仅作行为建模思路参考。

### 2.2 狗的姿态与关键点

这是①状态测量的地基。**工程上先上现成权重，别自己训。**

| 数据集 | 规模（官方口径） | 关键点 | 许可 | 获取 |
|---|---|---|---|---|
| **StanfordExtra** | 基于 Stanford Dogs 扩展的狗图像，含 2D 关键点 + 分割 **[规模数字未独立核实]** | 20 kp | 🟡 标注需填表申请 | [GitHub `benjiebob/StanfordExtra`](https://github.com/benjiebob/StanfordExtra) ・ [论文 WLDO, arXiv 2007.11110](https://arxiv.org/abs/2007.11110) |
| **SyDog** | 合成狗图像数据集（Unity 生成） | 2D pose | ❓ | [论文 arXiv 2108.00249](https://arxiv.org/abs/2108.00249) |
| **SyDog-Video** ⭐ | 500 个合成视频 × 175 帧 = 87,500 帧；6 个域变体（clean_plate / w_assets / w_people / …） | 33 kp + 分割 + bbox | 🚫 **仅非商用研究，不可再分发** | [官方页 + 直接下载](https://cvssp.org/data/SyDogVideo/) ・ [全文包 tar.gz](https://cvssp.org/data/SyDogVideo/SyDogVideo2024_full.tar.gz) ・ [论文 IJCV 2023](https://doi.org/10.1007/s11263-023-01946-z) |
| **AP-10K** | 10,015 图 / 13,028 instances / 54 物种 23 科 | 17 kp | ❓ 见仓库 LICENSE | [GitHub `AlexTheBad/AP-10K`](https://github.com/AlexTheBad/AP-10K) ・ [论文](https://arxiv.org/abs/2108.12617) |
| **APT-36K** | 36,000 帧 / 2,400 clips / 30 物种 | 17 kp + bbox + track ID | ❓ | [GitHub `pandorgan/APT-36K`](https://github.com/pandorgan/APT-36K) ・ [论文](https://arxiv.org/abs/2206.05683) |
| **APTv2** | 2,749 clips / 41,235 帧 / 84,611 instances，含 easy / hard（拥挤）划分 | kp + track ID | ❓ | [GitHub `ViTAE-Transformer/APTv2`](https://github.com/ViTAE-Transformer/APTv2) ・ [论文](https://arxiv.org/abs/2312.15612) |
| **Animal-Pose** | 4,000+ 图 / 6,000+ instances（狗/猫/牛/马/羊） | 20 kp | ❓ | [官方页](https://sites.google.com/view/animal-pose/) ・ [GitHub](https://github.com/noahcao/animal-pose-dataset) ・ [论文 ICCV 2019](https://openaccess.thecvf.com/content_ICCV_2019/html/Cao_Cross-Domain_Adaptation_for_Animal_Pose_Estimation_ICCV_2019_paper.html) |
| **RGBD-Dog** | 用 RGBD 传感器采集的狗姿态数据 | 3D pose | ❓ | [论文 arXiv 2004.07788](https://arxiv.org/abs/2004.07788) |
| **3DDogs-Lab** | 室内步道，多模态 3D 动作捕捉，用于单目 3D 狗姿态基准 | 3D pose | ❓ | [论文 arXiv 2406.14412](https://arxiv.org/abs/2406.14412) |
| **BARC / BITE** | 单图重建狗的 3D 形状与姿态（CVPR 2022 / 2023） | 3D shape + pose | ❓ | [BARC 代码](https://github.com/runa91/barc_release) |
| **DogPoseCV** ⭐ | 实测 20,423 张（卡片称 20,578）/ 119 犬种 / 4 类整图姿态分类（standing·sitting·lying·undefined） | **图像级类别，无关键点** | 💰 标称 `apache-2.0`（⚠️ 底图版权见下） | [HuggingFace](https://huggingface.co/datasets/stockeh/dog-pose-cv) ・ [GitHub](https://github.com/stockeh/canine-embedded-ml) ・ [论文 arXiv 2101.02380](https://arxiv.org/abs/2101.02380) |

#### 专项评估：DogPoseCV（`stockeh/dog-pose-cv`）

**这是什么。** Stanford Dogs 的重标注版本：把「犬种」标签换成「姿态」标签（standing / sitting /
lying / undefined），用于训练图像分类器判断狗的姿势。它是 Colorado State University 那篇
「AI 训狗」论文（arXiv 2101.02380）的配套数据集——同一批人为了在 Jetson Nano 上实时判断
sit/stand/lie 并触发投喂而构建的。**这是目前唯一一份标称可商用、姿态类别又与 Stay 训练判定对齐的犬姿态数据集。**

**实测核对（已下载 `labels.tar.gz` 逐行统计）——卡片与实物不符：**

| 类别 | 数据集卡片声明 | 实测 CSV 统计 |
|---|---:|---:|
| standing | 4,143 | **7,047** |
| sitting | 3,038 | 3,008 |
| lying | 7,090 | **4,110** |
| undefined | 6,307 | 6,258 |
| **合计** | **20,578** | **20,423** |

此外：CSV 中的标签名是 `lying` 而非卡片写的 `lying down`；实际为 **119 个犬种 CSV**，卡片称 120；
`standing` 与 `lying` 的数量近乎互换。**结论：这份数据集卡片不可作为依据，一切以下载后的实物为准。**

**可用性判定：可用，但只能放在特定位置。**

| 维度 | 判定 | 说明 |
|---|---|---|
| 许可 | ⚠️ 有条件 | HF 标 `apache-2.0`，但**重标注不改变原图版权**（底图为 Stanford Dogs / ImageNet 子集），商用前须确认底层图像条款 |
| 规模 | ✅ 够 | 2 万张、4 类，单卡可训，适合做 baseline |
| 类别对齐 | ✅ 好 | sit/stand/lie 正是 Stay 训练的核心判定类别 |
| 端侧可行性 | ✅ 强证据 | 原论文在 **Jetson Nano 上 92% 准确率 / 39 FPS**，手机端算力远超此标准 |
| 时序能力 | ❌ 无 | 静态图像，没有时间轴 → **测不了** `stay_duration` / `cue_latency` / `reward_delay` |
| 可解释性 | ❌ 弱 | 只有整图标签，没有关键点 → 给不出「移动了 0.3 体长」这类可回溯量 |
| 过渡态 | ❌ 无 | 只有四个终态类别，没有「起身中 / 转身 / 前移」，而 Stay 判定恰恰依赖过渡态 |
| 域匹配 | ❌ 差 | 源自 Flickr 犬种图（多为艺术化侧拍），不是手机拍的家庭室内训练场景 |
| 工程可得性 | ⚠️ 需手动 | HF dataset viewer 报错（`KeyError: 'jpg'`，webdataset 字段缺失），`load_dataset()` 会失败 |

**结论与用法**

- ✅ **做 P0 的第一步验证器**：训一个 3 类（去掉 undefined）轻量分类器，先回答
  「坐 / 站 / 卧 能不能分开」。这一步都过不了，说明整个技术路线要重新想。
- ✅ **做伪标签源**：用它对自采视频抽帧粗打标，再人工修正，能显著降低首批标注成本。
- ❌ **不能作为核心数据**，也不能用于任何时长/时机类指标——那是时序任务，需要关键点或跨帧跟踪。
- 数据下载（viewer 坏了，必须手动）：
  [images.tar.gz](https://huggingface.co/datasets/stockeh/dog-pose-cv/resolve/main/data/images.tar.gz)（779.7 MB）・
  [labels.tar.gz](https://huggingface.co/datasets/stockeh/dog-pose-cv/resolve/main/data/labels.tar.gz)（104.7 KB）。
  **无官方 train/test 划分**，需自行按犬种或随机切分（注意：同一只狗跨划分会虚高准确率）。

**现成工具（比数据集更该先用）**

| 工具 | 用途 | 链接 |
|---|---|---|
| **mmpose** | AP-10K / APT-36K 权重现成，直接推理狗的关键点 | [文档 · 2D Animal Keypoint](https://mmpose.readthedocs.io/en/latest/dataset_zoo/2d_animal_keypoint.html) |
| **DeepLabCut / SuperAnimal-Quadruped** | 跨物种四足预训练模型，零样本可对狗视频推理，**MVP 最快起点** | [DeepLabCut](https://github.com/DeepLabCut/DeepLabCut) ・ [模型权重](https://huggingface.co/mwmathis/DeepLabCutModelZoo-SuperAnimal-Quadruped) ・ [论文 Nature Comm 2024](https://doi.org/10.1038/s41467-024-48792-2) |
| **DeepLabCut 原始论文** | 少样本无标记姿态估计的奠基工作 | [Nature Neuroscience 2018](https://doi.org/10.1038/s41593-018-0209-y) |

> **关键工程决定：用 2D，不要碰 3D。**
> 手机单目视频算「狗的姿态是否发生变化」「保持了多少秒」，2D 关键点已经足够；
> 3D 重建的误差和算力成本对 MVP 是纯负担。3DDogs-Lab 的基准结果也说明单目 3D 仍有明显误差。

### 2.3 可穿戴传感器：牵绳场景的隐藏最优解

| 数据集 | 规模 | 内容 | 许可 | 获取 |
|---|---|---|---|---|
| **Movement Sensor Dataset for Dog Behavior Classification** ⭐ | 430 MB；`DogMoveData.mat`；100 Hz；3 轴加速度 + 3 轴陀螺；collar + harness 双位点；7 类行为（gallop / lying on chest / sitting / sniffing / standing / trotting / walking）；45 只中大型犬 | 同步视频标注 + IMU | 💰 **CC BY 4.0（可商用）** | [Mendeley Data](https://data.mendeley.com/datasets/vxhx934tbn/1) ・ DOI `10.17632/vxhx934tbn.1` |

**配套论文**

| 论文 | 要点 | 链接 |
|---|---|---|
| Kumpulainen et al., 2021, *Applied Animal Behaviour Science*（**开放获取，CC BY 4.0**） | 用 harness + collar 运动传感器做 7 类狗行为分类。⚠️ **注意：原文把「狗向人倾斜或拉扯牵绳导致步态/体态变形」列为排除标准**，即拉扯是污染信号、必须剔除——它不是这份数据能识别的类别 | [ScienceDirect 全文](https://www.sciencedirect.com/science/article/pii/S0168159121001805) ・ [DOI 10.1016/j.applanim.2021.105393](https://doi.org/10.1016/j.applanim.2021.105393) |
| Vehkaoja et al., 2022, *Data in Brief* | 上述数据集的数据说明 | [PMC8777071](https://pmc.ncbi.nlm.nih.gov/articles/PMC8777071/) |

> **注意同一批数据的两个入口**：Kaggle 上的
> [`arashnic/animal-behavior-analysis`](https://www.kaggle.com/datasets/arashnic/animal-behavior-analysis)
> 描述同样是「45 只中大型犬、collar + harness 双传感器」，与 Mendeley 这份是**同一批数据**的
> 另一种分发形式，不要当成两个独立数据集重复计数。

> **为什么值得单独说（以及一个必须纠正的误读）**
>
> 若选「牵绳拉扯」作为切入点，纯视频很难量出「拉力」。可靠的替代指标是
> **绳张力 / 人狗距离突变 / 拉扯频次（加速度峰值）**。
>
> 但要小心一个陷阱：上面这份数据集**不能**直接拿来训「拉扯检测器」。原文明确写道，
> 动态行为只在无歧义时才编码——即**排除**了「狗向人倾斜或拉扯牵绳从而影响步态或体态」的片段。
> 换句话说，拉扯在这份数据里是**污染项**，不是标签。**不要基于二手摘要做出相反的理解。**
>
> 这反而是个有价值的技术预警：**拉扯会破坏常规步态/行为分类器的输入分布**，
> 所以「拉扯」必须作为独立任务单独建模，不能指望复用行为分类模型。由此有两条可行路线：
> ① 自建「拉扯 / 非拉扯」标注片段（这是缺口，也是机会）；
> ② **让 App 读取手机自身加速度计**——手机放口袋里，人端被拽的加速度峰值是零成本、
>    且不涉及摄像头隐私的强信号。这是被竞品普遍忽略的低成本传感器。

相关工程验证：**An Integrated Wearable Sensor System for Simultaneous Pull and Pace Characterization in Guide Dogs**（ACM ACI 2025）——
用可穿戴传感器同时记录导盲犬的 **拉力（pull）** 与 **步态（pace）**。这篇是最接近「用传感器量化牵绳拉扯」的公开工作。
→ [ACM DL](https://dl.acm.org/doi/full/10.1145/3768539.3768563) ・ [DOI 10.1145/3768539.3768563](https://doi.org/10.1145/3768539.3768563)

### 2.4 动作质量评估（AQA）："做得对不对"的方法论来源

AQA 是体育 / 手术 / 康复领域研究「从视频判断动作水平」的成熟分支。**这是最该借鉴的方法论。**

| 数据集 | 规模（官方口径） | 特点 | 获取 |
|---|---|---|---|
| **FineDiving** ⭐ | 3,000 视频 / 52 动作类型 / 29 子动作 / 23 难度 | **过程感知（procedure-aware）**：标注动作步骤顺序与每步得分 → 直接类比「训练步骤拆解」 | [GitHub `xujinglin/finediving`](https://github.com/xujinglin/finediving) ・ [项目页](https://sites.google.com/view/finediving) ・ [论文](https://arxiv.org/abs/2204.03646) |
| **MTL-AQA** | 1,412 段跳水样本，带因子化细粒度标注 | 多任务（分数 + 各维度）联合学习 | [GitHub `ParitoshParmar/MTL-AQA`](https://github.com/ParitoshParmar/MTL-AQA) ・ [论文 CVPR 2019](https://openaccess.thecvf.com/content_CVPR_2019/papers/Parmar_What_and_How_Well_You_Performed_A_Multitask_Learning_Approach_CVPR_2019_paper.pdf) |
| **AQA-7** | 7 类奥运项目（单人跳水10m / 体操跳马 / 大跳台滑雪 / 单板 / 同步跳水等）；共 1,000+ 段 | 经典基线数据集 | [UNLV RTIS 官方下载页](http://rtis.oit.unlv.edu/datasets.html) |
| **JIGSAWS** | **8 位不同水平外科医生 × 5 次重复 × 3 项任务**（suturing / knot-tying / needle-passing），达芬奇系统采集；视频 + 运动学 + 手势标注 + 技能评分 | 技能评估的经典范式（可用配对排序替代绝对分数，降低标注成本） | [官方页](https://cirl.lcsr.jhu.edu/research/hmm/datasets/jigsaws_release/) 🟡 需签署 IRB 使用协议；官网公告下载脚本有故障，需发邮件申请 |
| **Ego-Exo4D** ⭐ | 1,400h 视频 / 多视角 / 7 通道音频 / 眼动 / 3D；**含 spoken expert commentary** | 首个「专家边看边讲」的 video-language 资源，ExpertAF 就构建在它上面 | [论文 arXiv 2311.18259](https://arxiv.org/abs/2311.18259) ・ [Meta AI 官方介绍](https://ai.meta.com/blog/ego-exo4d-video-learning-perception/) |
| **MM-JDM** | 1,863 样本 / 14 种动作；RGB + 光流 + 骨架 + 结构化文本 | 康复场景四模态对齐，规模小但数据结构值得参考 | [论文 arXiv 2607.07438](https://arxiv.org/pdf/2607.07438) |

**综述与索引（从这里进，别自己摸索）**

- **A Comprehensive Survey of Action Quality Assessment: Method and Benchmark**
  *Pattern Recognition* 2026 → [arXiv 2412.11149](https://arxiv.org/abs/2412.11149)
- **Awesome-AQA**（2014 至今论文索引，带 Domain / Tags 可筛选）
  → [GitHub `ZhouKanglei/Awesome-AQA`](https://github.com/ZhouKanglei/Awesome-AQA)
- **AQA-Benchmark** → [GitHub `ZhouKanglei/AQA-Benchmark`](https://github.com/ZhouKanglei/AQA-Benchmark)

### 2.5 人侧信号：口令、手部、奖励动作

狗的训练视频里，**一半的信息在人身上**：口令什么时候说、手什么时候伸出去、零食什么时候出现。

| 资源 | 用途 | 链接 |
|---|---|---|
| **Whisper** | 语音识别 + 词级时间戳 → 定位「坐 / 等 / 好」等口令的帧 | [GitHub `openai/whisper`](https://github.com/openai/whisper) |
| **FunASR / Paraformer** | 阿里达摩院开源，中文识别效果好，支持时间戳与热词（可把口令设为热词）→ **国内场景首选** | [GitHub `modelscope/FunASR`](https://github.com/modelscope/FunASR) |
| **COCO-WholeBody** | 133 个全身关键点（含人脸/手/脚），可识别训练者的手势与递零食动作 | [GitHub `jin-s13/COCO-WholeBody`](https://github.com/jin-s13/COCO-WholeBody) |
| **MediaPipe Pose / Hands** | Google 端侧人体与手部关键点，可在手机上实时运行 | [官方文档](https://ai.google.dev/edge/mediapipe/solutions/guide) |
| **ActionFormer** | 时序动作定位：从长视频切出动作起止时间 → 用于切分「口令→动作→奖励」片段 | [GitHub `happyharrycn/actionformer_release`](https://github.com/happyharrycn/actionformer_release) |

> **重要设计建议**：视觉检测「人给零食」在手机抖动 + 遮挡下不可靠。
> 更稳的方案是**让用户训练时手动打点**（按屏幕 / 双击手机背面），再与视频时间轴对齐。
> 用户成本约 1 秒，换来 100% 可靠的奖励时刻。这不是妥协，是
> **自动测可测的，人手补不可测的**——同时把「视频判断不准」的风险从模型挪到了产品设计里。

### 2.6 情绪、压力与面部信号

用于「训练是否过载 / 是否该转介」的安全兜底，以及压力信号的早期预警。

| 数据集 / 资源 | 规模（官方口径） | 用途 | 许可 | 获取 |
|---|---|---|---|---|
| **DogFLW** ⭐ | 4,335 张狗脸图 / 46 个面部关键点 + bbox | **对应 DogFACS**。可做舔唇、打哈欠、眼白等压力信号检测 | ❓ 见仓库 LICENSE | [GitHub `martvelge/DogFLW`](https://github.com/martvelge/DogFLW) ・ [Kaggle](https://www.kaggle.com/datasets/georgemartvel/dogflw) ・ [论文 arXiv 2405.11501](https://arxiv.org/abs/2405.11501) |
| **DogFACS**（面部动作编码系统） | 编码方案与手册 | 压力/恐惧面部信号的标注体系 | 🟡 | [AnimalFACS 官网](https://www.animalfacs.com/) |
| **Mendeley Canine Emotions** | ~127 段音视频 / 4 类（happy / sad / angry / relaxed）/ 2.05 GB | 小规模情绪分支种子 | 🚫 **CC BY-NC-ND 4.0（禁止商用/禁止演绎）** | [Mendeley Data](https://data.mendeley.com/datasets/5g5hg9hrkv/1) ・ [直接下载 zip](https://data.mendeley.com/public-api/zip/5g5hg9hrkv/download/1) |
| **疼痛指标视频数据集**（Zhu et al., ACII 2023） | 兽医专业人员采集并标注疼痛存在的狗视频 | 「从可见行为推断内部状态」的范本 | ❓ | [论文 PDF](https://webspace.science.uu.nl/~salah006/zhu23acii.pdf) ・ [arXiv 2209.13296](https://arxiv.org/abs/2209.13296) |
| **行为视频摘要（Dog Health）** | 长视频中切出行为片段的方法 + 数据 | 用户传 60s，你该只分析关键 5s | ❓ | [PMC10054391](https://pmc.ncbi.nlm.nih.gov/articles/PMC10054391/) |

---

## 3. 论文

### 3.1 核心范式（必读四篇）

| # | 论文 | 出处 | 为什么必读 | 链接 |
|---|---|---|---|---|
| 1 | **ExpertAF: Expert Actionable Feedback from Video** | CVPR 2025 | **整个产品的范式蓝本**。明确指出「现有方法只给分数或对比示范，把『该怎么做』的负担丢给用户」，提出生成①自由文本专家点评（好在哪 / 改哪里）②可视化专家示范。**弱监督路线：用专家评语 + LLM 造训练集**——你没有训犬标注数据，正好用训犬师点评照这条路造 | [arXiv 2408.00672](https://arxiv.org/abs/2408.00672) |
| 2 | **K9-Bench: Evaluating Multimodal LLMs on Canine-Centric Videos** | NeurIPS 2026 | 犬类视频理解的能力天花板实测。**用它定技术上限，不要承诺超过它**。其数据构造 pipeline（VLM/LLM 挖视频 → 造 QA → 去偏）可迁移到低资源领域 | [arXiv 2607.02680](https://arxiv.org/abs/2607.02680) ・ [项目页](https://ogmenrobotics.github.io/K9Bench) |
| 3 | **A Comprehensive Survey of Action Quality Assessment: Method and Benchmark** | *Pattern Recognition* 2026 | AQA 十年综述（2014–至今），带标签检索。**选型从这里进** | [arXiv 2412.11149](https://arxiv.org/abs/2412.11149) ・ [Awesome-AQA](https://github.com/ZhouKanglei/Awesome-AQA) |
| 4 | **CNN-Based Action Recognition and Pose Estimation for Animal Behavior: A Survey** | arXiv 2023 | 唯一一份动物行为识别 + 姿态估计的综述，**先读它省两周** | [arXiv 2301.06187](https://arxiv.org/abs/2301.06187) |

### 3.2 可执行反馈与教学过程

| 论文 | 出处 | 要点 | 链接 |
|---|---|---|---|
| **CricRAG: Retrieval Augmented VLMs for Personalized Cricket Coaching** | arXiv 2026 | 直击你的痛点：VLM 教练隐含拿「专业标准」做对比，对初学者反馈不可用。解法是 RAG 检索**学习者当前水平对应的**参考。→ 你该检索「这只狗当前阶段该练什么」，而非标准答案 | [arXiv 2609.26056](https://arxiv.org/abs/2609.26056) |
| **BioCoach: From 3D Pose to Prose** | arXiv 2026 | 生物力学约束 + 3D 骨架 + 语言的三阶段框架。**「先选相关自由度再评分」是很省算力的做法** | [arXiv 2603.26938](https://arxiv.org/abs/2603.26938) |
| **LIBS: Instructional Action Quality Assessment** | IEEE Trans. Computers 2026 | 把总分**归因到片段**（strengths / weaknesses），输出可解释的指导性归因。**「哪一步错了」正是用户最想知道的** | [IEEE Xplore](https://ieeexplore.ieee.org/document/11391570) |
| **UIL-AQA: Uncertainty-Aware Clip-Level Interpretable AQA** | IJCV 2026 | 显式建模**不确定度**，还注入噪声模拟裁判偏差。你的头号风险是「判断不准」，这篇给了工程化的诚实方案 | [项目页](https://andrewjohngilbert.github.io/InterpretAQA/) ・ [代码](https://github.com/dx199771/Interpretability-AQA) |
| **PoseCoach: Customizable Analysis & Visualization for Video-based Running Coaching** | arXiv 2022 | 可配置的姿态分析可视化系统，明确面向非专家用户。看它的 UX 取舍 | [arXiv 2204.08805](https://arxiv.org/abs/2204.08805) |
| **GuideMe: Multi-Domain Task Guidance and Intervention in Streaming Video** | arXiv 2026 | 流式视频中的「陪练」能力边界与错误类型分类 | [arXiv 2607.02991](https://arxiv.org/abs/2607.02991) |
| **Can Multi-Modal LLMs Provide Live Step-by-Step Task Guidance?** | arXiv 2025 | 同上，诊断 MLLM 做实时指导时的具体失败模式 | [arXiv 2511.21998](https://arxiv.org/abs/2511.21998) |
| **SportSkills: Physical Skill Learning from Sports Instructional Videos** | arXiv 2026 | 大规模运动技能教学视频数据集，「从教学视频学到技能」的直接参照 | [arXiv 2603.25163](https://arxiv.org/abs/2603.25163) |

### 3.3 动物姿态与行为识别

| 论文 | 出处 | 要点 | 链接 |
|---|---|---|---|
| **AnimalMotionCLIP: Embedding Motion in CLIP for Animal Behavior Analysis** | arXiv 2025 | 把运动信息注入 CLIP，解决「CLIP 只看静态样子」的问题 | [arXiv 2505.00569](https://arxiv.org/abs/2505.00569) |
| **Video-based estimation of pain indicators in dogs** | ACII 2023 | 双流网络 + 兽医标注。「从可见行为推断内部状态」的范本，思路可直接搬到压力 / 恐惧 | [arXiv 2209.13296](https://arxiv.org/abs/2209.13296) |
| **Benchmarking Monocular 3D Dog Pose Estimation Using In-The-Wild Motion Capture** | arXiv 2024 | 3D 狗姿态的实测上限 → 告诉你别指望 3D | [arXiv 2406.14412](https://arxiv.org/abs/2406.14412) |
| **RGBD-Dog: Predicting Canine Pose from RGBD Sensors** | CVPR 2020 | 用深度传感器提升狗姿态精度（有 RGBD 时的上限参考） | [arXiv 2004.07788](https://arxiv.org/abs/2004.07788) |
| **SyDog: A Synthetic Dog Dataset for Improved 2D Pose Estimation** | arXiv 2021 | 合成数据 + 域适应，解决「真狗视频标注贵」 | [arXiv 2108.00249](https://arxiv.org/abs/2108.00249) |
| **Who Left the Dogs Out? 3D Animal Reconstruction (WLDO)** | ECCV 2020 | 单图自监督 3D 动物重建，发布 StanfordExtra | [arXiv 2007.11110](https://arxiv.org/abs/2007.11110) |
| **Who Let The Dogs Out? Modeling Dog Behavior From Visual Data** | CVPR 2018 | 第一视角视觉数据建模狗的行为（DECADE） | [arXiv 1803.10827](https://arxiv.org/abs/1803.10827) |
| **Animal Kingdom** | CVPR 2022 | 动物行为理解的大规模多任务基准 | [arXiv 2204.08129](https://arxiv.org/abs/2204.08129) |
| **APT-36K** | NeurIPS 2022 D&B | 视频动物姿态估计与跟踪基准 | [arXiv 2206.05683](https://arxiv.org/abs/2206.05683) |
| **APTv2** | arXiv 2023 | 更大规模 + 拥挤场景难例划分 | [arXiv 2312.15612](https://arxiv.org/abs/2312.15612) |
| **Advanced techniques for automated emotion recognition in dogs from video** | *Neural Computing & Applications* 2024 | 犬类情绪识别 + Dog Clips 数据集来源 | [Springer](https://link.springer.com/article/10.1007/s00521-024-10042-3) |
| **Toward a science of computational ethology** | *Neuron* 2014 | 计算行为学纲领：如何把行为量化为可测量指标 | [DOI](https://doi.org/10.1016/j.neuron.2014.09.005) |

### 3.4 动作质量评估（AQA）

见 [§2.4](#24-动作质量评估aqa做得对不对的方法论来源) 的数据集表格与综述入口。补充两篇方法论奠基：

| 论文 | 出处 | 要点 | 链接 |
|---|---|---|---|
| **Assessing the Quality of Actions** | ECCV 2014 | AQA 任务的奠基论文（奥运跳水/跳马），从时空姿态特征回归裁判分，并强调「给出超越人类非专家的可解释反馈」 | [Springer](https://link.springer.com/chapter/10.1007/978-3-319-10599-4_36) |
| **Learning to Score Olympic Events** | CVPRW 2017 | 少数据条件下 AQA 的高效 clip 训练机制 | [arXiv 1611.05125](https://arxiv.org/abs/1611.05125) |

### 3.5 训练科学：行为学与学习机制

这一支不是 CV，但直接决定产品「建议得对不对」。**奖励时机是产品最该编码的先验。**

| 论文 | 出处 | 要点 | 链接 |
|---|---|---|---|
| **Demant et al.: The effect of frequency and duration of training sessions on acquisition and long-term memory in dogs** | *Applied Animal Behaviour Science* 2011 | **44 只比格犬 / 4 组 / 各 18 次训练**的对照实验。结论：**1–2 次/周显著优于每日**；**每天 1 次显著优于连上 3 次**；最佳组合是「每周训练 + 单次」。→ 可直接编码为产品的练习频率与单次时长规则 | [ScienceDirect](https://www.sciencedirect.com/science/article/abs/pii/S016815911100181X) ・ [DOI 10.1016/j.applanim.2011.05.010](https://doi.org/10.1016/j.applanim.2011.05.010) |
| **Chiandetti et al.: Can clicker training facilitate conditioning in dogs?** | *Applied Animal Behaviour Science* 2016 | **51 只无训练经验的家庭犬**，三组对照：响片 / 口头标记词「Bravo」/ 仅食物。**三组训练表现与泛化均无显著差异**。→ 产品启示：**标记信号的形式（响片 vs 口令）不重要，时机一致性才重要**。MVP 不必纠结响片，重点应放在测量「标记 → 奖励」的间隔 | [ScienceDirect](https://www.sciencedirect.com/science/article/abs/pii/S0168159116302386) ・ [开放获取 PDF](https://arts.units.it/retrieve/e2913fdf-1a19-f688-e053-3705fe0a67e0/2899105_Chiandettietal_APPLAN16-PostPrint.pdf) ・ [DOI 10.1016/j.applanim.2016.08.006](https://doi.org/10.1016/j.applanim.2016.08.006) |
| **Vieira de Castro et al.: Does training method matter?** | *PLOS ONE* 2020 | 厌恶式训练增加狗的应激行为和皮质醇 → 支持**只推荐正向强化**，并把惩罚法作为转介信号 | [PLOS ONE](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0225023) ・ [PMC 全文](https://pmc.ncbi.nlm.nih.gov/articles/PMC7743949/) |
| **AVSAB 立场声明** | 美国兽医动物行为学会 | 人道训练与惩罚使用的官方立场，可作产品内容合规依据 | [avsab.org](https://avsab.org/resources/position-statements/) |

> **关于「延迟强化」**：奖励延迟会显著削弱学习效果，这是操作性条件反射的基本结论，
> 属教科书知识而非某篇可引论文。但它是**竞品普遍忽略的点**——用户最常犯的错不是动作做错，
> 是**奖励晚了 2 秒**。建议直接编码成规则：`reward_delay > 1.0s` 即触发提醒。

> **关于 CSU「AI 训狗系统」（2021）——已找到正式论文**
>
> **Who's a Good Boy? Reinforcing Canine Behavior in Real-Time using Machine Learning**
> （Stock & Cavey, Colorado State University, 2021-01）→ [arXiv 2101.02380](https://arxiv.org/abs/2101.02380) ・
> [代码](https://github.com/stockeh/canine-embedded-ml)
>
> 用 Jetson Nano + 姿态分类（sit / stand / lie down）驱动伺服投喂器，报告
> **92% 测试准确率 / 39 FPS**。配套数据集即 [DogPoseCV](https://huggingface.co/datasets/stockeh/dog-pose-cv)（见 [§2.2](#22-狗的姿态与关键点)）。
>
> 定位仍是「机器训狗」而非「教人训狗」，产品定位不同；但**它证明了消费级算力足以实时判定犬类姿态**，
> 这对端侧可行性是很直接的证据——比任何 benchmark 数字都更有说服力。
> 注：这是 arXiv 预印本，未见同行评审版本；且其 92% 是在受控场景下取得，不能外推到客厅环境。

---

## 4. 能力边界与数据缺口

### 4.1 必须自建的部分（也是壁垒）

诚实结论：**没有一份公开数据集能直接训出这个产品需要的模型。** 缺的是：

| # | 缺口 | 为什么重要 | 现状 |
|---|---|---|---|
| 1 | **「训犬片段 + 正确性标注」** | ②质量判定的核心监督信号 | 不存在。没有人在狗的训练视频上标注过「这一秒奖励早了 0.8 秒」 |
| 2 | **人-狗双主体 + 口令语音 + 奖励事件的三重时间对齐** | 判定「时机对不对」的必要结构 | 不存在。K9-Bench 有 interaction 分析，但是问答式的，非事件级标注 |
| 3 | **纵向训练日志** | 「两周有没有进步」必须靠同一只狗、同一动作的多天序列 | 学术界不收这类数据 |
| 4 | **中文口令 / 国内家庭场景** | 国内 C 端产品的直接输入分布 | 现有全部为英文 YouTube 或实验犬舍场景 |
| 5 | **奖励时机（reward timing）的视频标注** | 最高频的错误类型 | 有行为学结论，无视频数据集 |

**推论**：这五个缺口恰好是产品数据飞轮的位置。MVP 阶段就该把埋点设计好——
用户每日上传 + 训犬师复核结论，就是在生产第 1、2、3 项数据。
**这份数据比模型本身更值钱。**

### 4.2 许可红线（会直接影响商业模式）

C 端 ¥19–49/月 属于商业使用，以下**不能直接用于训练商用模型**：

| 资源 | 限制 | 影响 |
|---|---|---|
| **SyDog-Video** | 明确「non-commercial research purposes only」，且**不可再分发** | 只能用于内部实验、论文，不能进产品 |
| **Mendeley Canine Emotions** | CC BY-NC-ND 4.0 | 禁止商用、禁止演绎 |
| **K9-Bench** | gated，需同意条款 | 适合做内部评测，商用需读条款 |
| **Animal Kingdom / AP-10K / APT-36K** | 研究用途（具体条款见各仓库 LICENSE） | 预训练权重可用于研究，商用需逐项确认 |
| **DogPoseCV** | 标称 `apache-2.0`，但底图为 Stanford Dogs（ImageNet 子集） | ⚠️ **标注文件的许可未必覆盖图像本身**。重标注不产生新的图像版权，商用前须确认底层图像条款 |
| **Movement Sensor Dataset** | **CC BY 4.0** | ✅ 可商用，仅需署名 |

**建议**：法务可接受的路线是——
①优先用 **CC BY 4.0** 数据 + 自采数据训练；
②研究许可数据只做**离线评测与选型**，不进入训练集；
③商用模型权重优先选**许可清晰的预训练模型**（如 SuperAnimal 系列需确认其权重许可）而非研究数据集训出的权重。

### 4.3 技术上限的现实预期

| 能力 | 可信度 | 依据 |
|---|---|---|
| 狗的姿态分类（坐/站/卧） | 高 | 大量数据集 + 成熟模型；DogPoseCV 论文在 Jetson Nano 上实测 92% / 39 FPS（受控场景） |
| 姿态是否发生变化 / 变化时刻 | 高 | 关键点位移即可，不依赖语义 |
| 保持时长（Stay duration） | 高 | 纯时间轴测量 |
| 口令时间戳定位 | 高 | ASR 词级时间戳，中文用 FunASR |
| 奖励时刻 | 高（**若用户手动打点**）／低（若纯视觉检测） | 遮挡与抖动导致视觉不可靠 |
| 「动作是否标准」（如牵引姿势） | 中 | AQA 方法可迁移，但无训犬标注，需规则 + 少量标注 |
| 狗的情绪 / 压力状态 | 中低 | K9-Bench 实测 MLLM 表现有限；DogFACS 需专门模型 |
| 长时序因果推理（「为什么两周没进展」） | 低 | 需要纵向数据 + 归因，MLLM 零样本不可靠 |

---

## 5. 建议

### 5.1 第一个场景选「等待 / Stay 持续时间」

**理由**
- 几乎不需要语义理解：判定「狗是否保持住」本质是**姿态稳定性 + 时长**，是可直接测量的物理量。
- 对拍摄质量要求低：不需要看清表情、不需要多个机位。
- **进步天然可视化**：每天一个 `stay_duration`，两周后就是一条曲线——
  正面击中原始痛点「练两周没进展」。
- 规避了最大的技术风险：不依赖 MLLM 的语义判断。

**对比其他候选**

| 场景 | 可测性 | 风险 | 结论 |
|---|---|---|---|
| **等待 / Stay** | 高（时长+姿态稳定性） | 低 | ✅ 首选 |
| **牵绳拉扯** | 中（需绳张力或手机 IMU） | 中（纯视觉难量拉力） | 第二优先，可结合手机加速度计 |
| **定点排泄** | 低（事件稀疏、需长时间监控） | 高 | 暂缓 |

### 5.2 技术流水线

```
用户上传 20–60s 视频
   ↓
① 人狗分离   YOLO 检测 + 多目标跟踪，区分人与狗两个 track
   ↓
② 口令识别   FunASR（中文）/ Whisper + 强制对齐 → t_cmd（"等"说出口的帧）
   ↓
③ 狗姿态     mmpose(AP-10K/APT-36K) 或 SuperAnimal-Quadruped 逐帧 17 关键点
             关键点坐标按体长归一化，消除体型与镜头距离差异
   ↓
④ 可测量指标（全部为数字，可回溯到具体帧）
     stay_duration  = t_cmd → 首次姿态跃迁（离位/起身/前移 > 0.2 体长）的秒数
     body_drift     = 该时段内关键点位移方差（"挪了但没站起来"）
     cue_latency    = 口令 → 狗进入目标姿态的反应时
     reward_delay   = 奖励事件时刻 − 目标行为达成时刻   ← 最关键
   ↓
⑤ 判定        规则引擎 + 小分类器，输出置信度
     低置信度 → 进入训犬师复核队列（质量保障 + 数据飞轮）
   ↓
⑥ 处方生成    LLM 输入：结构化测量值 + 该犬历史曲线 + RAG 检索的训练阶段 SOP
             绝不把原始视频丢给 LLM 让它自由发挥
```

### 5.3 四条设计原则

1. **先测量，后解释。** 不让模型「看着视频说」，只让它「读着数字写」。
   每个结论都要能回溯到「第 14 秒狗后腿移动了 0.3 个体长」。这是可复核性的前提。

2. **输出置信度，并让低置信度走人工。** 参考 UIL-AQA 的不确定度建模思路。
   把「视频判断不准」从模型缺陷转化为**可管理的产品流程**——这正好落在
   「专业训犬师复核」的定位上。

3. **自动测可测的，人手补不可测的。** 奖励时刻让用户按一下屏幕打点，1 秒成本换 100% 可靠性。
   不要为了「全自动」的卖点牺牲数据质量。

4. **数据飞轮从第一天就设计。** 每次复核结论都要结构化落库
   （训练目标 / 步骤 / 时间戳 / 判定 / 训犬师修正）。这是唯一无法被复制的资产。

### 5.4 近期行动建议

| 优先级 | 动作 | 产出 |
|---|---|---|
| P0 | 用 SuperAnimal-Quadruped 或 mmpose 在 10 段自拍 Stay 视频上跑通关键点 + 姿态稳定性 | 验证「2D 关键点能否区分坐稳 / 起身 / 挪动」 |
| P0 | FunASR 接入，测中文口令（坐 / 等 / 好 / 过来）的时间戳准确率 | 口令定位基线 |
| P1 | 定义指标 schema 与数据库表（狗 ID / 训练目标 / 每帧事件 / 每日指标） | 数据飞轮的地基 |
| P1 | 用 CricRAG 思路做训练阶段 SOP 知识库（Stay 的分级标准：3 秒 → 10 秒 → 加入干扰） | 处方生成的 RAG 语料 |
| P2 | 与 1–2 位训犬师建复核流程，收集首批「正确性标注」 | 缺口 #1 的第一批数据 |

---

## 附：链接验证记录

本报告共含 **99 个唯一 URL**，全部于 2026-11 逐一实际访问。验证方法与结果：

**第一轮（脚本直连）：90 个返回 HTTP 200。**

**第二轮（9 个返回 403 / 202，逐一用抓取服务复核内容）：**
其中 1 个是 `doi.org` 重定向到已被拦截的 ACM 页面（与下表 ACM 行同一结论），
下表列出另外 8 个。

| URL | 脚本状态 | 复核结果 |
|---|---|---|
| ScienceDirect · Kumpulainen 2021 | 403 | ✅ 抓取成功，标题与期刊卷期匹配（AABS Vol.241, 105393，开放获取 CC BY 4.0） |
| ScienceDirect · Demant 2011 | 403 | ✅ 抓取成功，标题/作者/页码匹配（AABS Vol.133, 228–234） |
| ScienceDirect · Chiandetti 2016 | 403 | ✅ 抓取成功，标题/作者/卷期匹配（AABS Vol.184, 109–116） |
| ACM DL · Guide dog pull sensor | 403 | ✅ 抓取成功，标题匹配（ACM ACI 2025） |
| JHU · JIGSAWS 官方页 | 403 | ✅ 抓取成功，任务与协议说明匹配 |
| IEEE Xplore · LIBS | 202 | ✅ 抓取成功，标题与摘要匹配 |
| arts.units.it · Chiandetti 开放 PDF | 403 | ✅ 抓取成功，确为同行评审后印本（post-print） |
| ai.meta.com · Ego-Exo4D 博客 | 400 | ✅ 抓取成功，标题匹配 |

> 结论：403 / 202 均为出版商反爬（Elsevier、ACM、IEEE、JHU 对非浏览器 UA 统一拦截），
> **不是死链**；链接在浏览器中可正常打开。上表 8 个已全部经抓取服务验证内容正确。

**仍需注意**

- JIGSAWS 需签署 IRB 使用协议；官网公告下载脚本有故障，需发邮件（jigsaws.cirl@gmail.com）申请。
- 标注 **[未核实]** 的条目（Dog Clips 规模约 100 段、StanfordExtra 规模）来自二手文献，
  使用前请查原始论文或仓库 README。
- Kaggle 上的 `arashnic/animal-behavior-analysis` 与 Mendeley `vxhx934tbn` 为**同一批数据**的两种分发，
  不要重复计数。

**Dataset 可用性实测记录**

- `stockeh/dog-pose-cv`：已实际下载 `labels.tar.gz`（104,662 B，HTTP 200，HF 直连可用），
  解压后逐 CSV 行统计出 20,423 条标注，据此发现与数据集卡片存在数量差异（见 §2.2 专项评估）。
  `images.tar.gz`（779,709,927 B）已通过 Range 请求读取头部，确认 tar 结构正常、
  可列出 `images/<犬种>/` 目录；**单张图片的解码验证未完成**（该步命令未获批准），
  使用前请自行验证一次图像完整性。

**核对原则**：本报告只写实际读到的数字。凡未亲验的规模或许可，均显式标注，
不以训练记忆补全——数据集规模与许可证是最容易出现「看起来合理但错误」的地方。
