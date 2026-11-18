# 宠物行为训练 Agent：技术数据集与论文精选

> 面向 MVP：用户每天上传 20--60 秒手机训练视频，系统测量口令、奖励与可见行为的时间关系，积累训练记录，并给出下一次练习建议。
>
> 整理日期：2026-11-12。本文为新增资料清单，未修改 `docs/` 下既有调研文件。所列访问地址在整理时进行了 HTTP 可达性检查；**可访问不等于可商用**，训练或发布前必须逐项复核数据集 LICENSE、数据使用条款和个人/宠物视频授权。

## 1. MVP 应优先解决的测量问题

先选择可从单段视频稳定测量的训练问题，例如“等待/Stay”。最小时间线为：

`口令时刻 -> 狗进入目标姿态 -> 姿态保持时长 -> 中断时刻 -> 奖励时刻`

这能产生可复核指标：反应延迟、成功保持时长、中断次数、奖励延迟和连续多日趋势。不要让视觉语言模型直接判定“训得对不对”；应先提取这些结构化事件，再由规则、训练师 SOP 与语言模型生成解释和下次计划。

## 2. 数据集与可复用模型

| 资源 | 数据/能力与下载地址 | 对 MVP 的用途 | 许可与注意事项 |
|---|---|---|---|
| **StanfordExtra** | 狗的 2D 关键点和分割标注；[下载申请与代码](https://github.com/benjiebob/StanfordExtra) | 训练或评估狗的姿态估计，帮助判断坐、站、卧及姿态是否中断。 | 标注须通过表单申请；商用条件需向发布方确认。 |
| **AP-10K** | 10,015 张图、54 种哺乳动物、17 个关键点；[下载与说明](https://github.com/AlexTheBad/AP-10K) | 作为四足动物姿态模型的通用预训练/评测来源，含犬科样本。 | 使用前阅读仓库 LICENSE；不是犬类训练互动数据。 |
| **APT-36K** | 2,400 段视频、36,000 帧、关键点和轨迹 ID；[下载与说明](https://github.com/pandorgan/APT-36K) | 适合验证跨帧跟踪与“保持多久”的时序测量。 | 使用前阅读仓库 LICENSE；物种和拍摄域与家庭手机视频存在偏差。 |
| **Animal Kingdom** | 动物动作、时序定位与姿态基准；[项目仓库](https://github.com/sutdcv/Animal-Kingdom) | 用于动物动作识别与长视频行为定位的预训练/方法对比。 | 数据获取与许可依项目说明执行；不应把它当成训犬质量评分数据。 |
| **MammalNet** | 173 类哺乳动物、18,000+ 视频、12 类行为；[下载与说明](https://github.com/Vision-CAIR/MammalNet) | 为跑、走、静止等高层行为分类提供预训练和测试参考。 | 复核 LICENSE；野外视频与家养犬训练场景差异显著。 |
| **DECADE / dogTorch** | 狗佩戴 GoPro 与 IMU 的第一视角数据；[代码与数据入口](https://github.com/ehsanik/dogTorch) | 参考狗行为的视觉-运动学联合建模；适合研究而非直接部署。 | 第一视角与用户第三人称手机视频不同，不能直接替代目标域数据。 |
| **Dog movement-sensor dataset** | 45 只犬、100 Hz 加速度计/陀螺仪、同步视频、7 类行为；[Mendeley 下载](https://data.mendeley.com/datasets/vxhx934tbn/1) | 训练“坐/站/走/嗅闻”等行为分类；也可验证牵绳场景中惯性信号的价值。 | 页面标注 CC BY 4.0，仍需保存版本与署名信息；它不含直接的绳张力真值。 |
| **DogPoseCV** | 20,578 张 RGB 狗图（120 犬种），姿态分类为 `standing` 4,143 / `sitting` 3,038 / `lying down` 7,090 / `undefined` 6,307；[Hugging Face 下载](https://huggingface.co/datasets/stockeh/dog-pose-cv) | **可用作姿态分类补充数据集**：将单帧分类器接在关键点/跟踪结果后，输出“站/坐/卧”，再通过连续帧聚合计算等待保持时长。也适合做端侧轻量分类基线。 | 数据卡标注 Apache-2.0、公开且非 gated；图像源为 Stanford Dogs 的人工重标注，商业发布前仍应复核源图像与派生数据的许可链。类别不均衡（卧姿约为坐姿两倍），且 `undefined` 多为近景或难辨姿态，须按视频质量返回低置信度。**它是静态图像集，没有关键点、视频时序、口令、奖励和训练质量标签。** |
| **DeepLabCut SuperAnimal-Quadruped** | 四足动物预训练关键点模型；[代码](https://github.com/DeepLabCut/DeepLabCut) / [模型权重](https://huggingface.co/mwmathis/DeepLabCutModelZoo-SuperAnimal-Quadruped) | **最适合 MVP 的狗姿态起点**：先对用户视频推理，无需先自行训练关键点模型。 | 复核代码和权重各自许可；对遮挡、极端犬种、镜头运动应输出低置信度。 |
| **COCO-WholeBody** | 人体、手部和面部共 133 个关键点；[下载与说明](https://github.com/jin-s13/COCO-WholeBody) | 识别训练者手部移动、弯腰和递送奖励等辅助信号。 | 它不标“给零食”；奖励事件仍需自建标注或手动打点。 |

### 语音与时序工具

| 工具 | 访问地址 | 用途与边界 |
|---|---|---|
| **FunASR** | [GitHub](https://github.com/modelscope/FunASR) | 中文语音识别、时间戳与热词。将“等、坐、来、好”等设为热词，定位口令和标记词。嘈杂环境/多人说话时需给置信度。 |
| **Whisper** | [GitHub](https://github.com/openai/whisper) | 语音转录的通用备选；适合将音轨变为可检索文本和近似时间线。中文训犬短词的时间精度须实测。 |
| **ActionFormer** | [GitHub](https://github.com/happyharrycn/actionformer_release) | 时序动作定位参考实现，可用于将连续视频切成“口令--执行--奖励”片段；需要自有标签才能学到训犬事件。 |

### 关键数据缺口

公开资源可帮助识别姿态或动作，但没有发现可直接支持下列任务的公开标准数据集：**人-犬同框、中文口令、奖励事件、训练步骤正确性和训练师复核结论的时间对齐标注**。因此建议从 MVP 第一天开始、在取得明确授权后积累匿名化训练片段与以下标签：

- 训练目标、阶段、口令时刻、狗的目标状态起止、奖励时刻；
- 视频可见性/遮挡、模型置信度、训练师是否同意系统结论；
- 风险信号及转介结果，但不得把攻击性或恐惧问题自动诊断为普通训练失败。

## 3. 值得优先阅读的论文

| 论文 | 访问地址 | 与产品的关系 |
|---|---|---|
| Mathis et al., **DeepLabCut** (Nature Neuroscience, 2018) | [论文](https://doi.org/10.1038/s41593-018-0209-y) | 无标记动物姿态估计的基础工作；说明少量领域标注可如何提升关键点质量。 |
| Ye et al., **SuperAnimal pretrained pose estimation models** (Nature Communications, 2024) | [论文](https://doi.org/10.1038/s41467-024-48792-2) | 跨物种预训练姿态模型的依据，支撑 MVP 先用预训练四足模型、后续按用户视频微调的策略。 |
| Biggs et al., **Who Left the Dogs Out? / StanfordExtra** (ECCV 2020) | [论文](https://arxiv.org/abs/2007.11110) | 狗专用姿态和形状估计的代表工作；用于理解犬体结构、关键点与遮挡问题。 |
| Stock & Cavey, **Who's a Good Boy? Reinforcing Canine Behavior in Real-Time using Machine Learning** (arXiv 2021) | [论文](https://arxiv.org/abs/2101.02380) / [DogPoseCV 数据集](https://huggingface.co/datasets/stockeh/dog-pose-cv) | DogPoseCV 的来源论文。采用 120 犬种的图片，将姿态重标注为站立、坐下、趴卧和未定义四类；可作为端侧姿态分类的轻量原型依据，但不是训练时序质量评估方案。 |
| Ehsani et al., **Who Let the Dogs Out? Modeling Dog Behavior From Visual Data** (CVPR 2018) | [论文](https://arxiv.org/abs/1803.10827) | 展示视觉和运动传感器如何联合表征狗的行为；对牵绳拉扯的后续硬件/手机传感器扩展有参考价值。 |
| Ng et al., **Animal Kingdom** (CVPR 2022) | [论文](https://arxiv.org/abs/2204.08129) | 多任务动物行为理解基准，涵盖动作分类、时序定位和姿态任务，适合作为模型评测方法来源。 |
| Yu et al., **AP-10K** (NeurIPS 2021) | [论文](https://arxiv.org/abs/2108.12617) | 大规模动物关键点基准，解释 2D 四足姿态估计的常见协议和指标。 |
| Yang et al., **APT-36K** (NeurIPS 2022) | [论文](https://arxiv.org/abs/2206.05683) | 视频中的动物姿态跟踪基准；与“等待保持时长”的跨帧测量最直接相关。 |
| Parmar & Morris, **What and How Well You Performed: Multi-task AQA** (CVPR 2019) | [论文](https://openaccess.thecvf.com/content_CVPR_2019/papers/Parmar_What_and_How_Well_You_Performed_A_Multitask_Learning_Approach_CVPR_2019_paper.pdf) | 动作质量评估（AQA）把总分拆为细粒度维度。可借鉴为“口令清晰度、奖励延迟、保持时长”等可解释指标，而非黑盒评分。 |
| Xu et al., **FineDiving** (CVPR 2022) | [论文](https://arxiv.org/abs/2204.03646) / [数据与代码](https://github.com/xujinglin/finediving) | 过程感知质量评估：按子步骤比较表现。很适合迁移到“口令--等待--奖励”的分步评分思想。 |
| **ExpertAF: Expert Actionable Feedback from Video** (CVPR 2025) | [论文](https://arxiv.org/abs/2408.00672) | 从视频生成可执行专家反馈的直接方法参照。产品应让训犬师点评成为训练信号，并保留证据片段与不确定性。 |
| Vieira de Castro et al., **Does training method matter?** (PLOS ONE, 2020) | [开放获取论文](https://doi.org/10.1371/journal.pone.0225023) | 比较奖励式与厌恶式训练的福利影响；支持产品只提供正向强化建议，并把高压力/恐惧场景转介给合格专业人员。 |
| Pereira et al., **Quantifying behavior to understand the brain** (Nature Neuroscience, 2020) | [论文](https://doi.org/10.1038/s41593-020-00734-z) | 行为量化方法综述。核心启发是把主观描述转成可重复测量的事件与轨迹，正是该 Agent 的数据层原则。 |

## 4. 推荐的最小技术验证顺序

1. 选定“等待/Stay”，采集 50--100 段已获授权、训练师复核的视频，并定义事件标注规范。
2. 用 SuperAnimal-Quadruped 生成狗关键点，结合轨迹稳定性规则输出“保持开始/结束”和置信度。
3. 用 FunASR 提取口令候选；奖励时刻先由用户在录制时手动打点或在上传后轻点标记，避免视觉误判递零食。
4. 计算每天的反应延迟、最长保持时长、成功率与奖励延迟；仅在指标置信度足够时生成反馈。
5. 训练师审核低置信度样本和风险样本，将审核结果回写为后续模型和规则的金标准。

## 5. 安全与合规底线

- 系统只能报告视频中**可观察到的行为和测量结果**，不能凭短视频诊断攻击性、疼痛、恐惧或医疗问题。
- 出现咬伤风险、明显恐惧/僵直/逃避、强烈资源守护或训练恶化时，停止自动处方，建议联系合格的兽医行为学或专业训犬人员。
- 对模型看不清、音频无法辨认、狗或人离开画面的片段，必须显示“无法可靠判断”，而不是补全推测。
- 用户视频是高敏感内容：上传授权、保留期限、删除入口、训练数据二次使用同意和人脸处理都应产品化。
